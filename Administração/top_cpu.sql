/*********************************************************************************************************************************
	Esse script lista as 20 consultas SQL que mais consumiram tempo de CPU no PostgreSQL, usando a extensão pg_stat_statements
**********************************************************************************************************************************/

SELECT
  datname ,
  round(total_time::numeric, 2) AS total_time,
  calls,
  round(mean_time::numeric, 2) AS mean,
  round((100 * total_time /
  sum(total_time::numeric) OVER ())::numeric, 2) AS percentage_cpu,
  substring(query, 1, 2500) AS short_query
FROM    pg_stat_statements t1
join pg_database t2 on t1.dbid = t2.oid
ORDER BY total_time DESC
LIMIT 20;

/*******************************************************************
O objetivo é identificar:

- Queries mais pesadas

- Alto consumo de CPU

- Queries com maior tempo acumulado

- Queries executadas muitas vezes

- Possíveis gargalos de performance

- Queries candidatas para otimização (índices, rewrite etc.)

É uma consulta típica de:

✔ Tunagem de banco
✔ Análise de performance
✔ Investigações de lentidão
✔ Análise de workload
*******************************************************************/
