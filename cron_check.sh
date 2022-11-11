#!/bin/bash

CONFFOLDER="/home/VPN/"
CHECKSCRIPT="/root/check_ovpn.sh"

SUBDIRS=$(ls $CONFFOLDER)

for dir in $SUBDIRS
do
	$CHECKSCRIPT $CONFFOLDER$dir"/"
done