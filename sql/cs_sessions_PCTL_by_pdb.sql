----------------------------------------------------------------------------------------
--
-- File name:   cs_sessions_PCTL_by_pdb.sql
--
-- Purpose:     Sessions Percentile by PDB
--
-- Author:      Carlos Sierra
--
-- Version:     2019/04/13
--
-- Usage:       Execute connected to CDB or PDB
--
--              Enter range of dates when requested.
--
-- Example:     $ sqlplus / as sysdba
--              SQL> @cs_sessions_PCTL_by_pdb.sql
--
-- Notes:       Developed and tested on 12.1.0.2.
--
---------------------------------------------------------------------------------------
--
@@cs_internal/cs_primary.sql
@@cs_internal/cs_set.sql
@@cs_internal/cs_def.sql
@@cs_internal/cs_file_prefix.sql
--
DEF cs_script_name = 'cs_sessions_PCTL_by_pdb';
DEF cs_hours_range_default = '168';
--
@@cs_internal/cs_sample_time_from_and_to.sql
@@cs_internal/cs_snap_id_from_and_to.sql
--
--ALTER SESSION SET container = CDB$ROOT;
--
SELECT '&&cs_file_prefix._&&cs_script_name.' cs_file_name FROM DUAL;
--
@@cs_internal/cs_spool_head.sql
PRO SQL> @&&cs_script_name..sql "&&cs_sample_time_from." "&&cs_sample_time_to."
@@cs_internal/cs_spool_id.sql
--
@@cs_internal/cs_spool_id_sample_time.sql
--
COL pdb_name FOR A30;
COL p95 HEA '95th PCTL';
COL p97 HEA '97th PCTL';
COL p99 HEA '99th PCTL';
COL p99 HEA '99th PCTL';
COL p999 HEA '99.9th PCTL';
COL max HEA 'MAX';
COL min_sample_time FOR A19 HEA 'SAMPLE_TIME_FROM';
COL max_sample_time FOR A19 HEA 'SAMPLE_TIME_TO';
COL max_date FOR A19;
--
BREAK ON REPORT;
COMPUTE SUM LABEL 'TOTAL' OF p95 p97 p99 p999 max ON REPORT;
--
PRO
PRO Sessions Percentiles per Machine
PRO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
WITH 
by_sample AS (
SELECT /*+ MATERIALIZE NO_MERGE */
       c.name pdb_name,
       h.sample_id,
       COUNT(*) cnt,
       MIN(h.sample_time) min_sample_time,
       MAX(h.sample_time) max_sample_time,
       ROW_NUMBER() OVER (PARTITION BY c.name ORDER BY COUNT(*) DESC, MIN(h.sample_time)) AS rn
  FROM dba_hist_active_sess_history h,
       v$containers c
 WHERE h.sample_time >= TO_TIMESTAMP('&&cs_sample_time_from.', '&&cs_datetime_full_format.') 
   AND h.sample_time < TO_TIMESTAMP('&&cs_sample_time_to.', '&&cs_datetime_full_format.')
   AND h.dbid = TO_NUMBER('&&cs_dbid.')
   AND h.instance_number = TO_NUMBER('&&cs_instance_number.')
   AND h.snap_id BETWEEN TO_NUMBER('&&cs_snap_id_from.') AND TO_NUMBER('&&cs_snap_id_to.')
   AND c.con_id = h.con_id
 GROUP BY
       c.name,
       h.sample_id
)
SELECT pdb_name,
       PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY cnt) p95,
       PERCENTILE_DISC(0.97) WITHIN GROUP (ORDER BY cnt) p97,
       PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY cnt) p99,
       PERCENTILE_DISC(0.999) WITHIN GROUP (ORDER BY cnt) p999,
       MAX(cnt) max,
       TO_CHAR(MIN(CASE rn WHEN 1 THEN min_sample_time END), 'YYYY-MM-DD"T"HH24:MI:SS') AS max_date,
       TO_CHAR(MIN(min_sample_time), 'YYYY-MM-DD"T"HH24:MI:SS') min_sample_time,
       TO_CHAR(MAX(max_sample_time), 'YYYY-MM-DD"T"HH24:MI:SS') max_sample_time
  FROM by_sample
 GROUP BY
       pdb_name
 ORDER BY
       pdb_name
/
--
CLEAR BREAK;
--
PRO
PRO SQL> @&&cs_script_name..sql "&&cs_sample_time_from." "&&cs_sample_time_to." 
--
@@cs_internal/cs_spool_tail.sql
--
--ALTER SESSION SET CONTAINER = &&cs_con_name.;
--
@@cs_internal/cs_undef.sql
@@cs_internal/cs_reset.sql
--


