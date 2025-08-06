#!/bin/bash

SLEEPT=1

get_user_input () {

	echo "Proceed to next check: Y/N"
	read user_input

}

echo "Verifying 100GbE Link and Speeds"
pdsh -w node[1-6],client[1-6] "sudo ethtool ens300np0 | egrep 'Link detected:|Speed:'" | dshbak -c
get_user_input

echo "Verifying 100GbE connectivity"
for((i=1; i<7;i++)) ; do echo node"$i"; ping -c 2 node"$i"; sleep $SLEEPT; done
for((i=1; i<7;i++)) ; do echo client"$i"; ping -c 2 client"$i"; sleep $SLEEPT; done
get_user_input

echo "Verifying Samsung NVMe"
pdsh -w node[1-6] "sudo nvme --list | grep SAMSUNG" | dshbak -c
pdsh -w node[1-6] "sudo nvme --list | grep SAMSUNG | wc -l" | dshbak -c
get_user_input

echo "Verifying MTU=9000"
pdsh -w node[1-6],client[1-6] "ifconfig ens300np0 | grep -i mtu" | dshbak -c
get_user_input

echo "Verifying CPU"
pdsh -w node[1-6],client[1-6] "sudo lscpu | egrep '^CPU|^Model' | grep -v MHz" | dshbak -c
pdsh -w node[1-6],client[1-6] "sudo lscpu | grep NUMA" | dshbak -c
get_user_input

echo "Verifying Memory" 
pdsh -w node[1-6],client[1-6] "sudo cat /proc/meminfo | grep -i MemTotal" | dshbak -c
get_user_input

echo "Verifying Free Memory" 
pdsh -w node[1-6],client[1-6] "free -g" | dshbak -c
pdsh -w node[1-6],client[1-6] "sudo lscpu | grep NUMA" | dshbak -c
get_user_input

echo "Verifying OS Kernel"
pdsh -w node[1-6],client[1-6] "cat /etc/os-release | egrep VERSION" | dshbak -c
pdsh -w node[1-6],client[1-6] "uname -r" | dshbak -c
get_user_input

echo "Verifying HSE Network HCA" 
pdsh -w node[1-6],client[1-6] "sudo lspci | grep Mellanox" | dshbak -c
pdsh -w node[1-6],client[1-6] "sudo lspci -s 61:00.0 -vvv | egrep 'LnkCap:|LnkCtl:|LnkSta:'" | dshbak -c
pdsh -w node[1-6],client[1-6] "sudo lspci -s a1:00.0 -vvv | egrep 'LnkCap:|LnkCtl:|LnkSta:'" | dshbak -c
get_user_input


echo "Verifying Synchronized date"
pdsh -w node[1-6],client[1-6] "date" | dshbak -c
get_user_input

echo "Verifying /etc/hosts does not contain localhost"
pdsh -w node[1-6],client[1-6] "grep localhost /etc/hosts" | dshbak -c
get_user_input

echo "Verifying /etc/hosts has unique node names and IP address"
for((i=1;i<=6;i++)); do echo "Server name: node$i"; pdsh -w node[1-6],client[1-6] grep node"$i" /etc/hosts | dshbak -c; done
for((i=1;i<=6;i++)); do echo "Client name: client$i"; pdsh -w node[1-6],client[1-6] grep client"$i" /etc/hosts | dshbak -c; done
get_user_input

echo "Verifying that the HSN IP address are in Unique IP subnet"
pdsh -w node[1-6],client[1-6] "ip addr show | grep 10.0.1" | dshbak -c
get_user_input

echo "Verifying RoCE status"
pdsh -w node[1-6],client[1-6] "rdma link show | grep ACTIVE" | dshbak -c
get_user_input

echo "Verifying NFS mount"
pdsh -w node[1-6],client[1-6] "cat /mnt/ddn/hello.txt" | dshbak -c
