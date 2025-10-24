-- Ele gera uma lista dos esquemas “não-sistêmicos”
SELECT '"'||nspname || '",'
FROM pg_catalog.pg_namespace
WHERE nspname NOT IN ('information_schema', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1', 'pg_catalog')
  AND nspname not ilike '%pg_temp%'
  AND nspname not ilike '%pg_toast%'



-- Como fica a saída (exemplo):
"public",
"meu_esquema",
"analytics",
