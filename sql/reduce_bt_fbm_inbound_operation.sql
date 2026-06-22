-- =============================================================================
-- Reducao da consulta  SELECT DISTINCT *  da tabela
--   `meli-bi-data.WHOWNER.BT_FBM_INBOUND_OPERATION`
--
-- Objetivo: gerar uma consulta que retorna APENAS as colunas com pelo menos
-- um valor nao-nulo (descartando colunas 100% null), reduzindo bytes lidos
-- e custo no BigQuery.
--
-- A tabela original tem 57 colunas. Em vez de chutar quais sao "so null" a
-- partir de uma amostra pequena, o script abaixo MEDE isso na tabela inteira.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- OPCAO 1 (RECOMENDADA): detecta as colunas nao-nulas e ja roda a consulta
-- reduzida automaticamente. Faz UMA unica varredura na tabela.
-- -----------------------------------------------------------------------------
DECLARE select_list STRING;

-- 1) Conta nao-nulos de cada coluna e monta a lista somente com as que tem dados
EXECUTE IMMEDIATE (
  SELECT FORMAT("""
    SELECT STRING_AGG('`' || name || '`', ',\n  ' ORDER BY pos)
    FROM UNNEST((
      SELECT [%s]
      FROM `meli-bi-data.WHOWNER.BT_FBM_INBOUND_OPERATION`
    ))
    WHERE n > 0
  """,
  STRING_AGG(
    FORMAT("STRUCT('%s' AS name, %d AS pos, COUNTIF(`%s` IS NOT NULL) AS n)",
           column_name, ordinal_position, column_name),
    ', '))
  FROM `meli-bi-data.WHOWNER`.INFORMATION_SCHEMA.COLUMNS
  WHERE table_name = 'BT_FBM_INBOUND_OPERATION'
) INTO select_list;

-- 2) (opcional) inspecionar a lista de colunas que sobraram:
-- SELECT select_list;

-- 3) Executa a consulta final, ja reduzida
EXECUTE IMMEDIATE FORMAT("""
  SELECT DISTINCT
    %s
  FROM `meli-bi-data.WHOWNER.BT_FBM_INBOUND_OPERATION`
""", select_list);


-- -----------------------------------------------------------------------------
-- OPCAO 2 (manual, para ferramentas/BI sem suporte a scripting)
--
-- Passo 1: gerar o diagnostico (copie o texto retornado):
--
--   SELECT STRING_AGG(
--            FORMAT('COUNTIF(`%s` IS NOT NULL) AS `%s`', column_name, column_name),
--            ',\n')
--   FROM `meli-bi-data.WHOWNER`.INFORMATION_SCHEMA.COLUMNS
--   WHERE table_name = 'BT_FBM_INBOUND_OPERATION';
--
-- Passo 2: cole o resultado abaixo e rode. Toda coluna que voltar 0 e 100% null:
--
--   SELECT
--     /* COUNTIF(...) gerados no passo 1 */
--   FROM `meli-bi-data.WHOWNER.BT_FBM_INBOUND_OPERATION`;
-- -----------------------------------------------------------------------------


-- -----------------------------------------------------------------------------
-- OPCAO 3 (pragmatica, baseada APENAS na amostra de 3 linhas) -- 43 colunas
--
-- ATENCAO: o bloco de CHECK-IN (CHK_* / CHKU_*) aparece null na amostra apenas
-- porque CHECKIN_ID = -1 (registros INBOUND_TRANSFER sem check-in). Em registros
-- com check-in real essas colunas TEM dados. Valide com a OPCAO 1 antes de
-- adotar esta versao em producao.
--
-- Colunas removidas (null na amostra): CUS_CUST_ID, INB_RCPT_TOTAL_QTY,
--   CHK_FBM_USER_ID, CHK_CREATED_DATETIME, MES_CHECKIN, CHK_UPDATED_DATETIME,
--   CHK_STATUS, CHKU_CREATED_DATETIME, CHKU_UPDATED_DATETIME, CHKU_UNITS_OK,
--   CHKU_UNITS_DAMAGED, CHKU_UNITS_TOTAL, DAMAGED_CULPABILITY,
--   USUARIO_ERROR_PUTAWAY
-- -----------------------------------------------------------------------------
-- SELECT DISTINCT
--   INBOUND_ID, INB_APPOINTMENT_DATETIME, INB_ARRIVAL_DATETIME, INB_RECEPTION_DATETIME,
--   CUS_NICKNAME, INVENTORY_ID, SIT_SITE_ID, WAREHOUSE_ID, INB_QUANTITY, INB_STATUS,
--   INB_SHIPMENT_TYPE, INB_UPDATED_DATETIME, CHECKIN_ID,
--   PUTAWAY_ID, PW_CREATED_DATETIME, PW_UPDATED_DATETIME, PW_FBM_USER_ID,
--   PW_UNITS_OK, PW_UNITS_DAMAGED, PW_UNITS_TOTAL, PW_STATUS,
--   AUDIT_ID, AU_CREATED_DATETIME, AU_UPDATED_DATETIME, AU_FBM_USER_ID,
--   AU_UNITS_OK, AU_UNITS_DAMAGED_ML, AU_UNITS_DAMAGED_SELLER, AU_UNITS_DAMAGED,
--   AU_UNITS_TOTAL, AU_STATUS, STORED_UNITS_BI, CHECKIN_PUTAWAY, AUDIT_CULPABILITY,
--   AUD_INS_DT, AUD_UPD_DT, AUDIT_AUTO_FLAG, INB_FLAG_REMOVAL, PARTIALITY_ID,
--   AUD_TRANSACTION_ID, AUD_UPD_DTTM, AUD_INS_DTTM, AUD_FROM_INTERFACE
-- FROM `meli-bi-data.WHOWNER.BT_FBM_INBOUND_OPERATION`;


-- -----------------------------------------------------------------------------
-- DICAS para reduzir custo/tempo de verdade no BigQuery:
--   1. Nunca use SELECT * -- listar so as colunas necessarias reduz bytes lidos.
--   2. Reavalie o DISTINCT -- se INBOUND_ID / AUD_TRANSACTION_ID ja for unico,
--      o DISTINCT e desperdicio de processamento.
--   3. Filtre por particao/data (ex.: WHERE AUD_UPD_DT >= '...') para cortar scan.
-- -----------------------------------------------------------------------------
