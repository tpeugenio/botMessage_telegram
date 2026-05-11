#!/usr/bin/env bash
# Wrapper para controlar notificacoes do Telegram
# Verifica se as notificacoes estao habilitadas antes de enviar

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG_FILE="${SCRIPT_DIR}/.telegram_enabled"

if [ -f "$FLAG_FILE" ]; then
    MESSAGE="${1:-}"
    if [ -z "$MESSAGE" ]; then
        DATA_HORA="$(date '+%d/%m/%Y %H:%M:%S')"
        MESSAGE="✅ Tarefa concluída no Claude Code às ${DATA_HORA}"
    fi

    "${SCRIPT_DIR}/telegram_notify.sh" "$MESSAGE"
else
    echo "Notificacoes do Telegram desabilitadas"
fi
