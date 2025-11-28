/**************************************************************************
- Identificar índices duplicados no PostgreSQL que NUNCA foram usados 

(índices com scans = 0, reads = 0 e fetch = 0)

E filtrar para retornar apenas os que não são PK.
**************************************************************************/

WITH cte AS
  (SELECT tablename,
          substring(indexdef, position('btree' IN indexdef)+6, length(indexdef)) AS colunas_index,
          count(substring(indexdef, position('btree' IN indexdef)+6, length(indexdef))) AS qtd
   FROM pg_indexes
   WHERE schemaname = 'public'
   GROUP BY tablename,
            substring(indexdef, position('btree' IN indexdef)+6, length(indexdef))
   HAVING count(substring(indexdef, position('btree' IN indexdef)+6, length(indexdef))) > 1)
SELECT *
FROM pg_stat_user_indexes
WHERE indexrelname IN
    (--INDICES DUPLICADOS
SELECT indexname --*

     FROM cte t1
     JOIN pg_indexes t2 ON t1.tablename = t2.tablename
     AND colunas_index = substring(t2.indexdef, position('btree' IN t2.indexdef)+6, length(t2.indexdef)))
  AND idx_scan = 0
  AND idx_tup_read = 0
  AND idx_tup_fetch = 0
  AND indexrelname not like '%pk%'


/********************************************************************
- lista somente os índices duplicados encontrados na CTE
- verifica se nunca foram usados (tudo igual a 0)
- remove PKs (que normalmente não podem ser apagadas)
- retorna apenas os índices realmente inúteis e redundantes
*********************************************************************/
