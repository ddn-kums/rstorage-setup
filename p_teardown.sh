#!/bin/bash

TEARDOWN_SCRIPT="/mnt/ddn/infinia_setup/scripts/teardown.sh"
CMD_OUTPUT_DIR="/mnt/ddn/infinia_setup/scripts/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/p_teardown_output"
# For 6 x Node Cluster
FIRST_NODE=1
LAST_NODE=6
SLEEPT=1

CMD_OUTPUT_FILE=$BASE_CMD_OUTPUT_FILE"_`date +%F-%T`.txt"
echo "Tearing down the Infnia setup from all the Cluster nodes: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE

# Infinia Server Nodes for 6 x node cluster 
for((i=$LAST_NODE;i>=$FIRST_NODE;i--));
do
	echo "Removing config.lock on node node$i at : `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
	ssh node$i "sudo rm -f /etc/red/deploy/config.lock" 2>&1 | tee -a $CMD_OUTPUT_FILE
	sleep $SLEEPT
	echo "============================================================" 2>&1 | tee -a $CMD_OUTPUT_FILE

done

sleep $SLEEPT

for((i=$LAST_NODE;i>=$FIRST_NODE;i--));
do
	echo "Tearing down the RED setup from cluster node node$i at : `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
	ssh node$i "sudo $TEARDOWN_SCRIPT" 2>&1 | tee -a $CMD_OUTPUT_FILE
	sleep $SLEEPT
	echo "============================================================" 2>&1 | tee -a $CMD_OUTPUT_FILE

done
