# Dicionário — `meli-bi-data.WHOWNER.DM_SHP_FBM_QUARANT`

Tabela de **quarentena** (unidades com problema reportado no fulfillment).
Baseado em amostra de `SELECT * ... LIMIT 1000` (2026-07-13).

> ⚠️ **Grão real = `UNIT_ID` + `TASK_ID`** (unidade física + tarefa), **não** `INVENTORY_ID`.
> E a amostra tem **linhas duplicadas** (mesma unidade/tarefa repetida, variando só
> `ITE_BASE_CURRENT_PRICE`) → sempre deduplicar antes de contar.

## Colunas

### 🔑 Identificação
| Coluna | Tipo | Significado |
|---|---|---|
| `UNIT_ID` | id | **Unidade física** em quarentena (o grão de verdade) |
| `TASK_ID` | id | Tarefa de tratamento da unidade |
| `INVENTORY_ID` | id | Inventário/SKU (o que usávamos p/ join) |
| `ADDRESS_ID` | string | Posição — aqui é **`QA-...`** (área de quarentena), ≠ dos `NA-...` da tabela de estoque |

### 🚦 Status
| Coluna | Exemplos | Significado |
|---|---|---|
| `UNIT_STATUS` | `pending` | Situação da unidade |
| `TASK_STATUS` | `waiting_review` | Situação da tarefa |
| `REPORTER_USER_ID` | `2554480` | Quem reportou |
| `SOLVER_USER_ID` | `null` | Quem resolveu (`null` = ainda aberto) |
| `TASK_PROCESS_NAME` | `packing`, `picking`, `stand_alone` | Processo onde o problema foi detectado |

### 🩺 Problema REPORTADO (na entrada)
| Coluna | Exemplos | Significado |
|---|---|---|
| `REPORTED_PROBLEM_TYPE` | `damaged`, `identification` | Tipo reportado |
| `REPORTED_PROBLEM_TYPE_ID` | `1` | Id do tipo |
| `REPORTED_PROBLEM_DESCRIPTION` | `Product is broken` | Descrição livre |

### ✅ Problema RESULTANTE (após análise) — pode substituir suposição por fato
| Coluna | Significado |
|---|---|
| `RESULT_PROBLEM_TYPE` | Tipo **confirmado** após tratamento (`null` enquanto não resolvido) |
| `RESULT_PROBLEM_TYPE_ID` | Id do tipo resultante |
| `RESULT_PROBLEM_DESCRIPTION` | Descrição do resultado |
| `RESULT_PROBLEM_SUBTYPE` | **Sub-tipo** do resultado |
| `PROBLEM_SUBTYPE_ID` | Id do sub-tipo |
| `PROBLEM_SUBTYPE_DESCRIPTION` | Descrição do sub-tipo |

### 🕒 Datas
| Coluna | Significado |
|---|---|
| `UNIT_CREATED_DTTM` / `UNIT_UPDATED_DTTM` | Criação/atualização da unidade em quarentena |
| `TASK_CREATED_DTTM` / `TASK_UPDATED_DTTM` | Criação/atualização da tarefa |
| `UNIT_CREATED_DTTM_TZ` / `TASK_CREATED_DTTM_TZ` | Versões com timezone (+1h na amostra) |

### 🏬 Contexto / Produto / Comercial
| Coluna | Exemplos | Significado |
|---|---|---|
| `WAREHOUSE_ID` | `BRSP06` | Galpão (a tabela cobre **vários**, não só BRSP04) |
| `ITE_BASE_CURRENT_PRICE` | `6.64`, `43.24` | Preço atual do item (varia entre linhas duplicadas) |
| `CAT_CATEG_ID_L7` | `269718` | Id de categoria (nível 7) |
| `CAT_CATEG_NAME_L1/L2/L3` | `Livros` / `História` / `Brasil` | Árvore de categoria |
| `CUS_NICKNAME` | `REDSHOPDOBRASILOFICIAL` | **Seller** (nickname) — enriquecimento que não tínhamos |

### 🧾 Auditoria
| Coluna | Significado |
|---|---|
| `AUD_FROM_INTERFACE` | Interface de origem (ex.: `DM_SHP_FBM_FPP_LOST`) |
| `AUD_INS_DTTM` / `AUD_UPD_DTTM` | Datas de carga/atualização do registro |
| `AUD_TRANSACTION_ID` | Id da transação de carga |

## 💡 Insights que mudam a análise
1. **Grão = `UNIT_ID`, não `INVENTORY_ID`.** Cada peça física tem seu `UNIT_ID`/`TASK_ID`.
   Contar/juntar por `INVENTORY_ID` mistura unidades diferentes do mesmo SKU.
2. **Duplicatas reais** na tabela → usar `SELECT DISTINCT` ou `QUALIFY` por `UNIT_ID`/`TASK_ID`.
3. **`RESULT_PROBLEM_*` e `PROBLEM_SUBTYPE_*`** dão o **desfecho confirmado** — dá pra
   parar de adivinhar com match de descrição e usar o diagnóstico oficial.
4. **`ADDRESS_ID` aqui é `QA-...`** (quarentena), diferente do `NA-...` do estoque — são
   espaços de endereço distintos.
5. **`CUS_NICKNAME`** = seller; **`CAT_*`** = categoria; **`ITE_BASE_CURRENT_PRICE`** = preço.
