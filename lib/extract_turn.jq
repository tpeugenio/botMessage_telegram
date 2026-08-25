# Extrai o contexto do último turno de um transcript (.jsonl) do Claude Code.
# Entrada: array de entradas do transcript (usar `jq -s`).
# Saída: objeto com prompt, promptTs, reply, tools, subagents, cwd, branch.

def txt:
  if (.message.content | type) == "string" then .message.content
  elif (.message.content | type) == "array" then
    ([.message.content[]? | select(.type == "text") | .text] | join("\n"))
  else "" end;

def isRealUser:
  .type == "user"
  and ((.isMeta // false) | not)
  and ((.isSidechain // false) | not)
  and (has("toolUseResult") | not)
  and ((txt | length) > 0);

def isMainAssistant:
  .type == "assistant" and ((.isSidechain // false) | not);

. as $all
| ([range(0; ($all | length)) | select($all[.] | isRealUser)] | last) as $i
| (if $i == null then $all else $all[$i:] end) as $turn
| {
    prompt:    (if $i == null then "" else ($all[$i] | txt) end),
    promptTs:  (if $i == null then "" else ($all[$i].timestamp // "") end),
    reply:     ([$turn[] | select(isMainAssistant) | .message.content[]?
                         | select(.type == "text") | .text] | last // ""),
    tools:     ([$turn[] | select(isMainAssistant) | .message.content[]?
                         | select(.type == "tool_use") | .name]
                | group_by(.) | map({name: .[0], n: length}) | sort_by(-.n)),
    subagents: ([$turn[] | select(isMainAssistant) | .message.content[]?
                         | select(.type == "tool_use" and .name == "Agent")] | length),
    cwd:       ([$all[] | .cwd? // empty] | last // ""),
    branch:    ([$all[] | .gitBranch? // empty] | last // "")
  }
