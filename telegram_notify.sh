#!/usr/bin/env bash
# ===============================
# Script: telegram_notify.sh
# Envia uma mensagem para o Telegram via API
# ===============================

set -u

if [ $# -lt 1 ]; then
    echo "Uso: $0 \"<mensagem>\""
    exit 1
fi

MESSAGE="$1"

# --- Carrega .env se existir ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    . "${SCRIPT_DIR}/.env"
    set +a
fi

# --- Configurações ---
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?Defina TELEGRAM_BOT_TOKEN (env ou .env)}"
CHAT_ID="${TELEGRAM_CHAT_ID:?Defina TELEGRAM_CHAT_ID (env ou .env)}"

# parse_mode: HTML por padrao; TELEGRAM_PARSE_MODE="" envia como texto puro
PARSE_MODE="${TELEGRAM_PARSE_MODE-HTML}"

# --- Envia a mensagem (curl faz o URL-encode com --data-urlencode) ---
CURL_ARGS=(
    --data-urlencode "chat_id=${CHAT_ID}"
    --data-urlencode "text=${MESSAGE}"
    --data-urlencode "disable_web_page_preview=true"
)
if [ -n "$PARSE_MODE" ]; then
    CURL_ARGS+=(--data-urlencode "parse_mode=${PARSE_MODE}")
fi

response=$(curl -sS --max-time 15 -G \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    "${CURL_ARGS[@]}")

if echo "$response" | grep -q '"ok":true'; then
    echo "Mensagem enviada com sucesso para o Telegram!"
else
    echo "Falha ao enviar mensagem: $response"
    exit 1
fi
