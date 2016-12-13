#!/bin/sh 
usage() {
  echo "usage: $0 [-z <zookeeper host list, default: dqc:2181>] -d <cluster_cfg_dir>"
}

if (( $# < 2 )); then
	echo "You must provide the cluster configuration path."
	usage
	exit
fi

ZKLIST=''
while getopts ":z:d:" opt_char
do
    case $opt_char in
        z)
            ZKLIST=$OPTARG
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

CLUSTER=`basename $CFGDIR`

if [[ ! (-d ${CFGDIR}) ]]; then
	echo "The provided path is not correct, fix the problem and rerun the script."
	exit
elif [[ ! ( -e $CFGDIR/cluster.csv && -f $CFGDIR/cluster.csv ) ]]; then
	echo "There is no cluster.cfg file in provided directory."
	exit
fi

declare -A templist
for line in `cat template.lst`
do
	KEY=`echo $line | cut -d: -f1`
	VALUE=`echo $line | cut -d: -f2`
	templist[${KEY}]=${VALUE}
done

echo "Generating container deployment instructions for each joining VM host..."
while IFS=, read HOST IP MASK CPU MEM RDPROLE DSTYPE DSROLE VMHOST
do
	case $RDPROLE in
		none)
			if [[ $DSTYPE == "memsql" && $DSROLE == "memsql-p" ]]; then
				TEMPLATE=${templist["memsql"]}
			else
				TEMPLATE=${templist["bare"]}
			fi
			;;
		dqc|dqe)
			if [[ $DSTYPE == "memsql" && $DSROLE == "memsql-p" ]]; then
				TEMPLATE=${templist["memsql"]}
			else
				TEMPLATE=${templist["rdp"]}
			fi
			;;
	esac

	if [[ $RDPROLE == "dqc" && $ZKLIST=="" ]]; then
		sed 's/localhost/'"$IP"'/' zk.config.sample > zk.config
		mv zk.config $CFGDIR
	else
		sed 's/localhost/'"$ZKLIST"'/' zk.config.sample > zk.config
	fi
	echo "setup_lxc.sh -n $HOST -i $IP -m $MASK -c $CPU -M $MEM -t $TEMPLATE" >> $CFGDIR/${VMHOST}.cmd
done < $CFGDIR/cluster.csv

# Prepare RapidsDB cluster configuration file
echo "Generating RapidsDB configuration file"
python mk_rdpConfig.py $CFGDIR/rdp.cluster
mv cluster.config $CFGDIR

# Copy specific config files to remote VM hosts
REMOTE_ROOT="/var/lib/rapids/cfg/clusters/${CLUSTER}"
for VMHOST in `cat vhost.lst`
do
	if [[ -e $VMHOST.cmd ]]; then
		ssh $VMHOST "if [[ ! (-d $REMOTE_ROOT) ]]; then mkdir -p $REMOTE_ROOT; fi"
		pdcp -w $VMHOST $CFGDIR/$VMHOST.cmd $CFGDIR/hosts $REMOTE_ROOT
		if [[ -e $CFGDIR/cluster.config ]]; then
			pdcp -w $VMHOST $CFGDIR/cluster.config $REMOTE_ROOT
		fi
		if [[ -e $CFGDIR/zk.config ]]; then
			pdcp -w $VMHOST $CFGDIR/zk.config $REMOTE_ROOT
		fi
	fi
done
echo "The deployment script for all VM Hosts are ready"
