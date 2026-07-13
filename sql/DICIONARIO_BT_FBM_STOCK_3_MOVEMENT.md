# Dicionário — `meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT`

**Histórico de movimentações** de estoque (uma linha por evento de movimento).
Multi-galpão/multi-país (amostras: `MXRC02`, `BRRC01`, `BRSP04`...).

## Colunas
| Coluna | Tipo | Significado |
|---|---|---|
| `FBM_OPE_ID` | STRING (uuid) | Id da operação/movimento |
| `WAREHOUSE_ID` | STRING | Galpão |
| `INVENTORY_ID` | STRING | Inventário/SKU movido |
| `FBM_REASON_PROCESS` | STRING | Processo que gerou (`PICK`, `lostnfound`, `stock_audit`, `cycle_count`, ...) |
| `FBM_REASON_ENTITY` | STRING | **Tipo de entidade que originou** — `inbound`, `issue`, ... 👈 discriminador chave |
| `FBM_REASON_ID` | STRING | Id da entidade (uuid ou `lostAndFound-<uuid>`) — **cru, 2 formatos** |
| `FBM_REASON_EXTERNAL_REFERENCES` | JSON | 🔥 **Referências** (ver decodificação abaixo). Coluna **pesada** — só ler quando necessário |
| `FBM_CREATED_DATE` | DATETIME | Data do movimento (provável partição) |
| `ADDRESS_FROM` | STRING | Origem (`NULL` = inbound/achado sem origem) |
| `ADDRESS_TO` | STRING | Destino (`NA-...`, `MU-...`, `MZ-...`) |
| `FBM_QUANTITY` | NUMERIC | Quantidade |
| `FBM_EVENT_ID` | STRING | Id do evento |
| `FBM_EVENT_TYPE` | STRING | Tipo (`MovementPerformed`) |
| `FBM_USER_ID` | NUMERIC | Usuário |
| `AUD_INS_DTTM` / `AUD_UPD_DTTM` / `AUD_TRANSACTION_ID` | — | Auditoria de carga |
| `AUD_FROM_INTERFACE` | STRING | Interface (`BQ_BT_FBM_STOCK_3_MOVEMENT`) |
| `DETACH_DESTINATION` | STRING | Destino de detach (null na amostra) |
| `FBM_ACTIONS_EXTERNAL_REFERENCES` | JSON | Refs de ações (null na amostra) |
| `ORIGINAL_INVENTORY_ID` | STRING | Inventário original (⚠️ **vazio** nesse fluxo — 0/102525 em BRSP04→NA) |

## 🔓 Decodificação do JSON `FBM_REASON_EXTERNAL_REFERENCES`
Depende de `FBM_REASON_ENTITY`:

### Quando `ENTITY = 'inbound'` (recebimento real) 👈 **o "IS"**
```json
{"fiscal_source_id":"38847056","fiscal_source_type":"inbound",
 "inbound_id":"38847056","partiality_id":"d7235255-..."}
```
- **`inbound_id`** = **Inbound Shipment (IS)** — o que a gente procurava!
  → `JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.inbound_id')`

### Quando `ENTITY = 'issue'` (lost & found / conciliação)
```json
{"fiscal_source_type":"found","issue_id":"1351564704",
 "issue_uuid":"e9f3464e-...","movement_code":"NS_FOUND","source":"lost_and_found-v3"}
```
- **`issue_id`** = id do evento de achado/auditoria (NÃO é inbound).
  → `JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.issue_id')`

## 💡 Insights
1. **O IS existe e é o `inbound_id` do JSON quando `ENTITY='inbound'`.** É um movimento
   **diferente** da entrada em NA (que é `ENTITY='issue'`, lost&found).
2. **Para ligar item → IS:** filtrar `FBM_REASON_ENTITY='inbound'` e extrair `inbound_id`.
3. **Custo:** o JSON é caro. Filtrar por `FBM_CREATED_DATE` (partição) e por galpão antes
   de ler o JSON.
4. `ORIGINAL_INVENTORY_ID` continua sem serventia aqui (vazio).
