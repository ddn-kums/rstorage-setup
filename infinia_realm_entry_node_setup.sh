#!/bin/bash

REALM_ENTRY_SECRET="DDN1nfini@R0cks!"
REALM_ADMIN_PASSWD="DDN1nfini@R0cks!"
CTRL_PLANE_IP_SUBNET="10.0.1"
CTRL_PLANE_IP_SUBNET_MASK="24"
CMD_OUTPUT_DIR="/mnt/ddn/infinia_setup/scripts/cmd_output"
BASE_CMD_OUTPUT_FILE="$CMD_OUTPUT_DIR/realm_entry_node_setup_output"
REALM_CONFIG_YAML_DIR="/mnt/ddn/infinia_setup/scripts"
REALM_CONFIG_YAML_BACKUP_DIR="/tmp"

SLEEPT=1

# DO NOT EDIT BELOW, UNLESS NECESSARY

CMD_OUTPUT_FILE=$BASE_CMD_OUTPUT_FILE"_`date +%F-%T`.txt"
echo "Setting Infinia on the realm entry node: `date`" 2>&1 | tee -a $CMD_OUTPUT_FILE

export BASE_PKG_URL="https://storage.googleapis.com/ddn-redsetup-public" &&
export RELEASE_TYPE="" && \
export TARGET_ARCH="$(dpkg --print-architecture)" && \
export REL_DIST_PATH="ubuntu/24.04" && \
export REL_PKG_URL="${BASE_PKG_URL}/releases${RELEASE_TYPE}/${REL_DIST_PATH}" && \
export RED_VER="2.1.30"

wget $REL_PKG_URL/redsetup_"${RED_VER}"_"${TARGET_ARCH}${RELEASE_TYPE}".deb?cache-time="$(date +$s)" -O /tmp/redsetup.deb && \
sudo apt install -y /tmp/redsetup.deb 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "RED Version is $RED_VER" 2>&1 | tee -a $CMD_OUTPUT_FILE
echo "------------------------" 2>&1 | tee -a $CMD_OUTPUT_FILE
sleep $SLEEPT

echo "redsetup version" 2>&1 | tee -a $CMD_OUTPUT_FILE
echo "---------------" 2>&1 | tee -a $CMD_OUTPUT_FILE
redsetup -v 2>&1 | tee -a $CMD_OUTPUT_FILE

sleep $SLEEPT

echo "redsetup realm-entry node" 2>&1 | tee -a $CMD_OUTPUT_FILE
echo "-----------------------" 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "sudo redsetup --realm-entry --realm-entry-secret $REALM_ENTRY_SECRET  --admin-password $REALM_ADMIN_PASSWD \
        -ctrl-plane-ip $(ip addr | grep inet | grep -v inet6 | grep $CTRL_PLANE_IP_SUBNET |awk '{print $2}' |sed 's/\/'"$CTRL_PLANE_IP_SUBNET_MASK"'//')" 2>&1 | tee -a $CMD_OUTPUT_FILE
sudo redsetup --realm-entry --realm-entry-secret $REALM_ENTRY_SECRET  --admin-password $REALM_ADMIN_PASSWD \
	-ctrl-plane-ip $(ip addr | grep inet | grep -v inet6 | grep $CTRL_PLANE_IP_SUBNET |awk '{print $2}' |sed 's/\/'"$CTRL_PLANE_IP_SUBNET_MASK"'//') 2>&1 | tee -a $CMD_OUTPUT_FILE

echo "Backing up the old realm_config.yaml to /tmp" 2>&1 | tee -a $CMD_OUTPUT_FILE 
mv $REALM_CONFIG_YAML_DIR/realm_config.yaml $REALM_CONFIG_YAML_BACKUP_DIR
