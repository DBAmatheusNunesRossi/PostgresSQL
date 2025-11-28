-- =====================================================================
-- FUNÇÃO: count_rows
-- OBJETIVO: Contar o número de linhas de qualquer tabela informada.
-- PARÂMETROS:
--   nome_schema  → schema onde a tabela está localizada (ex: public)
--   nome_tabela  → nome da tabela que deseja contar as linhas
-- =====================================================================

CREATE OR REPLACE FUNCTION count_rows(
    nome_schema TEXT,
    nome_tabela TEXT
) RETURNS INTEGER
AS
$body$
DECLARE
    result INTEGER;
BEGIN
    -- Monta dinamicamente a query e retorna o total de registros
    EXECUTE FORMAT(
        'SELECT COUNT(1) FROM %I.%I;',
        nome_schema,
        nome_tabela
    )
    INTO result;

    RETURN result;
END;
$body$
LANGUAGE plpgsql;


-- =====================================================================
-- RELATÓRIO DE QUANTIDADE DE LINHAS POR TABELA
-- ALTERAR o parâmetro:
--   'nome_do_schema'  → coloque aqui o schema da empresa (ex.: public, app, data)
-- =====================================================================

SELECT
    table_schema,
    table_name,
    count_rows(table_schema, table_name) AS total_linhas
FROM information_schema.tables
WHERE table_schema IN ('nome_do_schema')  -- <=== ALTERAR AQUI
  AND table_type = 'BASE TABLE'
ORDER BY total_linhas DESC;
