SET ECHO OFF
SET VERIFY OFF

REM PROMPT 
REM PROMPT specify password for HR as parameter 1:
REM DEFINE pass     = &1
REM PROMPT 
REM PROMPT specify default tablespeace for HR as parameter 2:
REM DEFINE tbs      = &2
REM PROMPT 
REM PROMPT specify temporary tablespace for HR as parameter 3:
REM DEFINE ttbs     = &3
REM PROMPT 
REM PROMPT specify log path as parameter 4:
REM DEFINE log_path = &4
REM PROMPT

DEFINE spool_file = $ORACLE_HOME/demo/schema/log/hr_main.log
SPOOL &spool_file

REM =======================================================
REM cleanup section
REM =======================================================
DECLARE
vcount INTEGER :=0;
BEGIN
select count(1) into vcount from dba_users where username = 'HR';
IF vcount != 0 THEN
EXECUTE IMMEDIATE ('DROP USER hr CASCADE');
END IF;
END;
/

REM =======================================================
REM create user
REM three separate commands, so the create user command 
REM will succeed regardless of the existence of the 
REM DEMO and TEMP tablespaces 
REM =======================================================
CREATE USER hr IDENTIFIED BY MyPassword;
ALTER USER hr DEFAULT TABLESPACE users
              QUOTA UNLIMITED ON users;
ALTER USER hr TEMPORARY TABLESPACE temp;
GRANT CREATE SESSION, CREATE VIEW, ALTER SESSION, CREATE SEQUENCE TO hr;
GRANT CREATE SYNONYM, CREATE DATABASE LINK, RESOURCE , UNLIMITED TABLESPACE TO hr;

REM =======================================================
REM create hr schema objects
REM =======================================================
ALTER SESSION SET CURRENT_SCHEMA=HR;
ALTER SESSION SET NLS_LANGUAGE=American;
ALTER SESSION SET NLS_TERRITORY=America;
--
-- create tables, sequences and constraint
--
@?/demo/schema/human_resources/hr_cre
-- 
-- populate tables
--
@?/demo/schema/human_resources/hr_popul

--
-- create indexes
--
@?/demo/schema/human_resources/hr_idx
--
-- create procedural objects
--
@?/demo/schema/human_resources/hr_code
--
-- add comments to tables and columns
--
@?/demo/schema/human_resources/hr_comnt
--
-- gather schema statistics
--
@?/demo/schema/human_resources/hr_analz
spool off