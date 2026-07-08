# Análise — Quarentena "identification" x itens achados (FOUND) em NA (BRSP04)

Correlaciona itens em **quarentena por `identification`** parados em endereços
`NA%` (não alocados) com itens **"achados"** (inbound, sem `ADDRESS_FROM`) que
caíram no **mesmo endereço NA** depois — e que provavelmente são o **mesmo
produto** entrado com outro `INVENTORY_ID` (match por similaridade de descrição).

## Arquivos

| Arquivo | Para quê |
|---|---|
| `quarentena_identificacao_afrouxada.sql` | Versão **afrouxada** da consulta, para trazer **mais casos**. |
| `quarentena_identificacao_funil_diagnostico.sql` | Conta quantos casos sobrevivem a **cada etapa** do funil — mostra **onde** as linhas somem. |

## Por que a original trazia só ~60 linhas?

Rode `quarentena_identificacao_funil_diagnostico.sql`: as etapas **0→6**
reproduzem a query original e a etapa onde a contagem despenca é o gargalo.
Os três maiores estranguladores costumam ser, nesta ordem:

1. **Match de descrição `>= 2`** — exige 2+ palavras (3+ letras) iguais, e o
   `SPLIT(... , ' ')` não trata acento/pontuação (`"cabo,"` ≠ `"cabo"`). Itens
   sem descrição em `INV` (`SITE_ID='MLB'`) também caem em silêncio.
2. **Filtro `(ORIGEM.ADDRESS_FROM IS NULL OR = '')`** — trava em origem inbound
   e torna **inalcançáveis** as categorias `MZ`/`MU`/`NA` do próprio
   `CASE ORIGEM_TIPO`.
3. **`FOUND.DATA_FOUND > ...`** com datas truncadas em `DATE` — descarta o
   achado no **mesmo dia** da quarentena.

> Não é limitador: `PAGOS` (a data `'2026-01-01'`) entra por `LEFT JOIN` e só
> alimenta o rótulo `POSSUI_PAGAMENTO` — não corta linhas.

## O que a versão afrouxada muda

1. Janela **180 → 365 dias**.
2. Match **`>= 2` → `>= 1`** + **normalização** (remove acento/pontuação, casefold).
3. Data **`>` → `>=`** (inclui o mesmo dia).
4. **Remove** o filtro de origem inbound.

### Botões de ajuste (na query afrouxada)

- **Janela**: os `INTERVAL 365 DAY`.
- **Sensibilidade do match**: o `>= 1` no fim do `WHERE` (suba p/ `>= 2` se
  aparecerem falsos positivos demais).
- **Falsos positivos**: adicione stopwords no `WHERE` do match, ex.:
  `AND palavra_qa NOT IN ('kit','com','para','cor','preto','branco','und')`.
