-- =============================================================================
-- MELIS DUPLICADAS / "mal identificado"  (v2 — só MLB + unidades da IS)
-- =============================================================================
-- Lógica (ver sql/OBJETIVO.md):
--   1) Itens reportados como 'identification' (QA).
--   2) Endereços com >= 2 melis distintas COM SALDO, sendo >= 1 identification.
--   3) Papel de cada meli: ORIGEM (tem IS/inbound) x FANTASMA (found).
--   4) Trazer a IS de origem, as UNIDADES dentro da IS, a RUA do MZ e o VALOR.
--
-- Escopo: SOMENTE MLB (Brasil) -> STOCK/INV por site, MOVEMENT por WAREHOUSE 'BR%'.
--
-- ⚠️ CUSTO: MOV_RAW lê a MOVEMENT (JSON) com janela de 365 dias e só galpões BR.
--    Ajuste `INTERVAL 365 DAY` se precisar. Faça dry-run antes.
-- ⚠️ SUPOSIÇÃO A VALIDAR: pareamento = 2 melis com SALDO no MESMO ADDRESS_ID.
-- =============================================================================

WITH
-- 1) Itens reportados como 'identification'
QA AS (
    SELECT DISTINCT WAREHOUSE_ID, INVENTORY_ID
    FROM meli-bi-data.WHOWNER.DM_SHP_FBM_QUARANT
    WHERE REPORTED_PROBLEM_TYPE = 'identification'
),

-- 2) Saldo atual por endereço — SÓ MLB
STOCK AS (
    SELECT DISTINCT WAREHOUSE_ID, ADDRESS_ID, INVENTORY_ID
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_ADDRESS
    WHERE FBM_QUANTITY > 0
      AND SIT_SITE_ID = 'MLB'            -- 👈 só Brasil
),

-- Endereços-alvo: >= 2 melis e >= 1 identification
ADDR_ALVO AS (
    SELECT S.WAREHOUSE_ID, S.ADDRESS_ID
    FROM STOCK S
    LEFT JOIN QA
        ON QA.WAREHOUSE_ID = S.WAREHOUSE_ID AND QA.INVENTORY_ID = S.INVENTORY_ID
    GROUP BY 1, 2
    HAVING COUNT(DISTINCT S.INVENTORY_ID) >= 2
       AND COUNT(DISTINCT IF(QA.INVENTORY_ID IS NOT NULL, S.INVENTORY_ID, NULL)) >= 1
),

-- Melis desses endereços (o par)
MELIS AS (
    SELECT S.WAREHOUSE_ID, S.ADDRESS_ID, S.INVENTORY_ID
    FROM STOCK S
    JOIN ADDR_ALVO A USING (WAREHOUSE_ID, ADDRESS_ID)
),

-- Uma passada na MOVEMENT (só BR + janela): inbound(IS) e found
MOV_RAW AS (
    SELECT
        WAREHOUSE_ID,
        INVENTORY_ID,
        FBM_REASON_ENTITY,
        FBM_CREATED_DATE,
        JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.inbound_id') AS IS_ID
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE FBM_REASON_ENTITY IN ('inbound', 'issue')
      AND WAREHOUSE_ID LIKE 'BR%'                                           -- 👈 só Brasil
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 365 DAY)
),

-- Membros de cada IS (todas as melis que entraram naquele inbound)
IS_MEMBRO AS (
    SELECT DISTINCT IS_ID, INVENTORY_ID
    FROM MOV_RAW
    WHERE FBM_REASON_ENTITY = 'inbound' AND IS_ID IS NOT NULL
),

-- Total de unidades por IS (+ lista das melis, limitada)
IS_TOTAL AS (
    SELECT
        IS_ID,
        COUNT(DISTINCT INVENTORY_ID) AS QTD_UNIDADES_NA_IS,
        ARRAY_TO_STRING(
            ARRAY_AGG(DISTINCT INVENTORY_ID ORDER BY INVENTORY_ID LIMIT 50), ', '
        ) AS UNIDADES_DA_IS
    FROM IS_MEMBRO
    GROUP BY IS_ID
),

-- Atributos por meli: teve found? qual a IS própria (última inbound)?
MELI_ATTR AS (
    SELECT
        WAREHOUSE_ID,
        INVENTORY_ID,
        LOGICAL_OR(FBM_REASON_ENTITY = 'issue') AS TEVE_FOUND,
        ARRAY_AGG(
            IF(FBM_REASON_ENTITY = 'inbound' AND IS_ID IS NOT NULL, IS_ID, NULL)
            IGNORE NULLS ORDER BY FBM_CREATED_DATE DESC LIMIT 1
        )[SAFE_OFFSET(0)] AS IS_PROPRIA
    FROM MOV_RAW
    GROUP BY 1, 2
),

-- A IS "do endereço" = a IS da meli de ORIGEM naquele endereço
IS_ENDERECO AS (
    SELECT M.WAREHOUSE_ID, M.ADDRESS_ID, MAX(A.IS_PROPRIA) AS IS_DO_ENDERECO
    FROM MELIS M
    JOIN MELI_ATTR A USING (WAREHOUSE_ID, INVENTORY_ID)
    WHERE A.IS_PROPRIA IS NOT NULL
    GROUP BY 1, 2
),

-- Cadastro (valor) — SÓ MLB, dedup por inventory
INV AS (
    SELECT INVENTORY_ID, DESCRIPTION, REFERENCE_COST
    FROM meli-bi-data.WHOWNER.BT_SHP_FBM_INVENTORY
    WHERE SITE_ID = 'MLB'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY INVENTORY_ID ORDER BY AUD_UPD_DTTM DESC) = 1
)

SELECT
    M.WAREHOUSE_ID,
    M.ADDRESS_ID,
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(0)] AS AREA,
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(1)] AS ANDAR,
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(2)] AS RUA,      -- 👈 rua do MZ
    SPLIT(M.ADDRESS_ID, '-')[SAFE_OFFSET(3)] AS PREDIO,
    M.INVENTORY_ID AS MELI,
    IF(QA.INVENTORY_ID IS NOT NULL, 'SIM', 'NÃO') AS REPORTADA_IDENTIFICATION,
    CASE
        WHEN A.IS_PROPRIA IS NOT NULL THEN 'ORIGEM (tem IS)'
        WHEN A.TEVE_FOUND             THEN 'FANTASMA (found)'
        ELSE 'INDEFINIDO'
    END AS PAPEL,
    A.IS_PROPRIA,                                         -- IS própria da meli (null = fantasma)
    IE.IS_DO_ENDERECO,                                    -- IS de origem daquele endereço
    IF(MB.INVENTORY_ID IS NOT NULL, 'SIM', 'NÃO') AS MELI_PERTENCE_A_IS,  -- fantasma = NÃO
    IT.QTD_UNIDADES_NA_IS,                                -- 👈 qtd de unidades dentro da IS
    IT.UNIDADES_DA_IS,                                    -- 👈 as unidades dentro da IS (até 50)
    INV.DESCRIPTION,
    INV.REFERENCE_COST AS VALOR
FROM MELIS M
LEFT JOIN QA
    ON QA.WAREHOUSE_ID = M.WAREHOUSE_ID AND QA.INVENTORY_ID = M.INVENTORY_ID
LEFT JOIN MELI_ATTR A
    ON A.WAREHOUSE_ID = M.WAREHOUSE_ID AND A.INVENTORY_ID = M.INVENTORY_ID
LEFT JOIN IS_ENDERECO IE
    ON IE.WAREHOUSE_ID = M.WAREHOUSE_ID AND IE.ADDRESS_ID = M.ADDRESS_ID
LEFT JOIN IS_TOTAL IT
    ON IT.IS_ID = IE.IS_DO_ENDERECO
LEFT JOIN IS_MEMBRO MB
    ON MB.IS_ID = IE.IS_DO_ENDERECO AND MB.INVENTORY_ID = M.INVENTORY_ID
LEFT JOIN INV
    ON INV.INVENTORY_ID = M.INVENTORY_ID
ORDER BY M.WAREHOUSE_ID, M.ADDRESS_ID, PAPEL;

-- =============================================================================
-- VALIDAÇÃO com a IS de exemplo (70057322) — as unidades dentro dela:
--   SELECT DISTINCT INVENTORY_ID
--   FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
--   WHERE FBM_REASON_ENTITY = 'inbound'
--     AND JSON_VALUE(FBM_REASON_EXTERNAL_REFERENCES, '$.inbound_id') = '70057322';
-- =============================================================================
