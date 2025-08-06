#!/bin/bash

CMD_OUTPUT_DIR="/mnt/ddn/infinia_setup/scripts/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/update_s3_configs_all_nodes_output"
HOME_DIR="/home/ubuntu"
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


echo "Updating S3 config in node: `hostname` at: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE

sudo cp ~/.bashrc $REPO_DIR/bashrc 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo chmod 0755 $REPO_DIR/bashrc 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $NON_REALM_AND_CLIENT_NODES "cp $REPO_DIR/bashrc $HOME_DIR/.bashrc" 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $ALL_NODES "ls -l $HOME_DIR/.bashrc" | dshbak -c 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $ALL_NODES "md5sum $HOME_DIR/.bashrc" | dshbak -c 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT
#get_user_input

echo "Cloning aws/credentials to rest of the nodes" 2>&1 | tee -a $CMD_OUTPUT_FILE
cp ~/.aws/credentials $REPO_DIR/aws-credentials 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo chmod 0755 $REPO_DIR/aws-credentials 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $NON_REALM_AND_CLIENT_NODES "cp $REPO_DIR/aws-credentials $HOME_DIR/.aws/credentials" 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $ALL_NODES "ls -l $HOME_DIR/.aws/credentials" | dshbak -c 2>&1 | tee -a $CMD_OUTPUT_FILE
pdsh -w $ALL_NODES "md5sum $HOME_DIR/.aws/credentials" | dshbak -c 2>&1 | tee -a $CMD_OUTPUT_FILE
