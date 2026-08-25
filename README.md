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

## Integração com Claude Code (hook `Stop`)

Para receber uma notificação no Telegram sempre que o Claude Code terminar uma resposta, configure o `telegram_wrapper.sh` como hook do evento `Stop` em `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/SEU_CAMINHO/botMessage/telegram_wrapper.sh"
          }
        ]
      }
    ]
  }
}
```

Pontos importantes:

- O hook precisa ser do tipo `Stop` — é o evento disparado quando o agente finaliza a resposta. Outros eventos (`PreToolUse`, `PostToolUse`, etc.) gerariam notificações a cada ação, o que não é o objetivo.
- Use o caminho absoluto para o script; o Claude Code executa hooks fora do diretório do projeto.
- Como o wrapper só envia se `.telegram_enabled` existir, você pode ligar/desligar as notificações sem editar o `settings.json` — use os slash commands `/telegram_notification_on` e `/telegram_notification_off`, ou crie/remova o arquivo `.telegram_enabled` manualmente.

## Requisitos

- `bash`
- `curl`
