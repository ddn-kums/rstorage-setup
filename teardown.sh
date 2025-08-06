#!/bin/bash
SLEEPT=1

echo "Tearing down the Infinia setup: `date`"
sudo rm -f /etc/red/deploy/config.lock
sleep $SLEEPT
sudo redsetup --reset
sudo apt purge -y redsetup
sudo apt purge -y hadoop-red red-client-common red-java-sdk redcli redtools
docker system prune --all --force
