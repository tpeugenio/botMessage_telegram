# botMessage

Scripts em Bash para enviar notificações ao Telegram via API de bots. Útil para receber avisos de tarefas concluídas (ex.: integração com Claude Code).

## Arquivos

- `telegram_notify.sh` — envia uma mensagem para o Telegram usando a API de bots.
- `telegram_wrapper.sh` — só dispara o `notify` se o arquivo flag `.telegram_enabled` existir (liga/desliga sem mexer no código).
- `.env.example` — modelo das variáveis de ambiente.

## Configuração

1. Crie um bot com o [@BotFather](https://t.me/BotFather) e copie o token.
2. Descubra seu `chat_id` (envie uma mensagem para o bot e consulte `https://api.telegram.org/bot<TOKEN>/getUpdates`).
3. Copie o `.env.example` para `.env` e preencha:

   ```bash
   cp .env.example .env
   ```

   ```
   TELEGRAM_BOT_TOKEN=seu_token_aqui
   TELEGRAM_CHAT_ID=seu_chat_id_aqui
   ```

   O `.env` está no `.gitignore` e não é versionado.

## Uso

Enviar uma mensagem direta:

```bash
./telegram_notify.sh "Olá do meu bot"
```

Via wrapper (só envia se `.telegram_enabled` existir):

```bash
touch .telegram_enabled        # habilita
./telegram_wrapper.sh "mensagem opcional"
rm .telegram_enabled           # desabilita
```

Sem argumento, o wrapper envia uma mensagem padrão com data/hora.

## Requisitos

- `bash`
- `curl`
