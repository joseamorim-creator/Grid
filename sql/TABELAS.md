# Tabelas usadas na análise

Todas no dataset **`meli-bi-data.WHOWNER`**. São **5 tabelas físicas distintas**
— a de movimentação (`BT_FBM_STOCK_3_MOVEMENT`) é lida 3 vezes, em CTEs diferentes.

| # | Tabela | Papel na análise | Usada em (CTE) | Colunas usadas |
|---|---|---|---|---|
| 1 | `meli-bi-data.WHOWNER.DM_SHP_FBM_QUARANT` | Itens em **quarentena** | `QA` | `WAREHOUSE_ID`, `INVENTORY_ID`, `REPORTED_PROBLEM_TYPE`, `UNIT_CREATED_DTTM` |
| 2 | `meli-bi-data.WHOWNER.BT_FBM_STOCK_3_ADDRESS` | **Estoque por endereço** | `NA` | `WAREHOUSE_ID`, `INVENTORY_ID`, `ADDRESS_ID`, `FBM_AVAILABLE`, `FBM_RESERVED` |
| 3 | `meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT` | **Movimentações** de estoque | `ORIGEM`, `POS_ORIGEM`, `FOUND` | `WAREHOUSE_ID`, `INVENTORY_ID`, `ADDRESS_FROM`, `ADDRESS_TO`, `FBM_CREATED_DATE`, `FBM_REASON_PROCESS`, `FBM_QUANTITY` |
| 4 | `meli-bi-data.WHOWNER.BT_SHP_FBM_INVENTORY` | **Cadastro do produto** (descrição/custo) | `INV` | `INVENTORY_ID`, `DESCRIPTION`, `REFERENCE_COST`, `SITE_ID` |
| 5 | `meli-bi-data.WHOWNER.DM_FBM_FPP_HIST` | Histórico de **pagamentos (FPP)** | `PAGOS` | `INVENTORY_ID`, `PAY_CREATED_DATETIME`, `WAREHOUSE_ID` |

## Notas

- **Prefixos:** `DM_` = data mart (quarentena e pagamentos), `BT_` = base/tabela
  transacional (endereço, movimentação, inventário).
- **A mais "trabalhada":** `BT_FBM_STOCK_3_MOVEMENT`, lida 3 vezes com filtros
  diferentes — origem do item (`ORIGEM`), última posição de origem (`POS_ORIGEM`)
  e os "achados" inbound (`FOUND`).
- **Chaves de junção:** `INVENTORY_ID` costura tudo, com apoio de `WAREHOUSE_ID`
  e `ADDRESS_ID` / `ADDRESS_TO` nos joins.
