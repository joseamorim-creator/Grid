# Regras de segurança

Regras que o agente deve seguir em toda alteração neste repositório.

## Segredos
- Proibido commitar credenciais, tokens, chaves de API, senhas ou certificados.
- Segredos de backend vêm de variáveis de ambiente ou do gerenciador de secrets do Fury.
- Chaves informadas pelo usuário no front-end ficam só no navegador e nunca são logadas.
- Chaves de API trafegam em header (ex.: `Authorization`, `x-goog-api-key`), nunca na URL.

## Entrada e dados externos
- Validar tipo, formato e tamanho de toda entrada: formulários, `localStorage`, arquivos importados,
  respostas de APIs e de modelos de IA.
- Respostas de IA são dados não confiáveis: fazer parse defensivo e checar a estrutura esperada.
- No DOM, renderizar dados externos com `textContent`/`createElement`; evitar `innerHTML`
  com conteúdo que não seja literal do código.
- Em Python, não usar `eval`/`exec`/`pickle` em dados externos; tratar `json.JSONDecodeError`.

## Autenticação e chamadas HTTP
- Chamadas a serviços internos usam os clientes do `fury-snippets-expert`.
- `credentials: "include"` só para endpoints confiáveis da própria plataforma (ex.: API do Grid).
- Usar sempre HTTPS.

## Processo
- `/security-review` obrigatório em PRs que tocam autenticação, entrada do usuário ou dados externos.
- Validar com `ApplicationSecurityMCP` antes de `/meli.finish`.
