#!/bin/bash

TEARDOWN_SCRIPT="/work/kums/infinia_cluster_3/setup/teardown_client.sh"
CMD_OUTPUT_DIR="/work/kums/infinia_cluster_3/setup/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/p_client_teardown_output"
# For 12 x Node Cluster
#FIRST_NODE=13
# For 6 x Node Cluster
FIRST_NODE=13
LAST_NODE=18
SLEEPT=1

CMD_OUTPUT_FILE=$BASE_CMD_OUTPUT_FILE"_`date +%F-%T`.txt"
echo "Tearing down the Infnia client setup on client nodes: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE

# Infinia Server Nodes for 12 x node cluster - srt[013-024] 
for((i=$FIRST_NODE;i<=$LAST_NODE;i++));
do
	echo "Tearing down the RED Client setup from client node srt0$i at : `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE
	ssh srt0$i "sudo $TEARDOWN_SCRIPT" 2>&1 | tee -a $CMD_OUTPUT_FILE
	sleep $SLEEPT
	echo "============================================================" 2>&1 | tee -a $CMD_OUTPUT_FILE

done
