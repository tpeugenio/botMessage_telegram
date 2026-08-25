# botMessage

Scripts em Bash para enviar notificações ao Telegram via API de bots. Útil para receber avisos de tarefas concluídas (ex.: integração com Claude Code).

## Arquivos

- `telegram_notify.sh` — envia uma mensagem para o Telegram usando a API de bots.
- `telegram_wrapper.sh` — lê o JSON do hook do Claude Code no stdin e monta uma mensagem com contexto (projeto, branch, pedido, resposta, ferramentas, duração). Só dispara o `notify` se o arquivo flag `.telegram_enabled` existir (liga/desliga sem mexer no código).
- `lib/extract_turn.jq` — programa `jq` que extrai o último turno do transcript (`.jsonl`) do Claude Code.
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

## Formato da mensagem

Em vez de um aviso genérico, o wrapper monta algo assim:

```
✅ Turno concluído · 📁 eugeniolab

💬 Pedido
> /agent-spec-minispec-generate-tasks @docs/.../intent.md

📝 Resposta
> Arquivos parciais salvos (task_plan.md + tasks/T1..T10.md)…

🌿 222-featcore-indicador-de-registro-nao-sincronizado
📄 2 alterado(s)
🔧 Bash×21 · Write×8 · Agent×3 · 🤖 3 subagente(s)
🕐 25/08 09:35 · ⏱ 14m 55s
```

De onde vem cada pedaço:

| Campo | Origem |
|-------|--------|
| Projeto | `basename` do `cwd` do payload do hook |
| Pedido | último prompt real do usuário no transcript (system-reminders e wrappers de slash command são removidos) |
| Resposta | último bloco de texto do assistente no turno (subagentes são ignorados) |
| Branch / arquivos alterados | `gitBranch` do transcript + `git status --porcelain` |
| Ferramentas / subagentes | `tool_use` do turno atual, agrupados por nome |
| Duração | agora menos o timestamp do último prompt do usuário |

Eventos suportados (`hook_event_name` do payload):

- **`Stop`** — turno concluído, mensagem completa.
- **`Notification`** — mensagem do Claude (ex.: pedido de permissão) em destaque, com resposta encurtada e sem estatísticas.
- **`SubagentStop`** e demais — cabeçalho genérico com o mesmo contexto.

Sem stdin (ou sem `jq`), o wrapper cai no comportamento antigo: título fixo — ou o passado como `$1` — mais projeto, branch e hora.

### Variáveis opcionais (`.env`)

| Variável | Padrão | Efeito |
|----------|--------|--------|
| `TELEGRAM_MAX_PROMPT_CHARS` | `350` | Corte do trecho do pedido |
| `TELEGRAM_MAX_REPLY_CHARS` | `900` | Corte do trecho da resposta |
| `TELEGRAM_MIN_DURATION_SECONDS` | `0` | No `Stop`, ignora turnos mais curtos que isso (reduz ruído de respostas rápidas) |
| `TELEGRAM_PARSE_MODE` | `HTML` | Vazio envia texto puro (usado no fallback automático se o HTML for recusado) |

## Requisitos

- `bash`
- `curl`
- `jq` (opcional — sem ele, a mensagem cai no formato simples)
- `perl` (opcional — usado para limpar o texto do prompt)
