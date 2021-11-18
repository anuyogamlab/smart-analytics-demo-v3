sshUser="gcpadmin"
sshFile="gcpcloud03"
oracleVM="oracle-vm-03"
oracleRegion="us-east4"
oracleZone="us-east4-c"
project="smart-analytics-demo-01"
tag="oracle-ssh-vm"
oracle_install_zip="gs://sa-demo-cdc/V839960-01.zip"

ssh-keygen -t rsa -f ~/.ssh/${sshFile} -C ${sshUser} -q -N ""
chmod 400 ~/.ssh/${sshFile}

gcloud compute instances create ${oracleVM} \
  --image-project="rhel-cloud" \
  --image-family="rhel-7" \
  --machine-type="n1-standard-4" \
  --boot-disk-size="400GB" \
  --subnet="projects/${project}/regions/${oracleRegion}/subnetworks/default" \
  --zone=${oracleZone} \
  --tags ${tag}


#  create network rule
gcloud compute firewall-rules create "${oracleVM}-firewall" \
  --description="Allow TCP SSH" \
  --direction=INGRESS \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=${tag}

gcloud compute os-login ssh-keys add --project ${project} --key-file ~/.ssh/${sshFile}.pub
# Manual ssh test:  gcloud compute ssh ${sshUser}@${oracleVM} --ssh-key-file=~/.ssh/${sshFile} --zone ${oracleZone}
gcloud compute scp --zone ${oracleZone} --ssh-key-file=~/.ssh/${sshFile} ./oracle-install.sh ${sshUser}@${oracleVM}:~/oracle-install.sh
gcloud compute ssh --zone ${oracleZone} --ssh-key-file=~/.ssh/${sshFile} ${sshUser}@${oracleVM} \
  --command "chmod +x ~/oracle-install.sh && ~/oracle-install.sh ${oracle_install_zip}"





# NOTES:
# test if oracle is running: ps -fu oracle | grep -i smon

sudo su - oracle
. ./.bash_profile
sqlplus sys as sysdba












##################################################################################################################
OLD
OLD
OLD
OLD
OLD
OLD
OLD
OLD
##################################################################################################################



gcloud compute instances create example-instance \
  --metadata-from-file startup-script=examples/scripts/install.sh


gcloud compute instances create oraclevm1 \
    --image-project="rhel-cloud" \
    --image-family="rhel-7" \
    --machine-type="n1-standard-4" \
    --subnet="projects/smart-analytics-demo-01/regions/us-east4/subnetworks/default" \
    --zone=${oracleZone} \
    --scopes storage-ro \
    --metadata startup-script-url="https://storage.cloud.google.com/sa-demo-cdc/oracle-install.sh"

gcloud compute instances create example-instance  --image-family=rhel-8 --image-project=rhel-cloud  --zone=us-central1-a


{
  "canIpForward": false,
  "cpuPlatform": "Intel Broadwell",
  "creationTimestamp": "2021-01-19T11:40:07.359-08:00",
  "deletionProtection": false,
  "disks": [
    {
      "autoDelete": true,
      "boot": true,
      "deviceName": "persistent-disk-0",
      "diskSizeGb": "400",
      "guestOsFeatures": [
        {
          "type": "UEFI_COMPATIBLE"
        }
      ],
      "index": 0,
      "interface": "SCSI",
      "kind": "compute#attachedDisk",
      "licenses": [
        "projects/rhel-cloud/global/licenses/rhel-7-server"
      ],
      "mode": "READ_WRITE",
      "source": "projects/smart-analytics-demo-01/zones/us-east4-c/disks/oracledb1",
      "type": "PERSISTENT"
    }
  ],
  "fingerprint": "M7V-GjZs8wQ=",
  "id": "181018606843890554",
  "kind": "compute#instance",
  "labelFingerprint": "42WmSpB8rSM=",
  "lastStartTimestamp": "2021-01-19T11:40:11.505-08:00",
  "machineType": "projects/smart-analytics-demo-01/zones/us-east4-c/machineTypes/n1-standard-4",
  "metadata": {
    "fingerprint": "EsOiDJGAbGM=",
    "kind": "compute#metadata"
  },
  "name": "oracledb1",
  "networkInterfaces": [
    {
      "accessConfigs": [
        {
          "kind": "compute#accessConfig",
          "name": "external-nat",
          "natIP": "35.245.174.67",
          "networkTier": "PREMIUM",
          "type": "ONE_TO_ONE_NAT"
        }
      ],
      "fingerprint": "wfEBa71LR84=",
      "kind": "compute#networkInterface",
      "name": "nic0",
      "network": "projects/smart-analytics-demo-01/global/networks/default",
      "networkIP": "10.150.0.2",
      "subnetwork": "projects/smart-analytics-demo-01/regions/us-east4/subnetworks/default"
    }
  ],
  "scheduling": {
    "automaticRestart": true,
    "onHostMaintenance": "MIGRATE",
    "preemptible": false
  },
  "selfLink": "projects/smart-analytics-demo-01/zones/us-east4-c/instances/oracledb1",
  "serviceAccounts": [
    {
      "email": "159965866633-compute@developer.gserviceaccount.com",
      "scopes": [
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring.write",
        "https://www.googleapis.com/auth/pubsub",
        "https://www.googleapis.com/auth/service.management.readonly",
        "https://www.googleapis.com/auth/servicecontrol",
        "https://www.googleapis.com/auth/trace.append"
      ]
    }
  ],
  "shieldedInstanceConfig": {
    "enableIntegrityMonitoring": true,
    "enableSecureBoot": false,
    "enableVtpm": true
  },
  "shieldedInstanceIntegrityPolicy": {
    "updateAutoLearnPolicy": true
  },
  "startRestricted": false,
  "status": "RUNNING",
  "tags": {
    "fingerprint": "_9TNTPLpA5U=",
    "items": [
      "oracledb"
    ]
  },
  "zone": "projects/smart-analytics-demo-01/zones/us-east4-c"
}












NAME="Red Hat Enterprise Linux Server"
VERSION="7.9 (Maipo)"
ID="rhel"
ID_LIKE="fedora"
VARIANT="Server"
VARIANT_ID="server"
VERSION_ID="7.9"
PRETTY_NAME="Red Hat Enterprise Linux Server 7.9 (Maipo)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:redhat:enterprise_linux:7.9:GA:server"
HOME_URL="https://www.redhat.com/"
BUG_REPORT_URL="https://bugzilla.redhat.com/"



https://oracle-base.com/articles/18c/oracle-db-18c-rpm-installation-on-oracle-linux-6-and-7#oracle_installation


curl -o oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm
yum -y localinstall oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm
rm oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm


# Install
- https://docs.oracle.com/en/database/oracle/oracle-database/18/xeinl/procedure-installing-oracle-database-xe.html
```
# Set root
sudo -s

# REHL 7 pre-reqs
curl -o oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm
yum -y localinstall oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm

# Oracle XC
curl -L https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-18c-1.0-1.x86_64.rpm --output oracle-database-xe-18c-1.0-1.x86_64.rpm 
yum -y localinstall oracle-database-xe-18c-1.0-1.x86_64.rpm

# Sample database
(echo "WelcomeWelcome1"; echo "WelcomeWelcome1";) | /etc/init.d/oracle-xe-18c configure >> /xe_logs/XEsilentinstall.log 2>&1



# Silient install?
mkdir /xe_logs
echo '#!/bin/bash' > myscript.sh
echo 'yum -y localinstall oracle-database-xe–18c-1.0-1.x86_64.rpm > /xe_logs/XEsilentinstall.log 2>&1' >> myscript.sh
echo '/etc/init.d/oracle-xe-18c configure >> /xe_logs/XEsilentinstall.log 2>&1' >> myscript.sh
chmod +x myscript.sh
sudo ./myscript.sh WelcomeWelcome1


```
(echo "WelcomeWelcome1"; echo "WelcomeWelcome1";) | /etc/init.d/oracle-xe-18c configure >> /xe_logs/XEsilentinstall.log 2>&1


# rm oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm
# rm oracle-database-xe-18c-1.0-1.x86_64.rpm

# Install sample database
sudo -s
/etc/init.d/oracle-xe-18c configure