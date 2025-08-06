#!/bin/bash

SETUP_WORKER_SCRIPT="/mnt/ddn/infinia_setup/scripts/setup_non-realm-entry_server_nodes.sh"
CMD_OUTPUT_DIR="/mnt/ddn/infinia_setup/scripts/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/p_setup_non-realm-entry_server_nodes_output"
# For 6 x Node Cluster
FIRST_NODE=2
LAST_NODE=6
SLEEPT=1

# DO NOT EDIT BELOW, UNLESS NECESSARY

CMD_OUTPUT_FILE=$BASE_CMD_OUTPUT_FILE"_`date +%F-%T`.txt"
echo "Setting up Infinia in the Cluster worker nodes: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE

# Infinia Worker Server Nodes for 6 x node cluster - node[1-6]
for((i=$FIRST_NODE;i<=$LAST_NODE;i++));
do
	echo "Setting up Infinia in worker node node$i at : `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
	echo "---------------------------------------------------" 2>&1 | tee -a $CMD_OUTPUT_FILE
	ssh node$i "$SETUP_WORKER_SCRIPT" 2>&1 | tee -a $CMD_OUTPUT_FILE
	sleep $SLEEPT
	echo "============================================================" 2>&1 | tee -a $CMD_OUTPUT_FILE

done
