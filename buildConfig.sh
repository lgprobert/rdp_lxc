#!/bin/sh
usage() {
  echo "usage: $0 -f <csv_format_config_file> -n <applicant_name> [-s <start_date>] -e <end_date> -t <rapidsdb|memsql|centos>"  
}


if (( $# < 6 )); then
	echo "The number of options is not correct!"
	usage
	exit
fi
START_DATE=`date "+%Y/%m/%d"`
CFGROOT="/var/lib/rapids/cfg/clusters"

while getopts ":f:n:s:e:t:" opt_char
do
    case $opt_char in
        f)
            CSV_FILE=$OPTARG
            ;;	
		n) 
			APPLICANT=$OPTARG
			;;
		s) 
			START_DATE=$OPTARG
			;;
		e) 
			END_DATE=$OPTARG
			;;
        t)
            CLUSTER_TYPE=$OPTARG
            ;;
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

date -d $START_DATE > /dev/null 2>&1
CHECK_STARTDATE=$?
date -d $END_DATE > /dev/null 2>&1
CHECK_ENDDATE=$?
if (( $CHECK_STARTDATE == 1 || CHECK_ENDDATE == 1 )); then
	echo "Provided date value is not in valid date format, valid format are like: 2016/1/30 or 1/30/2016."
	exit
fi

if [[ ! (-e $CFGROOT && -d $CFGROOT) ]]; then
    mkdir -p $CFGROOT
fi


# Form the cluster name by extracting first name from applicant name (must be in email form) with strimlined date value
RANDOMID=`cat /dev/urandom | tr -dc 0-9 | head -c 6`

echo $APPLICANT | grep '@' > /dev/null
if (( $? == 1 )); then
	echo "Error: the applicant's name must be a valide email address."
	exit 1
else
	CLUSTER=`echo $APPLICANT | cut -d@ -f1`${RANDOMID}
fi
CFGDIR=$CFGROOT/$CLUSTER

# Determine cluster type
case "$CLUSTER_TYPE" in 
	rapidsdb|memsql|centos)
		if [[ $CLUSTER_TYPE == 'rapidsdb' ]]; then
			grep dqc cluster.csv > /dev/null
			if (( $? == 1 )); then
				echo "You must assign at least one DQC node in a RapidsDB cluster."
				exit 1
			fi
		elif [[ $CLUSTER_TYPE == 'memsql' ]]; then
			grep master cluster.csv > /dev/null
            if (( $? == 1 )); then
                echo "You must assign one master node in a MemSQL cluster." 
				exit 1
            fi
		fi
		mkdir -p $CFGDIR
		echo $CLUSTER_TYPE > $CFGDIR/cluster.type
		;;
	*)
		echo "Error: the provided cluster value is not recognized."
		exit 1
		;;
esac


echo "CLUSTER name: $CLUSTER"
cp $CSV_FILE $CFGDIR
echo "Cluster name: $CLUSTER" > $CFGDIR/cluster.info
echo "Applicant name: $APPLICANT" >> $CFGDIR/cluster.info
echo "Requested resources: " >> $CFGDIR/cluster.info
cat $CSV_FILE >> $CFGDIR/cluster.info
echo
echo "Expected start date: $START_DATE" >> $CFGDIR/cluster.info
echo "Planned end date: $END_DATE" >> $CFGDIR/cluster.info


find $CFGDIR -type f \( -name cluster.cfg -o -name hosts -o -name rdp.cluster -o -name memsql.cluster -o -name voltdb.cluster -o -name *cmd \) -exec rm {} +  

echo "127.0.0.1   localhost localhost.localdomain" > $CFGDIR/hosts

while IFS=, read HOST IP MASK CPU MEM RDPROLE DS DSROLE VHOST
do
	echo "$IP $HOST" >> $CFGDIR/hosts
	VCPU=`expr $CPU \* 100`
	echo "$HOST,$IP,$MASK,$VCPU,$MEM,$VHOST" >> $CFGDIR/cluster.cfg
	if [[ -e $CFGDIR/vhost.lst ]]; then 
		grep $VHOST $CFGDIR/vhost.lst > /dev/null
		if (( $? != 0 )); then
			echo $VHOST >> $CFGDIR/vhost.lst
		fi
	else
		echo $VHOST >> $CFGDIR/vhost.lst
	fi
	if [[ $RDPROLE != "none" ]]; then
		echo $IP:$RDPROLE >> $CFGDIR/rdp.cluster
	fi
	if [[ $DS != "no" ]]; then
		if [[ $DS == "memsql" ]]; then
			echo $IP:$DSROLE >> $CFGDIR/memsql.cluster
		elif [[ $DS == "voltdb" ]]; then
		    echo $IP:$DSROLE >> $CFGDIR/voltdb.cluster
		fi
	fi
done < $CSV_FILE

echo "Cluster cofniguration is generated."
