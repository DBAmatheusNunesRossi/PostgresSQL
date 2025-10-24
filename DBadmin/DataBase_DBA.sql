--just dbadmin

CREATE DATABASE dbadmin;

--em all dbnames negociais

CREATE EXTENSION pg_freespacemap;


CREATE EXTENSION pg_repack;

--contexto do banco de dados dbadmin

CREATE extension pg_stat_statements;


CREATE extension dblink;

--convert to_seconds

CREATE OR REPLACE FUNCTION to_seconds(t text) RETURNS integer AS $BODY$
DECLARE
    hs INTEGER;
    ms INTEGER;
    s INTEGER;
BEGIN
    SELECT (EXTRACT( HOUR FROM  t::time) * 60*60) INTO hs;
    SELECT (EXTRACT (MINUTES FROM t::time) * 60) INTO ms;
    SELECT (EXTRACT (SECONDS from t::time)) INTO s;
    SELECT (hs + ms + s) INTO s;
    RETURN s;
END;
$BODY$ LANGUAGE 'plpgsql';

/*
--migration new format

create table public.tb_get_activity_new (
dt_log timestamp,
state varchar(200),
usr varchar(200),
db varchar(200),
ip varchar(100),
query text ,
query_start timestamp,
time_seconds int,
pid int);


insert into tb_get_activity_new

select
dt_log,
state,
usr,
db,
ip,
query,
query_start,
to_seconds(time_running::text)::int as time_seconds,
pid
from tb_get_activity


ALTER TABLE tb_get_activity RENAME TO tb_get_activity_old;
ALTER TABLE tb_get_activity_new RENAME TO tb_get_activity;

drop table tb_get_activity_old;

*/
CREATE TABLE public.tb_get_activity (dt_log timestamp, state varchar(200),
                                                             usr varchar(200),
                                                                 db varchar(200),
                                                                    ip varchar(100),
                                                                       query text , query_start timestamp, time_seconds int, pid int);


CREATE TABLE public.tb_get_activity_pid (dt_log timestamp, total_pid int, total_pid_by_db int, ip varchar(100),
                                                                                                  usr varchar(200),
                                                                                                      db varchar(200));


CREATE TABLE public.tb_db_size (dt_log timestamp, db varchar(200),
                                                     db_size_mb int);


CREATE TABLE public.tb_top_cpu (dt_log timestamp, db varchar(200),
                                                     total_time numeric, calls bigint , mean numeric, percentage_cpu numeric, short_query text);


CREATE TABLE tb_tables_size (dt_log timestamp, db varchar(200),
                                                  sche varchar(200),
                                                       tb varchar(300),
                                                          SIZE bigint, size_pretty varchar(300),
                                                                                   ROWS int);

/* --OU
 create table tb_tables_size
(dt_log timestamp,
 db varchar(200),
 sche varchar(200),
 tb varchar(300),
 size bigint,
 size_pretty varchar(300),
 rows int,
 bloat_mb int);
 */
CREATE TABLE tb_get_locks (dt_log timestamp, blocked_pid int, blocked_user text, blocking_pid int, blocking_user text, blocked_statement text, current_statement_in_blocking_process text);


CREATE TABLE tb_get_lag (dt_log timestamp, lag int);


CREATE VIEW vw_activity AS
SELECT DISTINCT state,
                usename AS usr,
                datname AS db,
                client_addr AS ip,
                a.query,
                a.query_start,
                age(now(), a.query_start) AS time_running,
                a.pid
FROM pg_stat_activity a
JOIN pg_locks l ON l.pid = a.pid
WHERE l.pid <> pg_backend_pid()
  AND usename NOT IN ('rdsadmin')
ORDER BY a.query_start;


CREATE VIEW vw_locks AS
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
AND blocking_locks.database IS NOT DISTINCT
FROM blocked_locks.database
AND blocking_locks.relation IS NOT DISTINCT
FROM blocked_locks.relation
AND blocking_locks.page IS NOT DISTINCT
FROM blocked_locks.page
AND blocking_locks.tuple IS NOT DISTINCT
FROM blocked_locks.tuple
AND blocking_locks.virtualxid IS NOT DISTINCT
FROM blocked_locks.virtualxid
AND blocking_locks.transactionid IS NOT DISTINCT
FROM blocked_locks.transactionid
AND blocking_locks.classid IS NOT DISTINCT
FROM blocked_locks.classid
AND blocking_locks.objid IS NOT DISTINCT
FROM blocked_locks.objid
AND blocking_locks.objsubid IS NOT DISTINCT
FROM blocked_locks.objsubid
AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;


CREATE VIEW vw_cpu AS
SELECT datname,
       round(total_exec_time::numeric, 2) AS total_time,
       calls,
       round(mean_exec_time::numeric, 2) AS mean,
       round((100 * total_exec_time / sum(total_exec_time::numeric) OVER ())::numeric, 2) AS percentage_cpu,
       substring(query, 1, 2500) AS short_query
FROM pg_stat_statements t1
JOIN pg_database t2 ON t1.dbid = t2.oid
ORDER BY total_exec_time DESC
LIMIT 20;

--COLLECT READ REPLICA

CREATE USER usr_manutencao WITH password 'U3r!M_nUT3nCa0!';

GRANT usr_forte TO usr_manutencao;


CREATE EXTENSION postgres_fdw;


CREATE SERVER NOME_SERVER_LEITURA
FOREIGN DATA WRAPPER postgres_fdw OPTIONS (dbname 'dbadmin',
                                                  HOST 'ENDPOINT_LEITURA',
                                                       port '5432');


CREATE USER MAPPING
FOR CURRENT_USER SERVER NOME_SERVER_LEITURA OPTIONS (USER 'usr_manutencao',
                                                          password 'U3r!M_nUT3nCa0!');


CREATE
FOREIGN TABLE public.pg_stat_activity_read (state varchar(200),
                                                  usename varchar(200),
                                                          datname varchar(200),
                                                                  client_addr varchar(100),
                                                                              query text , query_start timestamp, pid int) SERVER shared_read OPTIONS (SCHEMA_NAME 'pg_catalog',
                                                                                                                                                                   TABLE_NAME 'pg_stat_activity',
                                                                                                                                                                              fetch_size '100000000');


CREATE TABLE public.tb_get_activity_read (dt_log timestamp, state varchar(200),
                                                                  usr varchar(200),
                                                                      db varchar(200),
                                                                         ip varchar(100),
                                                                            query text , query_start timestamp, time_seconds int, pid int);


CREATE TABLE public.tb_get_activity_pid_read (dt_log timestamp, total_pid int, total_pid_by_db int, ip varchar(100),
                                                                                                       usr varchar(200),
                                                                                                           db varchar(200));
