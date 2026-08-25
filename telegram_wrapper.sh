#!/usr/bin/env bash
# =====================================================================
# telegram_wrapper.sh
# Hook do Claude Code -> mensagem contextualizada no Telegram.
#
# Lê o JSON do hook no stdin (Stop, Notification, SubagentStop, ...) e
# monta uma mensagem com projeto, branch, pedido, resposta, ferramentas
# usadas e duração do turno, em vez de um aviso genérico.
#
# Só envia se o arquivo flag `.telegram_enabled` existir.
# Nunca falha o hook: sai sempre com 0.
# =====================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG_FILE="${SCRIPT_DIR}/.telegram_enabled"
JQ_PROGRAM="${SCRIPT_DIR}/lib/extract_turn.jq"

if [ ! -f "$FLAG_FILE" ]; then
    echo "Notificacoes do Telegram desabilitadas"
    exit 0
fi

# Config opcional via .env (mesmo arquivo do telegram_notify.sh)
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/.env"
    set +a
fi

MAX_PROMPT_CHARS="${TELEGRAM_MAX_PROMPT_CHARS:-350}"
MAX_REPLY_CHARS="${TELEGRAM_MAX_REPLY_CHARS:-900}"
# Só notifica turnos que demoraram pelo menos N segundos (0 = sempre).
MIN_DURATION="${TELEGRAM_MIN_DURATION_SECONDS:-0}"

OVERRIDE_TITLE="${1:-}"

# --- Payload do hook (stdin) ---------------------------------------
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD="$(cat 2>/dev/null || true)"
fi

json_field() {
    # $1 = caminho jq; lê de $PAYLOAD
    [ -n "$PAYLOAD" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    printf '%s' "$PAYLOAD" | jq -r "$1 // empty" 2>/dev/null || true
}

EVENT="$(json_field '.hook_event_name')"
TRANSCRIPT="$(json_field '.transcript_path')"
HOOK_CWD="$(json_field '.cwd')"
NOTIF_MSG="$(json_field '.message')"

# --- Helpers --------------------------------------------------------
html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Limpa ruído de prompt: system-reminders, caveats e wrappers de slash command.
clean_prompt() {
    perl -0777 -pe '
        s{<system-reminder>.*?</system-reminder>}{}gs;
        s{<local-command-caveat>.*?</local-command-caveat>}{}gs;
        s{<command-message>.*?</command-message>}{}gs;
        s{<command-name>(.*?)</command-name>}{$1}gs;
        s{<command-args>(.*?)</command-args>}{ my $a = $1; $a =~ /\S/ ? " $a" : "" }ges;
        s{<local-command-stdout>.*?</local-command-stdout>}{}gs;
        s{\s*\n\s*\n\s*}{\n}gs;
        s{^\s+|\s+$}{}gs;
    '
}

truncate_chars() {
    # $1 = limite
    awk -v n="$1" '
        { buf = buf (NR > 1 ? "\n" : "") $0 }
        END {
            if (length(buf) > n) printf "%s…", substr(buf, 1, n)
            else printf "%s", buf
        }'
}

fmt_duration() {
    # $1 = segundos
    local s="$1"
    if [ "$s" -lt 60 ]; then
        printf '%ds' "$s"
    elif [ "$s" -lt 3600 ]; then
        printf '%dm %02ds' "$((s / 60))" "$((s % 60))"
    else
        printf '%dh %02dm' "$((s / 3600))" "$(((s % 3600) / 60))"
    fi
}

iso_to_epoch() {
    # $1 = 2026-08-25T12:20:52.369Z -> epoch
    local ts="${1%.*}"
    ts="${ts%Z}"
    TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" "+%s" 2>/dev/null || true
}

# --- Extrai o turno do transcript -----------------------------------
PROMPT=""; REPLY=""; TOOLS=""; PROMPT_TS=""; BRANCH=""; PROJECT_DIR=""; SUBAGENTS=0

if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ] && [ -f "$JQ_PROGRAM" ] && command -v jq >/dev/null 2>&1; then
    TURN="$(jq -s -f "$JQ_PROGRAM" "$TRANSCRIPT" 2>/dev/null || true)"
    if [ -n "$TURN" ]; then
        PROMPT="$(printf '%s' "$TURN"  | jq -r '.prompt   // ""' 2>/dev/null)"
        REPLY="$(printf '%s' "$TURN"   | jq -r '.reply    // ""' 2>/dev/null)"
        PROMPT_TS="$(printf '%s' "$TURN" | jq -r '.promptTs // ""' 2>/dev/null)"
        BRANCH="$(printf '%s' "$TURN"  | jq -r '.branch   // ""' 2>/dev/null)"
        PROJECT_DIR="$(printf '%s' "$TURN" | jq -r '.cwd   // ""' 2>/dev/null)"
        SUBAGENTS="$(printf '%s' "$TURN" | jq -r '.subagents // 0' 2>/dev/null)"
        TOOLS="$(printf '%s' "$TURN" | jq -r '
            [.tools[]? | "\(.name)×\(.n)"] | .[0:4] | join(" · ")' 2>/dev/null)"
    fi
fi

[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$HOOK_CWD"
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$PWD"
PROJECT="$(basename "$PROJECT_DIR")"

if [ -z "$BRANCH" ]; then
    BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

DIRTY="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
[ -n "$DIRTY" ] || DIRTY=0

DURATION=""
DURATION_S=0
if [ -n "$PROMPT_TS" ]; then
    START_EPOCH="$(iso_to_epoch "$PROMPT_TS")"
    if [ -n "$START_EPOCH" ]; then
        DURATION_S=$(( $(date +%s) - START_EPOCH ))
        [ "$DURATION_S" -ge 0 ] || DURATION_S=0
        DURATION="$(fmt_duration "$DURATION_S")"
    fi
fi

# Filtro de ruído: turnos curtos não notificam (só no Stop).
if [ "$EVENT" = "Stop" ] && [ "$MIN_DURATION" -gt 0 ] && [ "$DURATION_S" -lt "$MIN_DURATION" ]; then
    echo "Turno de ${DURATION_S}s abaixo de TELEGRAM_MIN_DURATION_SECONDS=${MIN_DURATION}; nao notificado"
    exit 0
fi

# --- Monta a mensagem -----------------------------------------------
case "$EVENT" in
    Notification) TITLE="🔔 Claude Code precisa de você" ;;
    SubagentStop) TITLE="🤖 Subagente finalizado" ;;
    Stop)         TITLE="✅ Turno concluído" ;;
    "")           TITLE="${OVERRIDE_TITLE:-✅ Tarefa concluída no Claude Code}" ;;
    *)            TITLE="✅ ${EVENT}" ;;
esac

# Notificacao de permissao/atencao: mensagem enxuta e acionavel.
if [ "$EVENT" = "Notification" ]; then
    MAX_REPLY_CHARS=250
    TOOLS=""
    SUBAGENTS=0
fi

BODY="<b>$(printf '%s' "$TITLE" | html_escape)</b>"
BODY="${BODY} · 📁 <i>$(printf '%s' "$PROJECT" | html_escape)</i>"

if [ -n "$NOTIF_MSG" ]; then
    BODY="${BODY}"$'\n\n'"$(printf '%s' "$NOTIF_MSG" | html_escape)"
elif [ -z "$EVENT" ] && [ -n "$OVERRIDE_TITLE" ]; then
    : # título já veio do argumento
fi

if [ -n "$PROMPT" ]; then
    P="$(printf '%s' "$PROMPT" | clean_prompt | truncate_chars "$MAX_PROMPT_CHARS" | html_escape)"
    [ -n "$P" ] && BODY="${BODY}"$'\n\n'"💬 <b>Pedido</b>"$'\n'"<blockquote>${P}</blockquote>"
fi

if [ -n "$REPLY" ]; then
    R="$(printf '%s' "$REPLY" | truncate_chars "$MAX_REPLY_CHARS" | html_escape)"
    [ -n "$R" ] && BODY="${BODY}"$'\n\n'"📝 <b>Resposta</b>"$'\n'"<blockquote expandable>${R}</blockquote>"
fi

FOOTER=""
[ -n "$BRANCH" ] && FOOTER="🌿 <code>$(printf '%s' "$BRANCH" | html_escape)</code>"
if [ "$DIRTY" -gt 0 ]; then
    [ -n "$FOOTER" ] && FOOTER="${FOOTER} · "
    FOOTER="${FOOTER}📄 ${DIRTY} alterado(s)"
fi
[ -n "$FOOTER" ] && BODY="${BODY}"$'\n\n'"${FOOTER}"

STATS=""
[ -n "$TOOLS" ] && STATS="🔧 ${TOOLS}"
if [ "${SUBAGENTS:-0}" -gt 0 ] 2>/dev/null; then
    [ -n "$STATS" ] && STATS="${STATS} · "
    STATS="${STATS}🤖 ${SUBAGENTS} subagente(s)"
fi
[ -n "$STATS" ] && BODY="${BODY}"$'\n'"$(printf '%s' "$STATS" | html_escape)"

TAIL="🕐 $(date '+%d/%m %H:%M')"
if [ -n "$DURATION" ] && [ "$EVENT" != "Notification" ]; then
    TAIL="${TAIL} · ⏱ ${DURATION}"
fi
BODY="${BODY}"$'\n'"${TAIL}"

# Telegram corta em 4096 chars.
BODY="$(printf '%s' "$BODY" | head -c 3900)"

# --- Envia (com fallback pra texto puro se o HTML for recusado) ------
if ! "${SCRIPT_DIR}/telegram_notify.sh" "$BODY" 2>&1; then
    PLAIN="$(printf '%s' "$BODY" \
        | sed -E 's#</?(b|i|code|pre|blockquote)( expandable)?>##g' \
        | sed -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g')"
    TELEGRAM_PARSE_MODE="" "${SCRIPT_DIR}/telegram_notify.sh" "$PLAIN" || true
fi

exit 0
