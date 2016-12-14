#!/bin/sh

usage()
{
  echo "usage: $0 [-t <container_template>] -d <cluster_name> -n <container_name> -i <ip_address> -m <netmask> -c <CPU_share> -M <memory_in_GB>"
}

if [ $# -lt 14 ]; then
    usage
    exit 1
fi

TEMPLATE="co72"
LXCPATH=`lxc-config lxc.lxcpath`

while getopts ":t:d:n:i:m:g:p:c:M:" opt_char
do
    case $opt_char in
		t)
			if [ $OPTARG != "" ]; then
				TEMPLATE=$OPTARG
			fi
			;;

		d)
			CFGDIR=/var/lib/rapids/cfg/clusters/$OPTARG
			echo "Cluster configuration data directory: $CFGDIR"
			;;
		n) 
			LXCNAME=$OPTARG 
			;; 
		i) 
			IP=$OPTARG 
			;; 
		m)
			MASK=$OPTARG
			;;
		c)
			CPU=$OPTARG
			;;
		M)
			MEM=$OPTARG
			;;
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit 1
            ;;
    esac
done

# old version clone command
#lxc-copy -n $TEMPLATE -N $LXCNAME
#lxc-clone $TEMPLATE $LXCNAME
# r2.x clone command
#lxc-copy -B btrfs -n $TEMPLATE -N $LXCNAME
lxc-copy -B zfs  -n $TEMPLATE -N $LXCNAME

echo "Setup container $LXCNAME, wait ..."

cd $LXCPATH/$LXCNAME
echo "lxc.cgroup.cpu.shares = $CPU" >> config
echo "lxc.cgroup.memory.limit_in_bytes  = ${MEM}G" >> config

# Goes to /etc to configure hosts and hostname files
cd rootfs/etc
echo "Copying $CFGDIR/hosts to target container"
cp $CFGDIR/hosts .
echo $LXCNAME > hostname
# add hostname info to network
cd sysconfig
# add static IP info to eth0 config file
cd network-scripts
sed -i 's/dhcp/none/; /IPADDR/ s/=\(.*\)/='"$IP"'/; /NETMASK/ s/=\(.*\)/='"$MASK"'/; /^MTU=/ s/=\(.*\)/=1500/' ifcfg-eth0
# return to conatiner's global root directory
cd $LXCPATH/$LXCNAME

echo "Finished configuration, now it is starting the container."
lxc-start -d -n $LXCNAME
lxc-info -n $LXCNAME

echo "Container $LXCNAME is fully deployed and up, you can access it now."
