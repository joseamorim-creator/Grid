-- =============================================================================
-- Quarentena "identification" x itens achados (FOUND) em endereços NA — BRSP04
-- VERSÃO AFROUXADA (objetivo: fazer aparecer MAIS casos)
-- =============================================================================
-- O que a análise faz:
--   Correlaciona itens em quarentena por 'identification' que estão parados em
--   endereços NA (não alocados) com itens "achados" (inbound, sem ADDRESS_FROM)
--   que caíram no MESMO endereço NA depois, e que provavelmente são o mesmo
--   produto (heurística de similaridade de descrição).
--
-- O QUE MUDOU vs. a versão original (para deixar passar mais linhas):
--   (1) Janela de 180 -> 365 dias em QA, ORIGEM, POS_ORIGEM e FOUND.
--   (2) Match de descrição: limiar de >= 2 -> >= 1 palavra em comum, E com
--       NORMALIZAÇÃO (remove acentos + pontuação, casefold). Antes "cabo," e
--       "cabo", ou "lâmina" e "lamina", NÃO casavam; agora casam.
--   (3) Comparação de data: FOUND.DATA_FOUND > ... trocado por >= ...
--       (passa a incluir o achado no MESMO dia da quarentena).
--   (4) REMOVIDO o filtro (ORIGEM.ADDRESS_FROM IS NULL OR = '') que travava a
--       análise em itens de origem "inbound" e tornava inalcançáveis as
--       categorias MZ/MU/NA do próprio CASE ORIGEM_TIPO.
--
-- COMO REGULAR O QUÃO "SOLTO" FICA (botões de ajuste):
--   - Janela de tempo: troque os "INTERVAL 365 DAY".
--   - Sensibilidade do match: o ">= 1" lá no final do WHERE. Suba para >= 2
--     para menos falsos positivos; mantenha >= 1 para máxima cobertura.
--   - Para reduzir falsos positivos com >= 1, dá para adicionar uma lista de
--     stopwords no WHERE do match, ex.:
--       AND palavra_qa NOT IN ('kit','com','para','cor','preto','branco','und')
--
-- NOTA (não afeta a contagem de linhas): PAGOS entra por LEFT JOIN e só alimenta
-- o rótulo POSSUI_PAGAMENTO; a data '2026-01-01' está fixa. Se quiser o rótulo
-- coerente com a janela de análise, alinhe essa data também.
-- =============================================================================

WITH QA AS (
    SELECT
        WAREHOUSE_ID,
        INVENTORY_ID,
        REPORTED_PROBLEM_TYPE,
        DATE(UNIT_CREATED_DTTM) AS UNIT_CREATED_DTTM
    FROM meli-bi-data.WHOWNER.DM_SHP_FBM_QUARANT
    WHERE REPORTED_PROBLEM_TYPE = 'identification'
      AND UNIT_CREATED_DTTM    >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 365 DAY)   -- (1) 180 -> 365
),

NA AS (
    SELECT
        WAREHOUSE_ID,
        INVENTORY_ID,
        ADDRESS_ID,
        FBM_AVAILABLE,
        FBM_RESERVED
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_ADDRESS
    WHERE WAREHOUSE_ID   = 'BRSP04'
      AND ADDRESS_ID     LIKE 'NA%'
      AND FBM_AVAILABLE >= 0
      AND FBM_RESERVED  >= 0
),

QA_NA AS (
    SELECT
        QA.INVENTORY_ID,
        QA.REPORTED_PROBLEM_TYPE,
        NA.ADDRESS_ID,
        NA.FBM_AVAILABLE,
        NA.FBM_RESERVED,
        QA.UNIT_CREATED_DTTM
    FROM NA
    JOIN QA
        ON  QA.INVENTORY_ID = NA.INVENTORY_ID
        AND QA.WAREHOUSE_ID = NA.WAREHOUSE_ID
),

ORIGEM AS (
    SELECT
        INVENTORY_ID,
        ADDRESS_TO,
        ADDRESS_FROM,
        DATE(FBM_CREATED_DATE) AS ORIGEM_DATA
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE WAREHOUSE_ID     = 'BRSP04'
      AND ADDRESS_TO       LIKE 'NA%'
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 365 DAY)       -- (1) 180 -> 365
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY INVENTORY_ID, ADDRESS_TO
        ORDER BY FBM_CREATED_DATE DESC
    ) = 1
),

POS_ORIGEM AS (
    SELECT
        INVENTORY_ID,
        ADDRESS_FROM AS POSICAO_ORIGEM
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE WAREHOUSE_ID     = 'BRSP04'
      AND ADDRESS_FROM     IS NOT NULL
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 365 DAY)       -- (1) 180 -> 365
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY INVENTORY_ID
        ORDER BY FBM_CREATED_DATE DESC
    ) = 1
),

FOUND AS (
    SELECT
        WAREHOUSE_ID,
        FBM_REASON_PROCESS,
        INVENTORY_ID,
        FBM_QUANTITY,
        ADDRESS_TO,
        DATE(FBM_CREATED_DATE) AS DATA_FOUND
    FROM meli-bi-data.WHOWNER.BT_FBM_STOCK_3_MOVEMENT
    WHERE WAREHOUSE_ID     = 'BRSP04'
      AND ADDRESS_FROM     IS NULL
      AND ADDRESS_TO       LIKE 'NA%'
      AND FBM_CREATED_DATE >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 365 DAY)       -- (1) 180 -> 365
),

INV AS (
    SELECT
        INVENTORY_ID,
        DESCRIPTION,
        REFERENCE_COST                       -- valor do produto
    FROM meli-bi-data.WHOWNER.BT_SHP_FBM_INVENTORY
    WHERE SITE_ID = 'MLB'
),

PAGOS AS (
    SELECT DISTINCT
        INVENTORY_ID
    FROM meli-bi-data.WHOWNER.DM_FBM_FPP_HIST
    WHERE PAY_CREATED_DATETIME >= '2026-01-01'   -- NOTA: data fixa; só rotula, não filtra linhas
      AND WAREHOUSE_ID          = 'BRSP04'
)

SELECT
    QA_NA.INVENTORY_ID,
    QA_NA.REPORTED_PROBLEM_TYPE,
    QA_NA.ADDRESS_ID,
    ORIGEM.ADDRESS_FROM AS ORIGEM_POSICAO,
    CASE
        WHEN ORIGEM.ADDRESS_FROM LIKE 'NA%'                          THEN 'Quarentena / Não alocado'
        WHEN ORIGEM.ADDRESS_FROM LIKE 'MZ%'                          THEN 'Posição de estoque (MZ)'
        WHEN ORIGEM.ADDRESS_FROM LIKE 'MU%'                          THEN 'Posição de estoque (MU)'
        WHEN ORIGEM.ADDRESS_FROM IS NULL OR ORIGEM.ADDRESS_FROM = '' THEN 'Entrada / Sem origem (inbound)'
        ELSE 'Outra origem'
    END AS ORIGEM_TIPO,
    ORIGEM.ORIGEM_DATA,
    QA_NA.FBM_AVAILABLE,
    QA_NA.FBM_RESERVED,
    QA_NA.UNIT_CREATED_DTTM,
    INV_QA.DESCRIPTION    AS DESCRIPTION,
    INV_QA.REFERENCE_COST AS VALOR_PRODUTO,         -- valor do produto principal
    STRING_AGG(
        DISTINCT CONCAT(
            FOUND.INVENTORY_ID, ' - ',
            COALESCE(INV_FOUND.DESCRIPTION, ''),
            ' [valor: ',  COALESCE(CAST(INV_FOUND.REFERENCE_COST AS STRING), 's/ valor'), ']',
            ' [origem: ', COALESCE(POS_FOUND.POSICAO_ORIGEM, 'sem origem'), ']'
        ),
        '  |  '
    ) AS FOUNDS,
    CASE WHEN PAGOS.INVENTORY_ID IS NOT NULL THEN 'SIM' ELSE 'NÃO' END AS POSSUI_PAGAMENTO
FROM QA_NA
JOIN FOUND
    ON QA_NA.ADDRESS_ID = FOUND.ADDRESS_TO
LEFT JOIN ORIGEM
    ON  ORIGEM.INVENTORY_ID = QA_NA.INVENTORY_ID
    AND ORIGEM.ADDRESS_TO   = QA_NA.ADDRESS_ID
LEFT JOIN POS_ORIGEM AS POS_FOUND
    ON  POS_FOUND.INVENTORY_ID = FOUND.INVENTORY_ID
LEFT JOIN INV AS INV_QA
    ON INV_QA.INVENTORY_ID = QA_NA.INVENTORY_ID
LEFT JOIN INV AS INV_FOUND
    ON INV_FOUND.INVENTORY_ID = FOUND.INVENTORY_ID
LEFT JOIN PAGOS
    ON PAGOS.INVENTORY_ID = QA_NA.INVENTORY_ID
WHERE FOUND.DATA_FOUND    >= QA_NA.UNIT_CREATED_DTTM        -- (3) > trocado por >= (inclui mesmo dia)
  AND FOUND.INVENTORY_ID <> QA_NA.INVENTORY_ID
  -- (4) filtro (ORIGEM.ADDRESS_FROM IS NULL OR = '') REMOVIDO de propósito
  AND (
      -- (2) match normalizado (sem acento/pontuação, casefold) e limiar >= 1
      SELECT COUNT(DISTINCT palavra_qa)
      FROM UNNEST(SPLIT(
             REGEXP_REPLACE(
               LOWER(REGEXP_REPLACE(NORMALIZE(COALESCE(INV_QA.DESCRIPTION, ''), NFD), r'\pM', '')),
               r'[^a-z0-9]+', ' '
             ), ' ')) AS palavra_qa
      JOIN UNNEST(SPLIT(
             REGEXP_REPLACE(
               LOWER(REGEXP_REPLACE(NORMALIZE(COALESCE(INV_FOUND.DESCRIPTION, ''), NFD), r'\pM', '')),
               r'[^a-z0-9]+', ' '
             ), ' ')) AS palavra_found
          ON palavra_qa = palavra_found
      WHERE LENGTH(palavra_qa) >= 3
  ) >= 1                                                    -- (2) 2 -> 1
GROUP BY
    QA_NA.INVENTORY_ID,
    QA_NA.REPORTED_PROBLEM_TYPE,
    QA_NA.ADDRESS_ID,
    ORIGEM.ADDRESS_FROM,
    ORIGEM.ORIGEM_DATA,
    QA_NA.FBM_AVAILABLE,
    QA_NA.FBM_RESERVED,
    QA_NA.UNIT_CREATED_DTTM,
    INV_QA.DESCRIPTION,
    INV_QA.REFERENCE_COST,
    PAGOS.INVENTORY_ID
ORDER BY
    QA_NA.UNIT_CREATED_DTTM DESC
