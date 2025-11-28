/************************************************************************************************************************
O que esse script faz? 
1) Esse é um script avançado de auditoria, que classifica índices do PostgreSQL com base em:
2) Uso real do índice
3) Quantidade de escrituras da tabela
4) Tamanho do índice
5) Efetividade das leituras
6) Tipo do índice (BTREE / não-BTREE)
E no final gera automaticamente um comando DROP INDEX para índices considerados inúteis.


Esse script identifica índices nunca utilizados e gera automaticamente os comandos para removê-los com segurança.

************************************************************************************************************************/

WITH
		table_scans AS (
			SELECT
				tables.relid                                           AS relid,
				tables.schemaname                                      AS schemaname,
				tables.relname                                         AS tablename,
				tables.idx_scan                                        AS table_idx_scan_count,
				tables.idx_tup_fetch                                   AS table_idx_tup_fetch,
				tables.seq_scan                                        AS table_seq_scan_count,
				tables.seq_tup_read                                    AS table_seq_tup_read,
				tables.idx_scan + tables.seq_scan                      AS table_sum_all_scans,
				tables.n_tup_ins                                       AS table_write_insert_count,
				tables.n_tup_upd                                       AS table_write_update_count,
				tables.n_tup_del                                       AS table_write_delete_count,
				tables.n_tup_ins + tables.n_tup_upd + tables.n_tup_del AS table_sum_all_writes,
				tables.n_tup_hot_upd                                   AS table_tup_hot_upd_count,
				tables.n_live_tup                                      AS table_live_tup_count,
				pg_relation_size(relid)                                AS table_bytes
			FROM
				pg_stat_user_tables AS tables
	),
		database_writes AS (
			SELECT sum(table_sum_all_writes) AS database_sum_all_writes
			FROM table_scans
	),
		indexes AS (
			SELECT
				idx_stat.relid                        AS relid,
				idx_stat.indexrelid                   AS indexrelid,
				idx_stat.schemaname                   AS schemaname,
				idx_stat.relname                      AS tablename,
				idx_stat.indexrelname                 AS indexname,
				idx_stat.idx_scan                     AS index_idx_scan_count,
				idx_stat.idx_tup_read                 AS index_idx_tup_read,
				idx_stat.idx_tup_fetch                AS index_idx_tup_fetch,
				pg_relation_size(idx_stat.indexrelid) AS index_bytes,
				indexes.indexdef ~* 'USING btree'     AS idx_is_btree
			FROM
				pg_stat_user_indexes AS idx_stat
				JOIN pg_index AS pg_index
				USING (indexrelid)
				JOIN pg_indexes AS indexes
					ON idx_stat.schemaname = indexes.schemaname
					   AND idx_stat.relname = indexes.tablename
					   AND idx_stat.indexrelname = indexes.indexname
			WHERE pg_index.indisunique = FALSE
	),
		index_ratios AS (
			SELECT
				indexes.schemaname                                                                                                                AS schemaname,
				indexes.tablename                                                                                                                 AS tablename,
				indexes.indexname                                                                                                                 AS indexname,
				indexes.index_idx_scan_count                                                                                                      AS index_idx_scan_count,
				indexes.index_idx_tup_read                                                                                                        AS index_idx_tup_read,
				indexes.index_idx_tup_fetch                                                                                                       AS index_idx_tup_fetch,
				round(CASE WHEN indexes.index_idx_scan_count = 0 OR table_scans.table_live_tup_count = 0
					THEN -1 :: NUMERIC
					  ELSE indexes.index_idx_tup_fetch :: NUMERIC / indexes.index_idx_scan_count / table_scans.table_live_tup_count * 100 END, 2) AS idx_pct_table_fetched,
				table_scans.table_idx_scan_count                                                                                                  AS table_idx_scan_count,
				table_scans.table_seq_scan_count                                                                                                  AS table_seq_scan_count,
				table_scans.table_seq_tup_read                                                                                                    AS table_seq_tup_read,
				table_scans.table_sum_all_scans                                                                                                   AS table_sum_all_scans,
				round((CASE WHEN table_scans.table_sum_all_scans = 0
					THEN -1 :: NUMERIC
					   ELSE indexes.index_idx_scan_count :: NUMERIC / table_scans.table_sum_all_scans * 100 END), 2)                              AS index_scan_pct,
				table_scans.table_write_insert_count                                                                                              AS table_write_insert_count,
				table_scans.table_write_update_count                                                                                              AS table_write_update_count,
				table_scans.table_write_delete_count                                                                                              AS table_write_delete_count,
				table_scans.table_sum_all_writes                                                                                                  AS table_sum_all_writes,
				round((CASE WHEN table_scans.table_sum_all_writes = 0
					THEN indexes.index_idx_scan_count :: NUMERIC
					   ELSE indexes.index_idx_scan_count :: NUMERIC / table_scans.table_sum_all_writes END), 2)                                   AS scans_per_write,
				table_scans.table_tup_hot_upd_count                                                                                               AS table_tup_hot_upd_count,
				table_scans.table_live_tup_count                                                                                                  AS table_live_tup_count,
				indexes.index_bytes                                                                                                               AS index_bytes,
				pg_size_pretty(indexes.index_bytes)                                                                                               AS index_size,
				table_scans.table_bytes                                                                                                           AS table_bytes,
				pg_size_pretty(table_scans.table_bytes)                                                                                           AS table_size,
				indexes.idx_is_btree                                                                                                              AS idx_is_btree
			FROM
				indexes
				JOIN table_scans
				USING (relid)
	),
		index_groups AS (
		SELECT
			1                    AS grp,
			'Never Used Indexes' AS reason,
			*
		FROM index_ratios
		WHERE
			index_ratios.index_idx_scan_count = 0
			AND index_ratios.idx_is_btree

		UNION ALL

		SELECT
			2                        AS grp,
			'Low Scans, High Writes' AS reason,
			*
		FROM index_ratios
		WHERE
			scans_per_write <= 1
			AND index_scan_pct < 10
			AND index_idx_scan_count > 0
			AND table_sum_all_writes > 100
			AND idx_is_btree

		UNION ALL

		SELECT
			3                           AS grp,
			'Seldom Used Large Indexes' AS reason,
			*
		FROM index_ratios
		WHERE
			index_scan_pct < 5
			AND scans_per_write > 1
			AND index_idx_scan_count > 0
			AND idx_is_btree
			AND index_bytes > 100000000

		UNION ALL

		SELECT
			4                            AS grp,
			'High-Write Large Non-Btree' AS reason,
			index_ratios.*
		FROM index_ratios, database_writes
		WHERE
			(table_sum_all_writes :: NUMERIC / COALESCE(NULLIF(database_sum_all_writes, 0), 1)) > 0.02
			AND NOT idx_is_btree
			AND index_bytes > 100000000

		UNION ALL

		SELECT
			5                     AS grp,
			'(+) Sem Efetividade' AS reason,
			index_ratios.*
		FROM index_ratios
		WHERE
			idx_is_btree
			AND index_idx_scan_count > 0
			AND idx_pct_table_fetched > 20

		UNION ALL

		SELECT
			6                                  AS grp,
			'(+) Índice Médio (100MB a 500MB)' AS reason,
			index_ratios.*
		FROM index_ratios
		WHERE
			index_bytes >= 100000000 AND index_bytes < 500000000

		UNION ALL

		SELECT
			7                                  AS grp,
			'(+) Índice Grande (500MB a 1 GB)' AS reason,
			index_ratios.*
		FROM index_ratios
		WHERE
			index_bytes >= 500000000 AND index_bytes < 1000000000

		UNION ALL

		SELECT
			8                                  AS grp,
			'(+) Índice Enorme (mais de 1 GB)' AS reason,
			index_ratios.*
		FROM index_ratios
		WHERE
			index_bytes >= 1000000000

		ORDER BY grp, index_bytes DESC
	)
SELECT
	'/* tb - ' ||schemaname || '.' ||tablename  || ' - size index ' || index_size::text ||' - '||reason || ' */' as razao,
	
	'drop index ' || schemaname || '.' || indexname|| ';' as dropindex
	
FROM index_groups
where reason ='Never Used Indexes'
order by tablename 
