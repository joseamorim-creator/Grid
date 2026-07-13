# Modelo de dados — como as 5 tabelas se conectam

Visão geral do fluxo de **quarentena / mal identificado** em FBM.

## Tabelas e grão
| Tabela | Grão | Papel |
|---|---|---|
| `DM_SHP_FBM_QUARANT` | `UNIT_ID` + `TASK_ID` | Unidade em quarentena (problema reportado x resultante) |
| `BT_FBM_STOCK_3_ADDRESS` | `INVENTORY_ID` + `ADDRESS_ID` (+grade/lote) | Onde o estoque está **agora** |
| `BT_FBM_STOCK_3_MOVEMENT` | evento (`FBM_OPE_ID`) | Movimentações (inbound, found, transfer...) |
| `BT_SHP_FBM_INVENTORY` | `INVENTORY_ID` (aninhado) | Cadastro do produto (GTIN, seller, família) |
| `DM_FBM_FPP_HIST` | issue (`FBM_ISSUE_ID`) | Ressarcimentos por dano/perda |

## 🔗 Grafo de junção
```
                         INVENTORY_ID  (chave universal)
   QUARANT ───────────────────┼───────────────── ADDRESS
   (UNIT/TASK)                 │                  (status/grade)
        │                      │                        │
        │                 INVENTORY                      │
        │            (GTIN, SELLER_ID, RELATION)         │
        │                      │                         │
        │              GTIN = identidade real            │
        │                                                │
   MOVEMENT ──── FBM_OPE_ID ────► FPP_HIST ◄── FBM_ISSUE_ID
   (JSON:                          (Paid?,       │
     ENTITY='inbound' → inbound_id  valor,       │
     ENTITY='issue'   → issue_id ───┘ tipo)      │
                                                 │
   seller:  INVENTORY.SELLER_ID = FPP.CUS_CUST_ID = QUARANT.CUS_NICKNAME
```

### Chaves
- **`INVENTORY_ID`** — liga todas.
- **`FBM_ISSUE_ID`** (FPP) = **`issue_id`** do JSON da MOVEMENT (`ENTITY='issue'`).
- **`FBM_OPE_ID`** (FPP) = **`FBM_OPE_ID`** da MOVEMENT.
- **`inbound_id`** (JSON MOVEMENT `ENTITY='inbound'`) = `INBOUND_ID`/`SHIPMENT_ID` (FPP).
- **GTIN** (`INVENTORY.IDENTIFIER.VALUE` onde `NAME='GTIN'`) = **identidade física** do produto.
- Seller: `INVENTORY.SELLER_ID` = `FPP.CUS_CUST_ID` = `QUARANT.CUS_NICKNAME`.

## 🏷️ Legenda de prefixos de endereço (observados)
| Prefixo | Significado |
|---|---|
| `QA-` | Quarentena |
| `NA-` | Não alocado |
| `MZ-` / `MU-` | Estoque (posições de picking/storage) |
| `DM-` | Dano (destino de itens danificados) |
| `RS-` | Recebimento/reserva (a confirmar) |
| `LT-` | Perda (Definitive Lost) (a confirmar) |

## ✅ Abordagem recomendada (nova)
Trocar o **match frágil por descrição** por identidade e status confiáveis:
1. **Identidade** via **GTIN** (`INVENTORY.IDENTIFIER`) — não por palavras da descrição.
2. **Estado** via `ADDRESS.FBM_STOCK_STATUS/SUBSTATUS/GRADE` e
   `QUARANT.RESULT_PROBLEM_TYPE/SUBTYPE` (desfecho confirmado).
3. **Financeiro** via `FPP_HIST` (`FRENADO_PAGO`, `FBM_ISSUE_TYPE`, valores) ligado por
   `FBM_ISSUE_ID`.
4. Sempre filtrar **`SITE_ID='MLB'`** + galpão, e **deduplicar** (grão UNIT/issue).
