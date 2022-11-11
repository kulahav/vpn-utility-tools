#!/bin/bash

# Usage: command confpath vpnclientusername clientpassword

CONFPATH=$1
USERNAME=$2
PASSWORD=$3

# check availablity
if [[ $4 || -z $CONFPATH || -z $USERNAME || -z $PASSWORD ]]; then
	echo -e "Plase type input parameters correctly!\n"
	echo -e "\t Usage: command config_file_path username password"
	exit 1
fi

if [ -f "$CONFPATH" ]; then
	echo -e "Client conf file path: $CONFPATH\n"
else
	echo -e "No such config file exists!\n"
	exit 1
fi


# add routing rules for remaining ssh connections after vpn is active
ip rule add from $(ip route get 1 | grep -Po '(?<=src )(\S+)') table 128
ip route add table 128 to $(ip route get 1 | grep -Po '(?<=src )(\S+)')/32 dev $(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
ip route add table 128 default via $(ip -4 route ls | grep default | grep -Po '(?<=via )(\S+)')

# get the dir path of client config file, user-auth file will be create here
CONFDIR=$(dirname "${CONFPATH}")
CONFFILE=$(basename "${CONFPATH}")
AUTHFILE="auth"
AUTHPATH="$CONFDIR$AUTHFILE"

# create auth-user-pass file
echo -e "$USERNAME\n$PASSWORD\n" > $AUTHPATH

# store existing tunnel interface names, this will be used to find out
# newly created interfaces
MAX=100
INDEX=0
TUNS[0]=""

for NAME in $(ls /sys/class/net | grep tun)
do
	TUNS[$INDEX]=$NAME
	echo TUNS[$INDEX]
	let INDEX+=1
done

# run openvpn as a daemon
if [ ! -f /usr/sbin/openvpn ]; then
	echo "Error: OpenVPN is not installed, please install it and try again."
	exit 1
else
	openvpn --config $CONFPATH --auth-user-pass $AUTHPATH --daemon
	
fi

sleep 10

# get tun list again to find out new one
INDEX=0
NEWTUN=""

for NAME in $(ls /sys/class/net | grep tun)
do
	if [ "$NAME" != TUNS[$INDEX] ]; then
		NEWTUN=$NAME
		echo -e "Connected! Interface $NEWTUN is created.\n"

		# delete routing rules
		ip route show | grep $NEWTUN | while IFS= read -r LINE
		do
			ip route del $LINE
		done
	fi
	let INDEX+=1
done

rm $AUTHPATH

if [ -z $NEWTUN ]; then
	echo "Connection Failed"
	
fi
