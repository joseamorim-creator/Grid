# CLAUDE.md

Guia para o Claude Code neste repositório, seguindo o arquétipo **Backend Developer (Fury / Meli)**.

## Conteúdo do repositório

- `kanban.html` — board Kanban no navegador, com geração de tarefas via Gemini (a chave é informada pelo usuário e fica no `localStorage`).
- `cronograma.html` — cronograma de turnos, com persistência opcional na API do Grid (`GRID_API`).
- `loja.py` — app de compras em terminal (Python 3, depende de `rich`).

## Fluxo obrigatório (SDD Meli)

Toda funcionalidade nova segue o ciclo completo, sem pular etapas:

1. `/meli.start` — abre a feature (e o ticket no JIRA-LOCAL).
2. `/meli.spec` — spec funcional **e** técnica. **Nunca** rodar `/meli.build` sem spec.
3. `/meli.plan` — plano de implementação.
4. `/meli.build` — implementação, com testes LTP gerados junto.
5. `/meli.check` — validação; obrigatório antes do `/meli.finish`.
6. `/meli.finish` — fecha a feature. Não deixar nada parado em `wip/`.

Para features complexas, consultar `meli-sdd-kit-expert` antes da spec.

## Convenções Fury

- **Antes de criar qualquer serviço ou dependência nova**, buscar se já existe via FuryMCP
  (`fury__search_api_specs`, `fury__search_api_docs`) e consultar `fury-services-architect`.
- Integrações com SDKs Fury (KVS, BigQueue, clientes HTTP) seguem os padrões do `fury-snippets-expert`.
  Não escrever cliente HTTP "na mão" quando existir um padrão Fury.
- Tickets e transições de status pelo JIRA-LOCAL.
- Todo endpoint novo precisa de testes LTP (LargeTestingPlatformMCP).

## Segurança

As regras completas estão em `.agentic-rules/security.md`. Resumo:

- Nada de credenciais, tokens ou chaves no código. Use variáveis de ambiente ou secrets do Fury.
- Chaves de API vão em header, nunca em query string (ex.: Gemini usa `x-goog-api-key`).
- Toda entrada externa (usuário, `localStorage`, respostas de APIs/IA) é validada antes do uso.
  No DOM, usar `textContent` em vez de `innerHTML` para dados externos.
- `/security-review` em todo PR que toca autenticação, entrada do usuário ou dados externos,
  e validação com `ApplicationSecurityMCP` antes de entregar.
- `/review` antes de fazer merge na `main`.

## Hooks

`.claude/settings.json` registra um hook PreToolUse (`.claude/hooks/pre_write_scan.py`) que
bloqueia escritas contendo segredos aparentes e arquivos `.py` com erro de sintaxe.

## MCPs

`.mcp.json` declara FuryMCP, JIRA-LOCAL, ApplicationSecurityMCP e LargeTestingPlatformMCP.
As URLs vêm de variáveis de ambiente (`FURY_MCP_URL`, `JIRA_LOCAL_MCP_URL`,
`APPSEC_MCP_URL`, `LTP_MCP_URL`); configure-as no seu ambiente antes de usar.
