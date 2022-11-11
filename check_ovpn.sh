#!/bin/bash

# default constant value
CONFDIR=$1
# get the prefix(id) word from the full path
VPNPREFIX=$(basename $CONFDIR)
CONFFILE=$(ls $CONFDIR | grep ovpn)
COMMAND="openvpn --config $CONFDIR$CONFFILE"

if [ -z $CONFFILE ]; then
	echo "Faild to find OpenVPN config file"
	exit 1
fi


# store existing tunnel interface names, this will be used to find out
# newly created interfaces
TUNS=()
ADDRS=()

for NAME in $(ls /sys/class/net | grep tun)
do
	TUNS+=($NAME)
	ADDRS+=($(/sbin/ip -o -4 addr list $NAME | awk '{print $4}' | cut -d/ -f1))
done

# check if unneccessary ip rules exist
ip rule show | grep POA | while IFS= read -r LINE
do
	ip=$(echo $LINE | awk '{print $3}')

	# rule with ip address which isn't owned by any tun devices must be removed
	if [[ ! " ${ADDRS[@]} " =~ " ${ip} " ]]; then
		for TABLE in $(ip rule show | grep $ip | awk '{print $5}')
		do
			ip rule del from $ip table $TABLE
		done
	fi
done

# check if openvpn is running at the moment (if running, must be 1)
TOTAL=$(ps aux | grep "openvpn --config $CONFDIR" | wc -l)
SHELLP=$(ps aux | grep "&& openvpn --config $CONFDIR" | wc -l)

PROCESSNUM=$(expr $TOTAL - $SHELLP)

if [ "$PROCESSNUM" != 1 ]; then
	# Openvpn is not running or something wrong

	# kill all process associated with current openvpn (screen command)
	for pid in `ps -ef | grep "openvpn --config $CONFDIR" | awk '{print $2}'` ; do kill $pid 2>/dev/null; done

	# run new OpenVPN process
	SOCKNAME=$VPNPREFIX"_VPN"
	screen -S $SOCKNAME -d -m -- sh -c "cd $CONFDIR && $COMMAND; exec $SHELL"
	# considered network latency
	sleep 5

	# get tun list again to find out new one
	NEWTUN=""

	for NAME in $(ls /sys/class/net | grep tun)
	do
		if [[ ! " ${TUNS[@]} " =~ " ${NAME} " ]]; then
			NEWTUN=$NAME
		fi
	done

	# add ip rule
	TABLENAME="$VPNPREFIX""POA"
	NEWADDR=$(/sbin/ip -o -4 addr list $NEWTUN | awk '{print $4}' | cut -d/ -f1)

	ip rule add from $NEWADDR table $TABLENAME
	ip route add default via $NEWADDR dev $NEWTUN table $TABLENAME
else
	echo "Already running, skipping..."
fi


