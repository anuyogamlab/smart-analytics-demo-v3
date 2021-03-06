#!/bin/bash

echo "Configure Datastream"
sudo su - oracle <<EOF
ps -ef|grep pmon
. ./.bash_profile
lsnrctl status
sqlplus / as sysdba <<EOFQ
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (all) COLUMNS;
CREATE USER datacdc IDENTIFIED BY MyPassword;
GRANT EXECUTE_CATALOG_ROLE TO datacdc;
GRANT CONNECT TO datacdc;
GRANT CREATE SESSION TO datacdc;
GRANT SELECT ON SYS.V_$DATABASE TO datacdc;
GRANT SELECT ON SYS.V_$ARCHIVED_LOG TO datacdc;
GRANT SELECT ON SYS.V_$LOGMNR_CONTENTS TO datacdc;
GRANT SELECT ON SYS.V_$LOGMNR_LOGS TO datacdc;
GRANT EXECUTE ON DBMS_LOGMNR TO datacdc;
GRANT EXECUTE ON DBMS_LOGMNR_D TO datacdc;
GRANT SELECT ANY TRANSACTION TO datacdc;
GRANT SELECT ANY TABLE TO datacdc;
GRANT LOGMINING TO datacdc;
EOFQ
EOF

