#!/bin/bash

REALM_ADMIN_PASSWD="DDN1nfini@R0cks!"
INFINIA_LICENSE_KEY="E94E1FD8-8E4D-4E28-AEAE-AA8594828A2F"
CMD_OUTPUT_DIR="/mnt/ddn/infinia_setup/scripts/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/infinia_cluster_setup_output"
SLEEPT=2

# DO NOT EDIT BELOW, UNLESS NECESSARY

CMD_OUTPUT_FILE=$BASE_CMD_OUTPUT_FILE"_`date +%F-%T`.txt"

echo "Infinia cluster setup in node: `hostname` at: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
echo "Login as realm_admin" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user login realm_admin --password $REALM_ADMIN_PASSWD 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "redcli inventory show" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli inventory show 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Generate config" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli realm config update --generate 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "Login as realm_admin" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli user login realm_admin --password $REALM_ADMIN_PASSWD 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "License install" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli license install -a $INFINIA_LICENSE_KEY -y 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Infinia cluster creation: `date`"
# TCP
#echo "redcli cluster create -z cluster1 -S=true -n tcp" 2>&1 | tee -a $CMD_OUTPUT_FILE
#redcli cluster create -z cluster1 -S=true -n tcp 2>&1 | tee -a $CMD_OUTPUT_FILE
# RDMA
echo "redcli cluster create -z cluster1 -S=true" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli cluster create -z cluster1 -S=true 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "Infinia cluster creation successful: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli cluster show cluster1 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "Infinia cluster status `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli cluster show cluster1 --status 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "Infinia cluster health `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli cluster show cluster1 --health 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "Infinia Cluster compression and encryption setting" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli config show runtime  -o json | egrep 'encryption|compression' 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Realm Agent Status" 2>&1 | tee -a $CMD_OUTPUT_FILE
redcli realm agent-status 2>&1 | tee -a $CMD_OUTPUT_FILE
