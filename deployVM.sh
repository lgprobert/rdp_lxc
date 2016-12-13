#!/bin/sh 
usage() {
  echo "usage: $0 -h <remote_VM_host> -d <cluster_cfg_dir>"
}

if (( $# < 4 )); then
	echo "You must provide the cluster configuration path."
	usage
	exit
fi
while getopts ":h:d:" opt_char
do
    case $opt_char in
        h)
            VMHOST=$OPTARG
            ;;
        d)  
            CFGDIR=$OPTARG
            ;;  
        \?)
	        echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done


if [[ ! (-d ${CFGDIR}) ]]; then
	echo "The provided path is not correct, fix the problem and rerun the script."
	exit
elif [[ ! ( -e $CFGDIR/cluster.csv && -f $CFGDIR/cluster.csv ) ]]; then
	echo "There is no cluster.cfg file in provided directory."
	exit
fi

ssh $VMHOST "if [[ ! (-d /var/lib/rapids/cfg/clusters) ]]; then mkdir /var/lib/rapids/cfg/cluster;fi"
scp -r $CFGDIR $VMHOST:/var/lib/rapids/cfg/clusters 

declare -A templist
for line in `cat template.lst`
do
	KEY=`echo $line | cut -d: -f1`
	VALUE=`echo $line | cut -d: -f2`
	templist[${KEY}]=${VALUE}
	echo templist[${KEY}] 
done

while IFS=, read HOST IP MASK CPU MEM RDPROLE DSTYPE DSROLE VMHOST
do
	echo "rdprole: $RDPROLE"
	case $RDPROLE in
		none)
			TEMPLATE=${templist["bare"]}
			;;
		dqc|dqe)
			if [[ $DSTYPE == "memsql" && $DSROLE == "memsql-p" ]]; then
				TEMPLATE=${templist["memsql"]}
			else
				TEMPLATE=${templist["rdp"]}
			fi
			;;
	esac

echo 	"./setup_lxc.sh -n $HOST -i $IP -m $MASK -c $CPU -M $MEM -t $TEMPLATE" >> $CFGDIR/${VMHOST}.cmd
done < $CFGDIR/cluster.csv

echo "The deployment script for all VM Hosts are ready"
