/********************************************************************************************************************************************
	Esse script lista e gera automaticamente comandos SQL para alterar o OWNER de todos os objetos de um banco PostgreSQL (tabelas, views, materialized views, sequences, functions e types), além de consultar quem é o owner atual de schemas e databases
*********************************************************************************************************************************************/

--TABELAS
SELECT 'ALTER TABLE "'|| schemaname || '"."' || tablename ||'" OWNER TO "'||current_database()||'";'
FROM pg_tables WHERE NOT schemaname IN ('pg_catalog', 'information_schema')
union
--SEQUENCES
SELECT 'ALTER SEQUENCE "'|| sequence_schema || '"."' || sequence_name ||'" OWNER TO "'||current_database()||'";'
FROM information_schema.sequences WHERE NOT sequence_schema IN ('pg_catalog', 'information_schema')
union 
--VIEWS
SELECT 'ALTER VIEW "'|| table_schema || '"."' || table_name ||'" OWNER TO "'||current_database()||'";'
FROM information_schema.views WHERE NOT table_schema IN ('pg_catalog', 'information_schema')
UNION
--VIEW MATERIALIZADA
SELECT 'ALTER TABLE "'|| oid::regclass::text ||'" OWNER TO "'||current_database()||'";'
FROM pg_class WHERE relkind = 'm';


--function
SELECT 'ALTER FUNCTION '
            || quote_ident(n.nspname) || '.' 
            || quote_ident(p.proname) || '(' 
            || pg_catalog.pg_get_function_identity_arguments(p.oid)
            || ') OWNER TO owner_usr;' AS command
FROM   pg_catalog.pg_proc p
JOIN   pg_catalog.pg_namespace n ON n.oid = p.pronamespace 
WHERE  n.nspname = 'wsm';

--alter owner TYPE

SELECT typowner::regrole as owner_actual , 
'alter type "'||typname || '" owner to "'||typowner::regrole::text|| '";' as alter_type_owner
FROM pg_type t 
WHERE typowner::regrole::text  not in ('rdsadmin')
and left(typname,1) <> '_'

--verifica o owner
SELECT * FROM (
    -- Tabelas, views, sequences e materialized views
    SELECT 
        pgr.rolname AS atual_owner,
        CASE pgc.relkind
            WHEN 'r' THEN 'ALTER TABLE "' || pgn.nspname || '"."' || pgc.relname || '" OWNER TO new_usuario;'
            WHEN 'm' THEN 'ALTER TABLE "' || pgn.nspname || '"."' || pgc.relname || '" OWNER TO new_usuario;'
            WHEN 'S' THEN 'ALTER SEQUENCE "' || pgn.nspname || '"."' || pgc.relname || '" OWNER TO new_usuario;'
            WHEN 'v' THEN 'ALTER VIEW "' || pgn.nspname || '"."' || pgc.relname || '" OWNER TO new_usuario;'
        END AS owner_to
    FROM 
        pg_class pgc
    JOIN 
        pg_roles pgr ON pgr.oid = pgc.relowner
    JOIN 
        pg_namespace pgn ON pgn.oid = pgc.relnamespace
    WHERE 
        pgn.nspname NOT IN ('pg_catalog','pg_toast','information_schema') 
        AND pgr.rolname <> 'rdsadmin'
    UNION ALL
    SELECT 
        pgr.rolname AS atual_owner,
        'ALTER TYPE "' || pgn.nspname || '"."' || pt.typname || '" OWNER TO new_usuario;' AS owner_to
    FROM 
        pg_type pt
    JOIN 
        pg_roles pgr ON pgr.oid = pt.typowner
    JOIN 
        pg_namespace pgn ON pgn.oid = pt.typnamespace
    WHERE 
        pt.typtype = 'e' -- somente ENUM
        AND pgn.nspname NOT IN ('pg_catalog','pg_toast','information_schema')
        AND pgr.rolname <> 'rdsadmin'
		and left(pt.typname,1) <> '_'
) AS t
WHERE owner_to IS NOT NULL;



--owner DBNAME
SELECT datname AS database_name,
       pg_catalog.pg_get_userbyid(datdba) AS owner
FROM pg_database
where datname = 'stg_onb_merchant_account_seller'


--owner schema
SELECT pg_catalog.pg_get_userbyid(n.nspowner) AS owner
FROM pg_catalog.pg_namespace n
WHERE n.nspname = 'public';
