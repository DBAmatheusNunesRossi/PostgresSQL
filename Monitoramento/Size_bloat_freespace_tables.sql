-- Lista todas as tabelas físicas do banco atual.
SELECT current_database() as db,
       relnamespace::regnamespace as sche,
       relname as tb,
       pg_total_relation_size(C.oid) size,
       pg_size_pretty (pg_total_relation_size(C.oid)) as size_pretty,
       reltuples as rows
FROM pg_class C
WHERE relkind = 'r'
  AND relnamespace NOT IN ('information_schema'::regnamespace,
                           'pg_catalog'::regnamespace)
ORDER BY size DESC;

/*************************************************************************************/

-- Criação da extensão
CREATE EXTENSION pg_freespacemap;


-- Usa a função pg_freespace(oid) para estimar quanto espaço livre (não utilizado) existe dentro das páginas de cada tabela
SELECT
current_database() db,
relnamespace::regnamespace sche,
 relname tb,  
 pg_total_relation_size(C.oid) size,
 pg_size_pretty (pg_total_relation_size(C.oid)) size_pretty,
reltuples rows, 
bloat_mb
FROM pg_class C,
LATERAL (
SELECT
(sum(avail)/1024/1024)  as bloat_mb
 FROM pg_freespace(oid)
) AS space
WHERE relkind = 'r' AND relnamespace NOT IN ('information_schema'::regnamespace, 'pg_catalog'::regnamespace)
and bloat_mb is not null
ORDER BY bloat_mb desc;
