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
while getopts ":z:n:" opt_char
do
    case $opt_char in
        z)
            ZKLIST=$OPTARG
            ;;
        n)  
            CLUSTER=$OPTARG
            ;;  
        \?)
	        echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

#CLUSTER=`basename $CFGDIR`
CFGDIR="/var/lib/rapids/cfg/clusters/$CLUSTER"
echo "CLUSTER: $CLUSTER"

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

find $CFGDIR -type f \( -name *.cmd \) -exec rm {} +

echo "Generating container deployment instructions for each joining VM host..."
while IFS=, read HOST IP MASK CPU MEM RDPROLE DSTYPE DSROLE VMHOST
do
	case $RDPROLE in
		none)
			if [[ $DSTYPE == "memsql" && $DSROLE == "master" ]]; then
				TEMPLATE=${templist["memsql"]}
			else
				TEMPLATE=${templist["bare"]}
			fi
			;;
		dqc)
			if [[ $DSROLE == "master" && $RDPROLE == "dqc" ]]; then
				TEMPLATE=${templist["rdpmemsql"]}
			else
				TEMPLATE=${templist["rdp"]}
			fi
			;;
		dqe)
			TEMPLATE=${templist["rdp"]}
			;;
	esac

	if [[ $RDPROLE == "dqc" ]]; then
		if [[ $ZKLIST=="" ]]; then
			sed 's/localhost/'"$IP"'/' zk.config.sample > zk.config
		else
			sed 's/localhost/'"$ZKLIST"'/' zk.config.sample > zk.config
		fi
		mv zk.config $CFGDIR
	fi
	VCPU=`expr $CPU \* 100`
	echo "setup_lxc.sh -d $CLUSTER -n $HOST -i $IP -m $MASK -c $VCPU -M $MEM -t $TEMPLATE" >> $CFGDIR/${VMHOST}.cmd
done < $CFGDIR/cluster.csv

# Prepare RapidsDB cluster configuration file for RapidsDB cluster
grep rapidsdb $CFGDIR/cluster.type > /dev/null
if (( $? == 0 )); then
	echo "Generating RapidsDB configuration file"
	python mk_rdpConfig.py $CFGDIR/rdp.cluster
	mv cluster.config $CFGDIR
fi

# Copy specific config files to remote VM hosts
REMOTE_ROOT="/var/lib/rapids/cfg/clusters/${CLUSTER}"
echo "Remote root: $REMOTE_ROOT"
for VMHOST in `cat $CFGDIR/vhost.lst`
do
	echo "Processing $VMHOST..."
	if [[ -e $CFGDIR/$VMHOST.cmd ]]; then
		mv $CFGDIR/$VMHOST.cmd $CFGDIR/install_container.cmd
		chmod +x $CFGDIR/install_container.cmd
		ssh $VMHOST "if [[ ! (-d $REMOTE_ROOT) ]]; then mkdir -p $REMOTE_ROOT; fi"
		pdcp -w $VMHOST $CFGDIR/install_container.cmd $CFGDIR/hosts $REMOTE_ROOT
		grep rapidsdb $CFGDIR/cluster.type > /dev/null
		if (( $? == 0 )); then
			if [[ -e $CFGDIR/cluster.config ]]; then
				pdcp -w $VMHOST $CFGDIR/cluster.config $REMOTE_ROOT
			elif [[ -e $CFGDIR/zk.config ]]; then
				pdcp -w $VMHOST $CFGDIR/zk.config $REMOTE_ROOT
			fi
		fi
	fi
done
echo "The deployment script for all VM Hosts are ready"
for vhost in `cat $CFGDIR/vhost.lst`
do
	pdsh -w $vhost "cd /var/lib/rapids/cfg/clusters/$CLUSTER; ./install_container.cmd"
done
