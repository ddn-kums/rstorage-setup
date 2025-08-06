#!/bin/bash

REALM_ENTRY_SECRET="DDN1nfini@R0cks!"
REALM_ENTRY_NODE_IP_ADDRESS="10.0.1.50"
CTRL_PLANE_IP_SUBNET="10.0.1"
CTRL_PLANE_IP_SUBNET_MASK="24"
SLEEPT=1

# DO NOT EDIT BELOW, UNLESS NECESSARY
echo "Setting Infinia on the non-realm-entry-node: `hostname` at `date`"

export BASE_PKG_URL="https://storage.googleapis.com/ddn-redsetup-public" &&
export RELEASE_TYPE="" && \
export TARGET_ARCH="$(dpkg --print-architecture)" && \
export REL_DIST_PATH="ubuntu/24.04" && \
export REL_PKG_URL="${BASE_PKG_URL}/releases${RELEASE_TYPE}/${REL_DIST_PATH}" && \
export RED_VER="2.1.30"

wget $REL_PKG_URL/redsetup_"${RED_VER}"_"${TARGET_ARCH}${RELEASE_TYPE}".deb?cache-time="$(date +$s)" \
-O /tmp/redsetup.deb && sudo apt install -y /tmp/redsetup.deb

sudo apt -y install /tmp/redsetup.deb
sleep $SLEEPT

echo "redsetup version"
echo "---------------"
redsetup -v

sleep $SLEEPT


if [ $(dpkg --print-architecture) == "amd64" ];
then
	echo "sudo redsetup --realm-entry-address $REALM_ENTRY_NODE_IP_ADDRESS --realm-entry-secret $REALM_ENTRY_SECRET --ctrl-plane-ip $(ip addr | grep inet | grep -v inet6 | grep $CTRL_PLANE_IP_SUBNET |awk '{print $2}' |sed 's/\/'"$CTRL_PLANE_IP_SUBNET_MASK"'//')"
	sudo redsetup --realm-entry-address $REALM_ENTRY_NODE_IP_ADDRESS --realm-entry-secret $REALM_ENTRY_SECRET --ctrl-plane-ip $(ip addr | grep inet | grep -v inet6 | grep $CTRL_PLANE_IP_SUBNET |awk '{print $2}' |sed 's/\/'"$CTRL_PLANE_IP_SUBNET_MASK"'//')
fi
