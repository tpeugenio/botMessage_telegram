# Slash commands do Claude Code

Esta pasta contém **slash commands customizados** para o [Claude Code](https://docs.claude.com/claude-code). Cada arquivo `.md` vira um comando `/<nome-do-arquivo>` disponível no chat.

## O que tem aqui

- **`telegram_notification_on.md`** → comando `/telegram_notification_on`
  Cria o arquivo flag `.telegram_enabled` na pasta do projeto `botMessage`, fazendo com que o `telegram_wrapper.sh` passe a enviar notificações ao concluir tarefas.

- **`telegram_notification_off.md`** → comando `/telegram_notification_off`
  Remove o arquivo flag, desligando as notificações sem precisar mexer em código ou hooks.

Os dois funcionam como um interruptor global de notificações via Telegram durante o uso do Claude Code.

## Onde esses arquivos devem ficar

O Claude Code procura slash commands em dois lugares:

| Escopo | Caminho | Quando usar |
|--------|---------|-------------|
| **Usuário** (global, todos os projetos) | `~/.claude/commands/` | Recomendado para estes scripts — você quer ligar/desligar notificações em qualquer projeto. |
| **Projeto** (versionado no repo) | `<projeto>/.claude/commands/` | Quando o comando faz sentido só dentro daquele repositório. |

### Instalação rápida (escopo usuário)

```bash
mkdir -p ~/.claude/commands
cp telegram_notification_on.md telegram_notification_off.md ~/.claude/commands/
```

Depois, dentro do Claude Code, digite `/telegram_notification_on` ou `/telegram_notification_off`.

## Ajuste obrigatório do caminho

Os arquivos referenciam `SEU_CAMINHO/botMessage/.telegram_enabled`. Antes de usar, troque `SEU_CAMINHO` pelo caminho absoluto da pasta onde você clonou este repositório. Exemplo no macOS:

```bash
sed -i '' "s|SEU_CAMINHO|$HOME/development|g" ~/.claude/commands/telegram_notification_on.md ~/.claude/commands/telegram_notification_off.md
```

Esse caminho precisa ser o mesmo que `telegram_wrapper.sh` consulta para a flag — por isso ele tem que apontar para a pasta real do projeto `botMessage`.

## Como funciona o fluxo completo

1. Você configura um hook do Claude Code (ex.: no `Stop`) chamando `telegram_wrapper.sh`.
2. O wrapper só dispara o `telegram_notify.sh` se `.telegram_enabled` existir.
3. Os comandos desta pasta criam/removem esse arquivo — ligando e desligando as notificações sob demanda, sem editar configuração.
