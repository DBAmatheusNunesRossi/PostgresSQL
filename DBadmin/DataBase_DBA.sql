--just dbadmin
create database dbadmin;

--em all dbnames negociais
CREATE EXTENSION pg_freespacemap;
CREATE EXTENSION pg_repack;


--contexto do banco de dados dbadmin
CREATE extension pg_stat_statements;
create extension dblink;

--convert to_seconds
CREATE OR REPLACE FUNCTION to_seconds(t text)
  RETURNS integer AS
$BODY$ 
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
$BODY$
  LANGUAGE 'plpgsql';
  
  
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

create table public.tb_get_activity (
dt_log timestamp,
state varchar(200),
usr varchar(200),
db varchar(200),
ip varchar(100),
query text ,
query_start timestamp,
time_seconds int,
pid int);


create table public.tb_get_activity_pid (
dt_log timestamp,
total_pid int,
total_pid_by_db int,
ip varchar(100),
usr varchar(200),db varchar(200)
);

create table public.tb_db_size (
dt_log timestamp,
db varchar(200),
db_size_mb int );

create table public.tb_top_cpu (
dt_log timestamp,
db varchar(200),
total_time numeric,
calls bigint ,
mean numeric,
percentage_cpu numeric,
short_query text);


create table tb_tables_size
(dt_log timestamp,
 db varchar(200),
 sche varchar(200),
 tb varchar(300),
 size bigint,
 size_pretty varchar(300),
 rows int); 
 
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
 
 

 create table tb_get_locks (
        dt_log timestamp,
		blocked_pid int,
		blocked_user text,
		blocking_pid int,
		blocking_user text,
		blocked_statement text,
		current_statement_in_blocking_process text
	);
 
 
CREATE TABLE tb_get_lag (
	dt_log timestamp,
	lag int 
);

 
 
 
 create view vw_activity AS
 SELECT  distinct
	 state, 
	 usename as usr,  
     datname as db,	 
         client_addr as ip,
         a.query,
         a.query_start,
         age(now(), a.query_start) AS time_running,
         a.pid
FROM pg_stat_activity a
JOIN pg_locks l ON l.pid = a.pid
where l.pid <> pg_backend_pid() 
and  usename not in ('rdsadmin') 
ORDER BY a.query_start;


 create view vw_locks AS
select
	blocked_locks.pid as blocked_pid,
	blocked_activity.usename as blocked_user,
	blocking_locks.pid as blocking_pid,
	blocking_activity.usename as blocking_user,
	blocked_activity.query as blocked_statement,
	blocking_activity.query as current_statement_in_blocking_process
from
	pg_catalog.pg_locks blocked_locks
join pg_catalog.pg_stat_activity blocked_activity on
	blocked_activity.pid = blocked_locks.pid
join pg_catalog.pg_locks blocking_locks
        on
	blocking_locks.locktype = blocked_locks.locktype
	and blocking_locks.database is not distinct
from 	blocked_locks.database	and blocking_locks.relation is not distinct
from 	blocked_locks.relation and blocking_locks.page is not distinct
from 	blocked_locks.page 	and blocking_locks.tuple is not distinct
from 	blocked_locks.tuple 	and blocking_locks.virtualxid is not distinct
from 	blocked_locks.virtualxid 	and blocking_locks.transactionid is not distinct
from 	blocked_locks.transactionid 	and blocking_locks.classid is not distinct
from 	blocked_locks.classid 	and blocking_locks.objid is not distinct
from 	blocked_locks.objid 	and blocking_locks.objsubid is not distinct
from 	blocked_locks.objsubid 	and blocking_locks.pid != blocked_locks.pid 
join pg_catalog.pg_stat_activity blocking_activity on 	blocking_activity.pid = blocking_locks.pid
where
	not blocked_locks.granted;
	
	
create view vw_cpu as	
SELECT
  datname ,
  round(total_exec_time::numeric, 2) AS total_time,
  calls,
  round(mean_exec_time::numeric, 2) AS mean,
  round((100 * total_exec_time /
  sum(total_exec_time::numeric) OVER ())::numeric, 2) AS percentage_cpu,
  substring(query, 1, 2500) AS short_query
FROM    pg_stat_statements t1
join pg_database t2 on t1.dbid = t2.oid
ORDER BY total_exec_time DESC
LIMIT 20;	



--COLLECT READ REPLICA

create user usr_manutencao with password 'U3r!M_nUT3nCa0!';

grant usr_forte to usr_manutencao;


CREATE EXTENSION postgres_fdw;

CREATE SERVER NOME_SERVER_LEITURA
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (dbname 'dbadmin', host 'ENDPOINT_LEITURA', port '5432');

CREATE USER MAPPING FOR CURRENT_USER
    SERVER NOME_SERVER_LEITURA
    OPTIONS (user 'usr_manutencao', password 'U3r!M_nUT3nCa0!');


CREATE FOREIGN TABLE public.pg_stat_activity_read (
state varchar(200),
usename varchar(200),
datname varchar(200),
client_addr varchar(100),
query text ,
query_start timestamp,
pid int)
SERVER shared_read
OPTIONS (schema_name 'pg_catalog', table_name 'pg_stat_activity', fetch_size '100000000');




create table public.tb_get_activity_read (
dt_log timestamp,
state varchar(200),
usr varchar(200),
db varchar(200),
ip varchar(100),
query text ,
query_start timestamp,
time_seconds int,
pid int);


create table public.tb_get_activity_pid_read (
dt_log timestamp,
total_pid int,
total_pid_by_db int,
ip varchar(100),
usr varchar(200),db varchar(200)
);
