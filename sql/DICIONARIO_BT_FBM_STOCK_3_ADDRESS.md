# Dicionário — `meli-bi-data.WHOWNER.BT_FBM_STOCK_3_ADDRESS`

**Snapshot do estoque atual** por (item × endereço). Baseado em amostra
`SELECT * ... LIMIT 1000` (2026-07-13). Tabela é **multi-site/multi-galpão**
(amostra tem `ARBA01`/`CLRM03` = Argentina/Chile, sites `MLA`/`MLC`).

> Grão ≈ (`INVENTORY_ID`, `ADDRESS_ID`), mas pode ter **mais de uma linha** por
> combinações de `FBM_STOCK_GRADE` / `FBM_BATCH` / `FBM_STOCK_STATUS` → fonte da
> "inflação" que vimos (60 linhas ≈ 15 itens).

## Colunas

### 🔑 Identificação / localização
| Coluna | Exemplos | Significado |
|---|---|---|
| `INVENTORY_ID` | `SFGU94386` | Inventário/SKU |
| `ADDRESS_ID` | `NA-...`, `MZ-3-...`, `RS-0-...` | Endereço. Prefixos: **NA** = não alocado, **MZ/MU** = estoque, **QA** = quarentena, **RS** = (a confirmar) |
| `WAREHOUSE_ID` | `ARBA01`, `CLRM03` | Galpão |
| `SIT_SITE_ID` | `MLA`, `MLB`, `MLC` | Site/país (Brasil = `MLB`) |
| `ORIGINAL_INVENTORY_ID` | `null` | 👀 **Inventário original** — se populado, liga item relabelado ao original (checar em BRSP04) |

### 📦 Quantidades / disponibilidade
| Coluna | Exemplos | Significado |
|---|---|---|
| `FBM_QUANTITY` | `1` | Quantidade na posição |
| `FBM_AVAILABLE` | `1`/`0` | Disponível (qtd/flag) |
| `FBM_RESERVED` | `0` | Reservado |
| `FBM_ARRIVING` | `0` | Em trânsito/chegando |

### 🏷️ Estado do estoque  ← provável chave da análise
| Coluna | Exemplos | Significado |
|---|---|---|
| `FBM_STOCK_STATUS` | `ok` | **Status** do estoque (checar valores p/ quarentena/bloqueado) |
| `FBM_STOCK_SUBSTATUS` | `ok` | **Sub-status** (idem) |
| `FBM_STOCK_GRADE` | `a` | Grade/qualidade (`a` = bom; b/c?) |
| `FBM_BATCH` | `2028-12-30`, `null` | Lote/validade |

### 🕒 Datas / origem do registro
| Coluna | Significado |
|---|---|
| `FBM_CREATED_DATE` / `FBM_LAST_UPDATED` | Criação / última atualização da posição |
| `FBM_CREATED_BY_APP` | App que criou (`fbm-wms-transfer`, `fbm-wms-issues`, `fbm-wms-routes-unit-handler`) |
| `FBM_CREATED_BY_USER` / `FBM_UPDATED_BY_USER` | Usuários |
| `FBM_UPDATED_BY_APP` | App que atualizou |
| `AUD_INS_DTTM` / `AUD_UPD_DTTM` / `AUD_TRANSACTION_ID` | Auditoria de carga |
| `AUD_FROM_INTERFACE` | Interface de origem |

## 💡 Insights
1. **`FBM_STOCK_STATUS`/`SUBSTATUS`/`GRADE`** podem identificar estoque problemático
   direto — talvez sem precisar cruzar com a tabela de quarentena. Checar valores distintos.
2. **`ORIGINAL_INVENTORY_ID` existe aqui também** — na movimentação veio vazio; vale
   checar se nesta tabela vem populado em BRSP04 (seria o vínculo direto do relabel).
3. **Múltiplas linhas por (item, endereço)** por grade/batch/status → deduplicar/agregar.
4. **Filtrar `SIT_SITE_ID='MLB'`** (e o galpão) p/ ficar só no Brasil.
