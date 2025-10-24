--permissao nivel tabela
SELECT  
    rtg.grantee AS usr,
    rtg.table_schema AS sche,
    rtg.privilege_type,
    COUNT(DISTINCT rtg.table_name) AS qtd_tabelas_permission,
    CASE 
        WHEN r.rolcanlogin THEN 'usuario'
        ELSE 'role'
    END AS tipo_usr,
    CASE 
        WHEN NOT r.rolcanlogin THEN (
            SELECT STRING_AGG(rm.rolname, ', ')
            FROM pg_auth_members am
            JOIN pg_roles rm ON rm.oid = am.member
            WHERE am.roleid = r.oid
        )
        ELSE 'N/A'
    END AS usuarios_filhos_role
FROM 
    information_schema.role_table_grants rtg
JOIN 
    pg_roles r ON r.rolname = rtg.grantee
WHERE 
    rtg.privilege_type = 'SELECT'
    AND rtg.grantee NOT ILIKE 'pg_%'
    AND rtg.table_schema NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
GROUP BY 
    rtg.grantee,
    rtg.table_schema,
    rtg.privilege_type,
    r.rolcanlogin,
    r.oid
ORDER BY 
    rtg.grantee, rtg.table_schema;




--permissao sequences
SELECT relname, relacl
FROM pg_class
WHERE relkind = 'S'
and relname = 'sequence';

--permissao sequences
select * from information_schema.role_usage_grants ; 

--ALL PERMISSIONS TO USER IN ALL SCHEMAS
SELECT DISTINCT  current_database(),
'GRANT USAGE ON SCHEMA "'||table_schema ||'" TO "'||grantee ||'";
GRANT SELECT,UPDATE,INSERT,DELETE ON ALL TABLES IN SCHEMA "'||table_schema ||'" TO "'||grantee ||'";
GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA "'||table_schema ||'" TO "'||grantee ||'";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA "'||table_schema ||'" TO "'||grantee ||'";
'
ALL_PERMISSIONS
FROM   information_schema.table_privileges 
WHERE  grantee not in ('postgres','PUBLIC')


--GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA PUBLIC TO "petz-parceiro_petz";
--GRANT SELECT ON ALL TABLES IN SCHEMA public to "";
--list procedures

SELECT
    routine_schema,
    routine_name
FROM 
    information_schema.routines
    where routine_schema  not in ('pg_catalog','information_schema')

--connect
select pgu.usename as user_name,
       (select string_agg(pgd.datname, ',' order by pgd.datname) 
        from pg_database pgd 
        where has_database_privilege(pgu.usename, pgd.datname, 'CONNECT')) as database_name
from pg_user pgu
order by pgu.usename;

--verifica ROLES member of heranca
SELECT r.rolname, 
  ARRAY(SELECT b.rolname
        FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
        WHERE m.member = r.oid) as memberof

FROM pg_catalog.pg_roles r
where rolname = 'usr_manutencao'

--permissao de server
SELECT usename AS role_name,
  CASE 
     WHEN usesuper AND usecreatedb THEN 
	   CAST('superuser, create database' AS pg_catalog.text)
     WHEN usesuper THEN 
	    CAST('superuser' AS pg_catalog.text)
     WHEN usecreatedb THEN 
	    CAST('create database' AS pg_catalog.text)
     ELSE 
	    CAST('' AS pg_catalog.text)
  END role_attributes
FROM pg_catalog.pg_user
ORDER BY role_name desc;

--rodar a partir do bd_ultracarweb2
revoke all on all TABLES in schema public,operational from  user_conversao cascade;
--rodar a partir do bd_ultracarweb
revoke all on all sequences in schema public from  user_conversao cascade;
REVOKE ALL PRIVILEGES ON DATABASE bd_ultracarweb FROM user_conversao;
REVOKE ALL PRIVILEGES ON DATABASE bd_ultracarweb2 FROM user_conversao;
DROP USER user_conversao;


CREATE USER user_conversao with password 'sMNaW7gt39wGSRxU' ;

GRANT ALL PRIVILEGES ON DATABASE bd_ultracarweb TO user_conversao;
GRANT ALL PRIVILEGES ON DATABASE bd_ultracarweb2 TO user_conversao;



--ROLES defaults
create role db_datareader;
COMMENT ON ROLE db_datareader IS 'Role leitura para as tabelas';

create role db_datawriter;
COMMENT ON ROLE db_datawriter IS 'Role escrita em todas as tabelas';


--pega os schemas banco atual
SELECT '"'||nspname || '",' FROM pg_catalog.pg_namespace
where nspname not in ('information_schema','pg_toast','pg_temp_1','pg_toast_temp_1','pg_catalog')

--leitura
GRANT SELECT ON ALL TABLES IN SCHEMA schema1, schema2 TO db_datareader;
ALTER DEFAULT PRIVILEGES IN SCHEMA schema1, schema2 GRANT SELECT ON TABLES TO db_datareader;
GRANT USAGE ON SCHEMA schema1, schema2 to db_datareader;

--escrita
GRANT UPDATE, INSERT,DELETE ON ALL TABLES IN SCHEMA schema1, schema2 TO db_datawriter;
ALTER DEFAULT PRIVILEGES IN SCHEMA schema1, schema2 GRANT UPDATE, INSERT,DELETE ON TABLES TO db_datawriter;
GRANT USAGE ON SCHEMA schema1, schema2 to db_datawriter;


--permission da role a um user especifico LEITURA
grant db_datareader to usr_nominal;

--permission da role a um user especifico ESCRITA
grant db_datawriter to usr_nominal;



---permission leitura user
GRANT USAGE ON SCHEMA public to usuario;
GRANT select,usage ON ALL sequences IN SCHEMA public TO usuario;
GRANT SELECT ON all TABLES IN SCHEMA public TO usuario;

--procurar se o user existe
SELECT usename
FROM pg_user
WHERE usename ILIKE '%nome_usuario%';










--leitura+escrita
GRANT USAGE ON SCHEMA public,"ms-payment-validation","ms_payment_validation" TO "jose.fragueiro";

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public,"ms-payment-validation","ms_payment_validation" TO "jose.fragueiro";

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public,"ms-payment-validation","ms_payment_validation" TO "jose.fragueiro";

ALTER DEFAULT PRIVILEGES IN SCHEMA public,"ms-payment-validation","ms_payment_validation"
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "jose.fragueiro";

ALTER DEFAULT PRIVILEGES IN SCHEMA public,"ms-payment-validation","ms_payment_validation"
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO "jose.fragueiro";



--novas bases
-- Acesso ao schema
GRANT USAGE ON SCHEMA public TO USUARIO;
GRANT CREATE ON SCHEMA public TO "USUARIO";


-- Acesso completo às sequences existentes
GRANT SELECT, USAGE ON ALL SEQUENCES IN SCHEMA public TO USUARIO;

-- Acesso completo às tabelas existentes
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO USUARIO;

-- Permissões para objetos futuros
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO USUARIO;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, USAGE ON SEQUENCES TO USUARIO;



CREATE USER USUARIO with password 'SENHA';

