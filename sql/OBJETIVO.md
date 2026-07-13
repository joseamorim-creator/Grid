# Objetivo — melis duplicadas / "mal identificado"

## 🧩 O fenômeno (erro de duplicidade de meli)
1. Um produto físico **chega em 1 IS** (inbound shipment). Ex.: `70057322`.
2. Por **erro de cadastro**, o produto fica com **2 melis** (dois `INVENTORY_ID`).
3. No **put-away**, só **1 meli é fisicamente armazenada** (a correta).
4. Um **erro na tarefa de inventário** faz **subir saldo das 2 melis** no CAD
   → **1 produto físico, 2 saldos**. A segunda é a **meli fantasma**.
5. A **fantasma** não tem lastro real na IS; sua movimentação característica na rua
   é um **`found`** (a IS dela é **inconsistente** — às vezes existe, às vezes não).
6. Um **rep de inventário** dá **LOST** na meli de origem → **perda**; a fantasma
   fica com **saldo indevido** no CAD.
7. O **vendedor reporta** o produto como **`identification`** (pode ser **qualquer
   uma** das duas melis).
8. A **Qualidade** dá **baixa RQ** na meli fantasma, tirando-a do CAD.

## 🎯 Objetivo
Para os itens reportados como **`identification`**, trazer:
- de qual **IS (inbound)** o produto veio (origem),
- de qual **rua do MZ** ele veio,
- e o **valor** do produto,

para **quantificar e rastrear** as melis fantasma e a perda associada.

**Cada linha = uma meli mal identificada**, com origem (**IS + rua do MZ**) e **valor**.

## 🔑 Regras/mecânica (confirmadas)
- **A** — a meli reportada como `identification` pode ser **a fantasma OU a de origem**
  (relativo; não assumir lado).
- **B** — **pareamento das 2 melis = mesmo `ADDRESS_ID`** (dois `INVENTORY_ID`
  distintos no mesmo endereço). 👈 chave da consulta.
- **C** — **fantasma** = tem movimentação **`found`** na rua (IS inconsistente);
  **origem** = tem **inbound real** (`inbound_id` no JSON, `FBM_REASON_ENTITY='inbound'`).
- **D** — anatomia do endereço `MZ-3-072-013-05-03`:
  | `MZ` | `3` | `072` | `013` | `05` | `03` |
  |---|---|---|---|---|---|
  | área | andar | **rua** | prédio | nível do prédio | sub-nível |
  - Em SQL: `SPLIT(ADDRESS_ID,'-')[OFFSET(2)]` = rua.
- **E** — valor = `INVENTORY.REFERENCE_COST`; escopo = **TODOS os warehouses**;
  janela de tempo = *(a definir — ver nota de custo abaixo)*.

> ⚠️ **Custo:** "todos os warehouses" + leitura do JSON da MOVEMENT tende a ficar
> caro (foi o que estourou 1,2 TB). Mitigação: aplicar **janela de data** na
> partição (`FBM_CREATED_DATE`) e só ler o JSON depois de reduzir o volume.

## 🗺️ Tabelas por papel
| Papel | Tabela / campo |
|---|---|
| Itens `identification` | `DM_SHP_FBM_QUARANT` (`REPORTED_PROBLEM_TYPE`) |
| Saldo/posição + pareamento por endereço | `BT_FBM_STOCK_3_ADDRESS` (`ADDRESS_ID`, `INVENTORY_ID`) |
| Found (fantasma) vs inbound (origem) + rua MZ | `BT_FBM_STOCK_3_MOVEMENT` (`ENTITY`, `inbound_id`, `ADDRESS_FROM`) |
| Valor / GTIN | `BT_SHP_FBM_INVENTORY` (`REFERENCE_COST`, `IDENTIFIER`) |
| Financeiro (perda paga?) | `DM_FBM_FPP_HIST` (`FRENADO_PAGO`, `FBM_ISSUE_TYPE`) |

## 🧪 Caso-teste
IS **`70057322`** — usar para validar o resultado da consulta.
