#!/bin/bash

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


#########################################################################################################################
# BEGIN: Commom code for ALL deploy / bash scripts.  Any changes must be copied and pasted in all files that use this!
#########################################################################################################################
echo "---------------------------------------------------------------------------------------------------------" 
echo "Parameters (read from a config file, you can have different configs for different environments)"
echo "---------------------------------------------------------------------------------------------------------" 
# Make sure we got a command line arguement
if [ "$1" = ""  ]; then
    echo "ERROR: You need to pass in a main-config.json file"
    exit 1
fi

# Get full path (important when passing to another program)
configJSONFilename=$(echo "$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")")

# Load JSON
configJSON=$(cat $configJSONFilename)

# Parse each value using jq
project=$(echo "$configJSON" | jq .project --raw-output)
GOOGLE_APPLICATION_CREDENTIALS=$(echo "$configJSON" | jq .GOOGLE_APPLICATION_CREDENTIALS --raw-output)
export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS
environment=$(echo "$configJSON" | jq .environment --raw-output)
looker_customer_id=$(echo "$configJSON" | jq .looker_customer_id --raw-output)
LOOKER_APPLICATION_CREDENTIALS=$(echo "$configJSON" | jq .LOOKER_APPLICATION_CREDENTIALS --raw-output)
looker_git_remote_url=$(echo "$configJSON" | jq .looker_git_remote_url --raw-output)
looker_origin=$(echo "$configJSON" | jq .looker_origin --raw-output)
oracle_install_zip=$(echo "$configJSON" | jq .oracle_install_zip --raw-output)

echo "CONFIG ==> configJSONFilename:             $configJSONFilename"
echo "CONFIG ==> project:                        $project"
echo "CONFIG ==> GOOGLE_APPLICATION_CREDENTIALS: $GOOGLE_APPLICATION_CREDENTIALS"
echo "CONFIG ==> environment:                    $environment"
echo "CONFIG ==> looker_customer_id:             $looker_customer_id"
echo "CONFIG ==> LOOKER_APPLICATION_CREDENTIALS: $LOOKER_APPLICATION_CREDENTIALS"
echo "CONFIG ==> looker_git_remote_url:          $looker_git_remote_url"
echo "CONFIG ==> looker_origin:                  $looker_origin"
echo "CONFIG --> oracle_install_zip:             $oracle_install_zip"
#########################################################################################################################
# END:   Commom code for ALL deploy / bash scripts.  Any changes must be copied and pasted in all files that use this!
#########################################################################################################################


echo "---------------------------------------------------------------------------------------------------------" 
echo "Setting names and locations (These could be placed in the config)"
echo "---------------------------------------------------------------------------------------------------------" 
# You can set these, but you need to ensure the location exists for each service
region="us-west2"
zone="us-west2-a"
datafusion_name="sa-datafusion-$environment"
datafusion_location="us-west2"
composer_name="sa-composer-$environment"
composer_location="us-west2"
composer_zone="us-west2-a"
cloudFunctionBucket="sa-ingestion-$environment"

echo "region:$region"
echo "zone:$zone"
echo "datafusion_name:$datafusion_name"
echo "datafusion_location:$datafusion_location"
echo "composer_name:$composer_name"
echo "composer_location:$composer_location"
echo "composer_zone:$composer_zone"
echo "cloudFunctionBucket:$cloudFunctionBucket"


echo "---------------------------------------------------------------------------------------------------------" 
echo "Login using service account"
echo "---------------------------------------------------------------------------------------------------------" 
# The username of the service account (e.g.  "smart-analytics-dev-ops@smart-analytics-demo-01.iam.gserviceaccount.com" )
accountName=$(cat $GOOGLE_APPLICATION_CREDENTIALS | jq .client_email --raw-output)

gcloud auth activate-service-account $accountName --key-file=$GOOGLE_APPLICATION_CREDENTIALS --project=$project


echo "---------------------------------------------------------------------------------------------------------" 
echo "Create Oracle Compute VM"
echo "---------------------------------------------------------------------------------------------------------" 

# The OracleVM and tag values are also in the deploy-datastream.sh file
sshUser="gcpadmin"
sshFile="gcpcloud-${environment}"
oracleVM="oracle-vm-${environment}"
tag="oracle-datastream"

# Create a SSH key for logging into the VM
if test -f ~/.ssh/${sshFile}; then
   echo "${sshFile} file exists."
else
  ssh-keygen -t rsa -f ~/.ssh/${sshFile} -C ${sshUser} -q -N ""
  chmod 400 ~/.ssh/${sshFile}
fi

gcloud compute instances create ${oracleVM} \
  --image-project="rhel-cloud" \
  --image-family="rhel-7" \
  --machine-type="n1-standard-4" \
  --boot-disk-size="400GB" \
  --subnet="projects/${project}/regions/${region}/subnetworks/default" \
  --zone=${zone} \
  --tags ${tag}

ip=$(curl --silent ifconfig.me/ip)

#  create network rule
gcloud compute firewall-rules create "oracle-ssh-ingress" \
  --description="Allow TCP SSH" \
  --direction=INGRESS \
  --allow=tcp:22 \
  --source-ranges=${ip} \
  --target-tags=${tag}

gcloud compute os-login ssh-keys add --project ${project} --key-file ~/.ssh/${sshFile}.pub

echo "---------------------------------------------------------------------------------------------------------" 
echo "Installing Oracle (This will take some time)"
echo "---------------------------------------------------------------------------------------------------------" 
gcloud compute scp --zone ${zone} --ssh-key-file=~/.ssh/${sshFile} ./oracle-install.sh ${sshUser}@${oracleVM}:~/oracle-install.sh
gcloud compute scp --zone ${zone} --ssh-key-file=~/.ssh/${sshFile} ./hr_main_custom.sql ${sshUser}@${oracleVM}:/tmp/hr_main_custom.sql

gcloud compute ssh --zone ${zone} --ssh-key-file=~/.ssh/${sshFile} ${sshUser}@${oracleVM} \
  --command "chmod 777 /tmp/hr_main_custom.sql"

gcloud compute ssh --zone ${zone} --ssh-key-file=~/.ssh/${sshFile} ${sshUser}@${oracleVM} \
  --command "chmod +x ~/oracle-install.sh && ~/oracle-install.sh ${oracle_install_zip}"


echo "---------------------------------------------------------------------------------------------------------" 
echo "To Verify Oracle Installation"
echo "---------------------------------------------------------------------------------------------------------" 
echo "To manaully check if Oracle got installed properly ssh to the machine using this command:"
echo "gcloud compute ssh ${sshUser}@${oracleVM} --ssh-key-file=~/.ssh/${sshFile} --zone ${zone}"
echo "Then run: ps -fu oracle | grep -i smon"
echo ""
echo "To Login to SQL Plus, ssh to the machine:"
echo "gcloud compute ssh ${sshUser}@${oracleVM} --ssh-key-file=~/.ssh/${sshFile} --zone ${zone}"
echo "Then run the following:"
echo "sudo su - oracle"
echo ". ./.bash_profile"
echo "sqlplus sys as sysdba"
echo ""

# gcloud compute ssh gcpadmin@oracle-vm-myid-dev --ssh-key-file=~/.ssh/gcpcloud-myid-dev --zone us-west2-a
# sudo su - oracle
# . ./.bash_profile
# sqlplus sys as sysdba