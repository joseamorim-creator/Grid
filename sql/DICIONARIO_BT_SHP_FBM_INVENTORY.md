# Dicionário — `meli-bi-data.WHOWNER.BT_SHP_FBM_INVENTORY`

**Cadastro do produto/inventário.** Tabela **aninhada** (STRUCT/ARRAY) — vários
campos são repetidos, por isso um `SELECT *` "explode" cada inventário em
sub-linhas. Multi-site (amostra é `MLM` = México; Brasil = `MLB`).

> ⚠️ Ao juntar, **selecione só escalares** (ex.: `DESCRIPTION`, `REFERENCE_COST`)
> para não multiplicar linhas. Para GTIN/atributos, use `UNNEST(...)` controlado.

## Colunas escalares (chave)
| Coluna | Exemplos | Significado |
|---|---|---|
| `INVENTORY_ID` | `KOEQ85160` | SKU/inventário |
| `SELLER_ID` | `623923806` | **Seller** (id numérico) |
| `ITEM_ID` | `MLM1951754091` | Item/anúncio no marketplace |
| `VARIATION_ID` | `null` | Variação do item |
| `SITE_ID` | `MLM`, `MLB` | Site/país |
| `TYPE` | `meli_item` | Tipo de inventário |
| `DESCRIPTION` | `Casco Seguridad...` | Título/descrição |
| `REFERENCE_COST` | `169` | **Valor de referência** do produto |
| `INSURANCE_COST` | `148.72` | Custo de seguro |
| `FAMILY_ID` / `FAMILY_NAME` | `2294935169610027963` | **Família** do produto (agrupa variações) |
| `USER_PRODUCT_ID` | `MLMU891923030` | Id do produto do usuário |
| `HAS_EXPIRATION_DATE` | `false` | Tem validade? |
| `OPT_IN_DATE` / `DATE_CREATED` | — | Datas de entrada/criação |
| `AUD_INS_DTTM` / `AUD_UPD_DTTM` | — | Auditoria |

## Campos aninhados (ARRAY/STRUCT)
| Campo | Sub-campos | Significado |
|---|---|---|
| **`IDENTIFIER`** | `NAME` (`UPC`/`GTIN`), `VALUE` (`765619003254`) | 🔥 **Código de barras** — identidade física do produto |
| `PICTURE` | `ID`, `NAME`, `URL`, `SECURE_URL` | Foto do produto |
| `TAG` | `sortable`, `totable`, `operates_by_pi`, `family_gm` | Tags de operação |
| `PRODUCT_ATTRIBUTE` | `VALUE_ID`, `VALUE_NAME`, `TYPE` (`SHIPMENT_PACKING`) | Atributos |
| **`INVENTORY_RELATION`** | `INVENTORY_ID`, `ITEM_ID`, `VARIATION_ID`, `ACTIVE`, `VERSION` | 🔥 **Relações item↔inventário** (possível vínculo relabel) |
| `DIMENSIONS_SET` | `WIDTH/HEIGHT/LENGTH/WEIGHT` + unidades | Dimensões/peso |
| `USER_PRODUCT_HISTORY` | `USER_PRODUCT_ID` | Histórico de produto |

## 💡 Insights (podem resolver o "mal identificado" de vez)
1. **`IDENTIFIER` (GTIN/UPC) é a identidade real do produto.** Dois `INVENTORY_ID`
   diferentes que são o **mesmo produto físico** tendem a compartilhar o **mesmo GTIN**.
   → Substitui o match frágil por descrição por um match **exato por código de barras**.
2. **`INVENTORY_RELATION`** pode dar o vínculo **explícito** entre inventários
   (mesmo produto/variação) — investigar se liga o item relabelado ao correto.
3. **`FAMILY_ID`** agrupa variações do mesmo produto — útil como match intermediário.
4. **`SELLER_ID`** aqui + `CUS_NICKNAME` na quarentena = dá pra confirmar dono.
5. Filtrar **`SITE_ID='MLB'`** e cuidar do aninhamento (UNNEST só quando necessário).
