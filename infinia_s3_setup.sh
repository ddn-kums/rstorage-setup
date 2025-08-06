#!/bin/bash

REALM_ADMIN_PASSWD="DDN1nfini@R0cks!"
CMD_OUTPUT_DIR="/mnt/ddn/infinia_setup/scripts/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/infinia_s3_setup_output"
HOME_DIR="/home/ubuntu"
CERT_FILE="ca.pem"
REPO_DIR="/mnt/ddn/infinia_cluster/repo"
NON_REALM_AND_CLIENT_NODES="node[2-6],client[1-6]"
ALL_NODES="node[1-6],client[1-6]"
SLEEPT=1

# DO NOT EDIT BELOW, UNLESS NECESSARY

CMD_OUTPUT_FILE=$BASE_CMD_OUTPUT_FILE"_`date +%F-%T`.txt"

get_user_input () {
        
        echo "Proceed to next step: Y/N"
        read user_input

}

echo "Setting up Infinia S3 in node: `hostname` at: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Login as Realm Admin and Verify Cluster Status" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user login realm_admin --password $REALM_ADMIN_PASSWD 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli cluster show cluster1 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT
#get_user_input

echo "Grant realm_admin access to Tenant red" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user grant realm_admin red 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user grant realm_admin red/red 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "Add admin user for tenant red and grant access" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user add admin -p $REALM_ADMIN_PASSWD --scope red -t red 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user grant admin red/red -t red 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli s3 access add admin --scope red/red/redobj -e 10y 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT
#get_user_input

echo "Create S3 Buckets and Verify" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user login admin -p $REALM_ADMIN_PASSWD -t red 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

redcli s3 bucket create bucket1 -t red 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli s3 bucket create bucket2 -t red 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli s3 bucket create bucket3 -t red 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "S3 Buckets created successfully" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli s3 bucket list -t red | grep bucket 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT
#get_user_input

echo "Please Update .bashrc and aws/credentials with the ACCESS_KEY and SECRET_KEY" 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

redcli user list -t red 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Copying $CERT_FILE to $HOMEDIR" 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo cp /etc/red/certs/$CERT_FILE ~/ 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo chmod 0755 ~/$CERT_FILE 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Copying $CERT_FILE to rest of the Infinia and Client Nodes" 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo cp ~/$CERT_FILE $REPO_DIR 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo chmod 0755 $REPO_DIR/$CERT_FILE 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $NON_REALM_AND_CLIENT_NODES "cp $REPO_DIR/$CERT_FILE $HOME_DIR" 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $NON_REALM_AND_CLIENT_NODES "sudo chmod 0755 $HOME_DIR/$CERT_FILE" 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $ALL_NODES "md5sum $HOME_DIR/$CERT_FILE" | dshbak -c 2>&1 | tee -a $CMD_OUTPUT_FILE
