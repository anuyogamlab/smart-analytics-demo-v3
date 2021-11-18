# Copyright 2021 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#-------------------------------------------------------------------------------------

############### Change the Parameter values below ##########################
# Change the bucket name and file name below
# export O_SOFTWARE="gs://your bucket name/V839960*.zip"

export O_SOFTWARE=$1
#"gs://sa-demo-cdc/V839960-01.zip"

# Change the database and PDB names below
# You will also need to change any matching values in the deploy-datastream.sh 
export VERSION=12.2.0.1
export ORACLE_SID=ORADB01
export PDB_NAME=ORAPDB01
export DATA_DIR=/u01/oradata

#Set the passwords for the database below
export PASSW=WelcomeWelcome1
###################### Change parameter values above #########################

# Install the Oracle Pre_Install RPM which configures the OS, install required rpms and create the oracle user.

echo "INSTALL...Installing Oracle Pre Install RPM"
sudo yum install -y https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm

echo "INSTALL...Creating directories"
sudo mkdir -p /u01/app/oracle
sudo  mkdir -p /u01/app/oraInventory
sudo chown -R oracle:oinstall /u01/app/oracle
sudo chown -R oracle:oinstall /u01/app/oraInventory
sudo chmod -R 775 /u01/app
sudo chown oracle /u01/app
sudo mkdir -p /u01/oradata
sudo chown -R oracle:oinstall /u01/oradata

echo "INSTALL...setting environment variables"
echo "export ORACLE_BASE=/u01/app/oracle   
export ORACLE_HOME=\$ORACLE_BASE/product/$VERSION/dbhome_1
export ORACLE_HOSTNAME=`hostname`
export ORA_INVENTORY=/u01/app/oraInventory
export PATH=/usr/sbin:/usr/local/bin:\$PATH
export PATH=\$ORACLE_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export ORACLE_SID=$ORACLE_SID" >> /tmp/oraenv
sudo su -c "cat /tmp/oraenv >> /home/oracle/.bash_profile" oracle


# Create the oracle home directory

. /tmp/oraenv
sudo su -c "mkdir -p $ORACLE_HOME" oracle
sudo -u oracle ls $ORACLE_HOME

echo "INSTALL...Copying Oracle Software"
## Copy the Oracle Software 
## If using this copy method remember to grant the service account access to the bucket first. Otherwise download it from the Oracle web site here.

sudo -u oracle mkdir /tmp/osoft
sudo -u oracle gsutil cp $O_SOFTWARE /tmp/osoft

echo "INSTALL...Configuring SWAP space"
## Config swap
sudo su - <<EOF
 dd if=/dev/zero of=/swapfile bs=1024 count=255360
 mkswap /swapfile
 chmod 0600 /swapfile
# Edit /etc/fstab 
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab systemctl daemon-reload
swapon /swapfile
cat /proc/swaps
free -h
EOF


# Oracle in sudoers file
sudo su - <<EOF
echo "oracle ALL=(ALL) ALL" >> /etc/sudoers
cat /etc/sudoers
EOF

echo "INSTALL...Unzipping Oracle Software"
# Unzip the Oracle software
. /tmp/oraenv
sudo su - oracle <<EOF
cd /tmp
unzip -oq '/tmp/osoft/*.zip'
cd database
EOF


## Install the software

echo "INSTALL...Running RunInstaller utility"
. /tmp/oraenv
sudo su - oracle <<EOF
hostname
export ORACLE_HOSTNAME=`hostname`
cd /tmp/database
./runInstaller -ignorePrereq -waitforcompletion -showProgress \
    -silent \
    -responseFile /tmp/database/response/db_install.rsp \
    oracle.install.option=INSTALL_DB_SWONLY \
    ORACLE_HOSTNAME=${ORACLE_HOSTNAME} \
    UNIX_GROUP_NAME=oinstall \
    INVENTORY_LOCATION=${ORA_INVENTORY} \
    SELECTED_LANGUAGES=en,en_GB \
    ORACLE_HOME=${ORACLE_HOME} \
    ORACLE_BASE=${ORACLE_BASE} \
    oracle.install.db.InstallEdition=EE \
    oracle.install.db.OSDBA_GROUP=dba \
    oracle.install.db.OSBACKUPDBA_GROUP=dba \
    oracle.install.db.OSDGDBA_GROUP=dba \
    oracle.install.db.OSKMDBA_GROUP=dba \
    oracle.install.db.OSRACDBA_GROUP=dba \
    SECURITY_UPDATES_VIA_MYORACLESUPPORT=false \
    DECLINE_SECURITY_UPDATES=true
EOF

echo "INSTALL...Executing root.sh scripts"
. /tmp/oraenv
sudo /u01/app/oraInventory/orainstRoot.sh
sudo $ORACLE_HOME/root.sh


### Create a Database

echo "INSTALL...Starting the Listener"
sudo su - oracle <<EOF
lsnrctl start
EOF


echo "INSTALL...Creating the databaseâ€¦"
sudo su - oracle <<EOF
dbca -silent -createDatabase                                                   \
     -templateName General_Purpose.dbc                                         \
     -gdbname ${ORACLE_SID} -sid  ${ORACLE_SID} -responseFile NO_VALUE         \
     -characterSet AL32UTF8                                                    \
     -sysPassword ${PASSW}                                                     \
     -systemPassword ${PASSW}                                                  \
     -createAsContainerDatabase false                                          \
     -databaseType MULTIPURPOSE                                                \
     -automaticMemoryManagement false                                          \
     -totalMemory 4000                                                         \
     -storageType FS                                                           \
     -datafileDestination "${DATA_DIR}"                                        \
     -redoLogFileSize 50                                                       \
     -emConfiguration NONE                                                     \
     -ignorePreReqs

ps -ef|grep pmon
. ./.bash_profile
lsnrctl status
sqlplus / as sysdba <<EOFQ
show sga
show pdbs
EOFQ
EOF



echo "CONFIGURE... Datastream"
sudo su - oracle <<'EOF'
ps -ef|grep pmon
. ./.bash_profile
lsnrctl status
sqlplus / as sysdba <<'EOFQ'
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
--ALTER DATABASE;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
--CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 4 DAYS;
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
@/tmp/hr_main_custom.sql;
ALTER SYSTEM ARCHIVE LOG CURRENT;
EOFQ
EOF

echo "Database software Installation and database creation completed"
echo "Your Database name is $ORACLE_SID"
echo "Your database sys/system password is $PASSW"

echo "Your DataStream user name is datacdc"
echo "Your DataStream user password is MyPassword"