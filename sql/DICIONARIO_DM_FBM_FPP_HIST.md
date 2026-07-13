# Dicionário — `meli-bi-data.WHOWNER.DM_FBM_FPP_HIST`

**Histórico de FPP** = ressarcimentos por *issues* de estoque (dano, perda, roubo,
devolução). Uma linha ≈ um issue conciliado que gerou (ou não) pagamento ao seller.
Tabela **multi-país** (LATAM). Fonte: `STG.FPP_HIST`.

## 🔗 Chaves de junção (o mais importante)
| Coluna | Liga com | Uso |
|---|---|---|
| `INVENTORY_ID` | todas as tabelas | SKU |
| **`FBM_ISSUE_ID`** | `issue_id` do JSON da MOVEMENT (`ENTITY='issue'`) | 👈 amarra o **found/lost&found** ao ressarcimento |
| **`FBM_OPE_ID`** | `FBM_OPE_ID` da MOVEMENT | amarra à operação de movimento |
| `INBOUND_ID` / `SHIPMENT_ID` | `inbound_id` do JSON da MOVEMENT (`ENTITY='inbound'`) | recebimento (null na amostra) |
| `CUS_CUST_ID` / `CUS_NICKNAME` | `SELLER_ID` (INVENTORY) / `CUS_NICKNAME` (QUARANT) | seller |

## 🩺 Issue
| Coluna | Exemplos | Significado |
|---|---|---|
| `FBM_ISSUE_TYPE` | `Damaged`, `Return`, `Definitive Lost`, `Definitive Lost Cancelled` | Tipo do issue |
| `FBM_ISSUE_CONDITION` | `DAMAGED_BY_MELI`, `DAMAGED_BY_CARRIER`, `FRAUD_REVERSE`, `AVAILABLE` | Condição/causa |
| `FBM_ISSUE_STATUS` | `CONCILIATED` | Status |
| `FBM_PROCESS_NAME` | `Quarantine`, `Return`, `Expedition`, `Cycle count`, `Stock audit` | Processo de origem |
| `MOVEMENT_CODE` / `MOVEMENT_NAME` | `INV0DMGQA` / `QUARANTINE_DMG` | Código/nome do movimento |
| `FBM_ISSUE_DATE_CREATED` | — | Data de criação do issue |
| `ADDRESS_ID_FROM` / `ADDRESS_ID_TO` | `QA-...`→`DM-...` | De/para (ex.: quarentena → dano) |
| `FBM_ISSUE_QTY` | `1` | Quantidade |
| `LAST_ADDRESS` | `MU-TT-RC-...` | Último endereço conhecido |

## 💰 Financeiro
| Coluna | Significado |
|---|---|
| **`FRENADO_PAGO`** | **`Paid` / `Pending`** — se o ressarcimento foi pago |
| `PAY_PAYMENT_ID` / `PAYMENT_ALL_ID` | Ids de pagamento |
| **`PAY_CREATED_DATETIME`** | Data do pagamento (era o filtro do `PAGOS`) |
| `MOV_LC_AMOUNT` / `MOV_DOL_AMOUNT` | Valor movido (moeda local / USD) |
| `FBM_REFERENCE_COST_LC` / `_DOL` | Custo de referência |
| `FBM_INSURANCE_COST_LC` / `_DOL` | Custo de seguro |
| `ADD_AMOUNT` / `ADD_AMOUNT_USD` | Valor adicional |
| `RECUPERO_BILLING_AMT_USD` / `TOTAL_AMT_USD` | Recupero / total |
| `MOV_CURRENCY_ID`, `USD_RATIO` | Moeda / câmbio |
| `TIPO_DE_PAGO` | Tipo de pagamento |

## 🏷️ Produto / seller / classificação
| Coluna | Exemplos |
|---|---|
| `ITEM_TITLE` | Título do produto |
| `ITE_ITEM_DOM_DOMAIN_ID` | `MLM-UMBRELLAS` (domínio/categoria) |
| `CAT_CATEG_NAME_L1` / `VERTICAL` | `Eletrodomésticos` / `CE` |
| `MARCA` / `OFS_BRAND_FANTASY_NAME` | Marca |
| `TIPOSELLER` | `1P` / `3P` |
| `HV` | `HV` / `NO HV` (high value) |

## 🌎 Geografia / operação / auditoria
`SITE_ID`/`SIT_SITE_ID`, `REGION`, `COUNTRY`, `GRUPO`, `FUSION`, `CLUSTER_OPS`,
`CLUSTER_ICQA`, `WAREHOUSE_ID`, `FLAG_FAST_TRACK`, `PACKAGING_TYPE`, `COMMINGLING`,
`AUD_INS_DTTM`, `AUD_UPD_DTTM`, `AUD_FROM_INTERFACE`, `AUD_TRANSACTION_ID`.

## 💡 Insights
1. **`FBM_ISSUE_ID` é a ponte** entre o "found" (lost&found da MOVEMENT) e o
   **ressarcimento**. Dá pra saber se um item achado em NA já foi **pago** como perdido.
2. **`FRENADO_PAGO='Paid'` + `FBM_ISSUE_TYPE='Definitive Lost'`** = item ressarcido como
   perdido. Se esse mesmo item **reaparece** (found em NA), é dinheiro a recuperar.
3. Filtrar por **`SITE_ID='MLB'`** (Brasil) e pelo galpão.
4. Substitui o `PAGOS` antigo (que só olhava `PAY_CREATED_DATETIME`) por algo bem mais rico.
