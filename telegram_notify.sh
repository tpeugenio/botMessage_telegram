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

# --- Configurações ---
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?Defina a variável de ambiente TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID:?Defina a variável de ambiente TELEGRAM_CHAT_ID}"

# --- Envia a mensagem (curl faz o URL-encode com --data-urlencode) ---
response=$(curl -sS -G "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    --data-urlencode "parse_mode=HTML")

if echo "$response" | grep -q '"ok":true'; then
    echo "Mensagem enviada com sucesso para o Telegram!"
else
    echo "Falha ao enviar mensagem: $response"
    exit 1
fi
