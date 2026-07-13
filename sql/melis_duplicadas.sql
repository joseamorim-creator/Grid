-- =============================================================================
-- MELIS DUPLICADAS / "mal identificado"  (v1 — validar com IS 70057322)
-- =============================================================================
-- Lógica (ver sql/OBJETIVO.md):
--   1) Pegar itens reportados como 'identification' (QA).
--   2) Achar endereços com >= 2 melis distintas COM SALDO, sendo >= 1 identification.
--      (o erro faz "subir saldo das 2 melis no mesmo endereço")
--   3) Para cada meli do par, classificar o PAPEL:
--        - ORIGEM   = tem movimento de inbound (inbound_id / IS) -> a que veio de verdade
--        - FANTASMA  = só tem movimento de found (lost&found)     -> a que não deveria existir
--   4) Trazer a IS de origem, a RUA do MZ e o VALOR (REFERENCE_COST).
--
-- ⚠️ CUSTO: escopo é TODOS os galpões. A MOVEMENT (JSON) é a cara — está com
--    janela de 365 dias na CTE MOV. Ajuste `INTERVAL 365 DAY` se precisar de mais
--    histórico (mais caro) ou menos (mais barato). Faça um dry-run antes.
--
-- ⚠️ SUPOSIÇÃO A VALIDAR: o pareamento assume que as 2 melis têm SALDO no MESMO
--    ADDRESS_ID (tabela ADDRESS). Se na prática a fantasma fica num NA e a origem
--    num MZ (endereços diferentes), a gente troca o pareamento por histórico de
--    movimento. Valide com a IS de exemplo (ver rodapé).
-- =============================================================================

WITH
-- 1) Itens reportados como 'identification' (dedup por galpão+meli)
QA AS (
    SELECT DISTINCT WAREHOUSE_ID, INVENTORY_ID
    FROM meli-bi-data.WHOWNER.DM_SHP_FBM_QUARANT
    WHERE REPORTED_PROBLEM_TYPE = 'identification'
),

-- 2) Saldo atual por endereço (melis "com saldo no CAD")
STOCK AS (
    SELECT DISTINCT WAREHOUSE_ID, ADDRESS_ID, INVENTORY_ID
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_ADDRESS
    WHERE FBM_QUANTITY > 0            -- tem saldo
),

-- Endereços-alvo: >= 2 melis distintas e >= 1 reportada como identification
ADDR_ALVO AS (
    SELECT S.WAREHOUSE_ID, S.ADDRESS_ID
    FROM STOCK S
    LEFT JOIN QA
        ON QA.WAREHOUSE_ID = S.WAREHOUSE_ID
       AND QA.INVENTORY_ID = S.INVENTORY_ID
    GROUP BY 1, 2
    HAVING COUNT(DISTINCT S.INVENTORY_ID) >= 2
       AND COUNT(DISTINCT IF(QA.INVENTORY_ID IS NOT NULL, S.INVENTORY_ID, NULL)) >= 1
),

-- Todas as melis desses endereços (o par completo)
MELIS AS (
    SELECT S.WAREHOUSE_ID, S.ADDRESS_ID, S.INVENTORY_ID
    FROM STOCK S
    JOIN ADDR_ALVO A USING (WAREHOUSE_ID, ADDRESS_ID)
),

-- 3) Uma passada na MOVEMENT: por meli, pega o found (fantasma) e a última IS (origem)
MOV AS (
    SELECT
        WAREHOUSE_ID,
        INVENTORY_ID,
        LOGICAL_OR(FBM_REASON_ENTITY = 'issue') AS TEVE_FOUND,
        ARRAY_AGG(
            IF(FBM_REASON_ENTITY = 'inbound',
               JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.inbound_id'),
               NULL)
            IGNORE NULLS ORDER BY FBM_CREATED_DATE DESC LIMIT 1
        )[SAFE_OFFSET(0)] AS IS_ID
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE FBM_REASON_ENTITY IN ('inbound', 'issue')
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 365 DAY)   -- 👈 janela/custo
    GROUP BY 1, 2
),

-- 4) Cadastro (valor) — dedup por inventory
INV AS (
    SELECT INVENTORY_ID, DESCRIPTION, REFERENCE_COST
    FROM meli-bi-data.WHOWNER.BT_SHP_FBM_INVENTORY
    QUALIFY ROW_NUMBER() OVER (PARTITION BY INVENTORY_ID ORDER BY AUD_UPD_DTTM DESC) = 1
)

SELECT
    M.WAREHOUSE_ID,
    M.ADDRESS_ID,
    -- anatomia do endereço: AREA-ANDAR-RUA-PREDIO-NIVEL-SUBNIVEL
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(0)] AS AREA,
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(1)] AS ANDAR,
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(2)] AS RUA,      -- 👈 rua do MZ
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(3)] AS PREDIO,
    M.INVENTORY_ID AS MELI,
    IF(QA.INVENTORY_ID IS NOT NULL, 'SIM', 'NÃO') AS REPORTADA_IDENTIFICATION,
    CASE
        WHEN MOV.IS_ID IS NOT NULL      THEN 'ORIGEM (tem IS)'
        WHEN MOV.TEVE_FOUND             THEN 'FANTASMA (found)'
        ELSE 'INDEFINIDO'
    END AS PAPEL,
    MOV.IS_ID,                                   -- IS de origem (inbound_id)
    MOV.TEVE_FOUND,
    INV.DESCRIPTION,
    INV.REFERENCE_COST AS VALOR
FROM MELIS M
LEFT JOIN QA
    ON QA.WAREHOUSE_ID = M.WAREHOUSE_ID AND QA.INVENTORY_ID = M.INVENTORY_ID
LEFT JOIN MOV
    ON MOV.WAREHOUSE_ID = M.WAREHOUSE_ID AND MOV.INVENTORY_ID = M.INVENTORY_ID
LEFT JOIN INV
    ON INV.INVENTORY_ID = M.INVENTORY_ID
ORDER BY M.WAREHOUSE_ID, M.ADDRESS_ID, PAPEL;

-- =============================================================================
-- VALIDAÇÃO com a IS de exemplo (70057322)
-- Rode isto separado pra ver onde a meli daquela IS está e quem é o par dela:
--
--   SELECT WAREHOUSE_ID, INVENTORY_ID,
--          JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.inbound_id') AS IS_ID,
--          ADDRESS_FROM, ADDRESS_TO, FBM_REASON_ENTITY, FBM_REASON_PROCESS,
--          FBM_CREATED_DATE
--   FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
--   WHERE JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.inbound_id') = '70057322'
--   ORDER BY FBM_CREATED_DATE;
--
-- Pegue o INVENTORY_ID e o ADDRESS retornados e confira se aparecem no resultado
-- principal, e se a "outra meli" do mesmo endereço é a fantasma (found).
-- =============================================================================
