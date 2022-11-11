#!/bin/bash

# Usage: command confpath

CONFPATH=$1

# check availablity
if [[ $4 || -z $CONFPATH ]]; then
	echo -e "Command type invaild!\n"
	echo -e "\t Usage: command config_file_path"
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
EXTENSION=".conf"
NEWWG=""

if echo "$CONFFILE" | grep -q "$EXTENSION"; then
	NEWWG=${CONFFILE%"$EXTENSION"}
else
	echo -e "Conf name is invalid, must include extension \".conf\"..."
	exit 1
fi


TEMPPATH="$CONFDIR"/"$NEWWG"_temp.conf

if grep -Fxq "TABLE = off" $CONFPATH
then
	:
else
	sed '/\[Peer\]/i TABLE = off' $CONFPATH > $TEMPPATH
	cp -f $TEMPPATH $CONFPATH
	rm -f $TEMPPATH
fi

# check if there is already same interface
CONFIRM=$(ls /sys/class/net | grep $NEWWG)

if [ -z $CONFIRM ]; then
	:
else
    echo -e "Interface $NEWWG already exists, exiting..."
    exit 0
fi

# start the process
sudo wg-quick up $CONFPATH

CONFIRM=$(ls /sys/class/net | grep $NEWWG)

if [ -z $CONFIRM ]; then
	echo -e "\nFailed to create interface, or address already in use...\n"
else
    echo -e "\nProcess started, Interface $NEWWG is created.\n"
    echo -e "\nType \"sudo wg-quick down $CONFPATH\" to exit"
fi

