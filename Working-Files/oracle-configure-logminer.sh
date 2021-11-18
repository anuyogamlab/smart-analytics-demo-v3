#!/bin/bash
echo "Configure Log Miner"
sudo su - oracle <<EOF
ps -ef|grep pmon
. ./.bash_profile
lsnrctl status
sqlplus / as sysdba <<EOFQ
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
--ALTER DATABASE;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
--CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 4 DAYS;
EOFQ
EOF