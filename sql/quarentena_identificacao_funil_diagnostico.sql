-- =============================================================================
-- FUNIL DE DIAGNÓSTICO — por que a query original retorna ~60 linhas?
-- =============================================================================
-- Este script NÃO retorna os casos; ele CONTA quantos "casos de quarentena"
-- (grão = INVENTORY_ID + ADDRESS_ID, o mesmo grão da saída final após o GROUP BY)
-- sobrevivem a cada etapa do funil. A etapa onde a contagem despenca é o gargalo.
--
-- ETAPAS 0..6 reproduzem a QUERY ORIGINAL (janela de 180 dias, > estrito, filtro
-- de origem e match >= 2). A etapa 6 deve bater com as suas ~60 linhas.
--
-- ETAPAS 7..10 são CENÁRIOS de afrouxamento — compare cada uma com a ETAPA 6
-- para ver quanto cada "botão" sozinho (e todos juntos) devolve de casos.
-- OBS.: os cenários usam a MESMA janela de 180 dias; a query afrouxada oficial
-- usa 365 dias e, portanto, tende a devolver ainda mais que a ETAPA 10.
--
-- Grão de contagem: COUNT(DISTINCT (QA_INV, QA_ADDR)). Uma quarentena com vários
-- FOUND conta como 1 (igual à saída final, que colapsa os founds via STRING_AGG).
-- =============================================================================

WITH QA AS (
    SELECT
        WAREHOUSE_ID,
        INVENTORY_ID,
        DATE(UNIT_CREATED_DTTM) AS UNIT_CREATED_DTTM
    FROM meli-bi-data.WHOWNER.DM_SHP_FBM_QUARANT
    WHERE REPORTED_PROBLEM_TYPE = 'identification'
      AND UNIT_CREATED_DTTM    >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 180 DAY)
),

NA AS (
    SELECT WAREHOUSE_ID, INVENTORY_ID, ADDRESS_ID
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_ADDRESS
    WHERE WAREHOUSE_ID   = 'BRSP04'
      AND ADDRESS_ID     LIKE 'NA%'
      AND FBM_AVAILABLE >= 0
      AND FBM_RESERVED  >= 0
),

QA_NA AS (
    SELECT QA.INVENTORY_ID, NA.ADDRESS_ID, QA.UNIT_CREATED_DTTM
    FROM NA
    JOIN QA
        ON  QA.INVENTORY_ID = NA.INVENTORY_ID
        AND QA.WAREHOUSE_ID = NA.WAREHOUSE_ID
),

ORIGEM AS (
    SELECT INVENTORY_ID, ADDRESS_TO, ADDRESS_FROM
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE WAREHOUSE_ID     = 'BRSP04'
      AND ADDRESS_TO       LIKE 'NA%'
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 180 DAY)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY INVENTORY_ID, ADDRESS_TO
        ORDER BY FBM_CREATED_DATE DESC
    ) = 1
),

FOUND AS (
    SELECT INVENTORY_ID, ADDRESS_TO, DATE(FBM_CREATED_DATE) AS DATA_FOUND
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE WAREHOUSE_ID     = 'BRSP04'
      AND ADDRESS_FROM     IS NULL
      AND ADDRESS_TO       LIKE 'NA%'
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 180 DAY)
),

INV AS (
    SELECT INVENTORY_ID, DESCRIPTION
    FROM meli-bi-data.WHOWNER.BT_SHP_FBM_INVENTORY
    WHERE SITE_ID = 'MLB'
),

-- Todos os pares QA_NA x FOUND no mesmo endereço, já com origem e descrições.
BASE AS (
    SELECT
        QA_NA.INVENTORY_ID    AS QA_INV,
        QA_NA.ADDRESS_ID      AS QA_ADDR,
        QA_NA.UNIT_CREATED_DTTM,
        FOUND.INVENTORY_ID    AS FOUND_INV,
        FOUND.DATA_FOUND,
        ORIGEM.ADDRESS_FROM   AS ORIGEM_FROM,
        INV_QA.DESCRIPTION    AS DESC_QA,
        INV_FOUND.DESCRIPTION AS DESC_FOUND
    FROM QA_NA
    JOIN FOUND
        ON QA_NA.ADDRESS_ID = FOUND.ADDRESS_TO
    LEFT JOIN ORIGEM
        ON  ORIGEM.INVENTORY_ID = QA_NA.INVENTORY_ID
        AND ORIGEM.ADDRESS_TO   = QA_NA.ADDRESS_ID
    LEFT JOIN INV AS INV_QA
        ON INV_QA.INVENTORY_ID = QA_NA.INVENTORY_ID
    LEFT JOIN INV AS INV_FOUND
        ON INV_FOUND.INVENTORY_ID = FOUND.INVENTORY_ID
),

FUNIL AS (

    -- ---- ETAPAS 0..6: reproduzem a query ORIGINAL (o "porquê das ~60") ----

    -- Universo (grão = item; referência, não é o grão dos passos seguintes).
    SELECT 0 AS ORD, '0 | QA em quarentena identification (180d)' AS ETAPA,
           (SELECT COUNT(DISTINCT INVENTORY_ID) FROM QA) AS CASOS

    UNION ALL
    SELECT 1, '1 | + parado em endereço NA (JOIN NA)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(INVENTORY_ID, ADDRESS_ID))) FROM QA_NA)

    UNION ALL
    SELECT 2, '2 | + existe FOUND no mesmo endereço NA (JOIN FOUND)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR))) FROM BASE)

    UNION ALL
    SELECT 3, '3 | + FOUND é inventory diferente',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE WHERE FOUND_INV <> QA_INV)

    UNION ALL
    SELECT 4, '4 | + achado DEPOIS da quarentena (> estrito, original)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE WHERE FOUND_INV <> QA_INV AND DATA_FOUND > UNIT_CREATED_DTTM)

    UNION ALL
    SELECT 5, '5 | + origem inbound (ADDRESS_FROM NULL/vazio)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE
            WHERE FOUND_INV <> QA_INV
              AND DATA_FOUND > UNIT_CREATED_DTTM
              AND (ORIGEM_FROM IS NULL OR ORIGEM_FROM = ''))

    UNION ALL
    SELECT 6, '6 | + match descrição >= 2  ===> FINAL ORIGINAL (~60)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE
            WHERE FOUND_INV <> QA_INV
              AND DATA_FOUND > UNIT_CREATED_DTTM
              AND (ORIGEM_FROM IS NULL OR ORIGEM_FROM = '')
              AND ( SELECT COUNT(DISTINCT p)
                    FROM UNNEST(SPLIT(LOWER(DESC_QA), ' ')) AS p
                    JOIN UNNEST(SPLIT(LOWER(DESC_FOUND), ' ')) AS q ON p = q
                    WHERE LENGTH(p) >= 3 ) >= 2)

    -- ---- ETAPAS 7..10: CENÁRIOS de afrouxamento (compare com a ETAPA 6) ----

    UNION ALL  -- só o match: >= 1 + normalizado (resto = original)
    SELECT 7, '7 | cenário: match >= 1 normalizado (resto igual ao original)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE
            WHERE FOUND_INV <> QA_INV
              AND DATA_FOUND > UNIT_CREATED_DTTM
              AND (ORIGEM_FROM IS NULL OR ORIGEM_FROM = '')
              AND ( SELECT COUNT(DISTINCT p)
                    FROM UNNEST(SPLIT(REGEXP_REPLACE(LOWER(REGEXP_REPLACE(NORMALIZE(COALESCE(DESC_QA,''),   NFD), r'\pM','')), r'[^a-z0-9]+',' '),' ')) AS p
                    JOIN UNNEST(SPLIT(REGEXP_REPLACE(LOWER(REGEXP_REPLACE(NORMALIZE(COALESCE(DESC_FOUND,''), NFD), r'\pM','')), r'[^a-z0-9]+',' '),' ')) AS q ON p = q
                    WHERE LENGTH(p) >= 3 ) >= 1)

    UNION ALL  -- só remover o filtro de origem (mantém match >= 2)
    SELECT 8, '8 | cenário: SEM filtro de origem (match >= 2)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE
            WHERE FOUND_INV <> QA_INV
              AND DATA_FOUND > UNIT_CREATED_DTTM
              AND ( SELECT COUNT(DISTINCT p)
                    FROM UNNEST(SPLIT(LOWER(DESC_QA), ' ')) AS p
                    JOIN UNNEST(SPLIT(LOWER(DESC_FOUND), ' ')) AS q ON p = q
                    WHERE LENGTH(p) >= 3 ) >= 2)

    UNION ALL  -- só trocar > por >= na data (mantém resto do original)
    SELECT 9, '9 | cenário: DATA_FOUND >= (inclui mesmo dia)',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE
            WHERE FOUND_INV <> QA_INV
              AND DATA_FOUND >= UNIT_CREATED_DTTM
              AND (ORIGEM_FROM IS NULL OR ORIGEM_FROM = '')
              AND ( SELECT COUNT(DISTINCT p)
                    FROM UNNEST(SPLIT(LOWER(DESC_QA), ' ')) AS p
                    JOIN UNNEST(SPLIT(LOWER(DESC_FOUND), ' ')) AS q ON p = q
                    WHERE LENGTH(p) >= 3 ) >= 2)

    UNION ALL  -- TODOS juntos (ainda 180d; a query .sql usa 365d e devolve mais)
    SELECT 10, '10 | cenário: TODOS juntos (match>=1 norm + sem origem + data >=) [180d]',
           (SELECT COUNT(DISTINCT FORMAT('%T', STRUCT(QA_INV, QA_ADDR)))
            FROM BASE
            WHERE FOUND_INV <> QA_INV
              AND DATA_FOUND >= UNIT_CREATED_DTTM
              AND ( SELECT COUNT(DISTINCT p)
                    FROM UNNEST(SPLIT(REGEXP_REPLACE(LOWER(REGEXP_REPLACE(NORMALIZE(COALESCE(DESC_QA,''),   NFD), r'\pM','')), r'[^a-z0-9]+',' '),' ')) AS p
                    JOIN UNNEST(SPLIT(REGEXP_REPLACE(LOWER(REGEXP_REPLACE(NORMALIZE(COALESCE(DESC_FOUND,''), NFD), r'\pM','')), r'[^a-z0-9]+',' '),' ')) AS q ON p = q
                    WHERE LENGTH(p) >= 3 ) >= 1)
)

SELECT
    ORD,
    ETAPA,
    CASOS,
    ROUND(100 * SAFE_DIVIDE(CASOS, FIRST_VALUE(CASOS) OVER (ORDER BY ORD)), 1) AS PCT_DO_UNIVERSO
FROM FUNIL
ORDER BY ORD;
