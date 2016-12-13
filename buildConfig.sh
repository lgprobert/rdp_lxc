#!/bin/sh
usage() {
  echo "usage: $0 -f <csv_format_config_file> -n <applicant_name> [-s <start_date>] -e <end_date>"  
}


if (( $# < 6 )); then
	echo "The number of options is not correct!"
	usage
	exit
fi
START_DATE=`date "+%Y/%m/%d"`

while getopts ":f:n:s:e:" opt_char
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

if [[ ! (-e /root/cfg/clusters && -d /root/cfg/clusters) ]]; then
	mkdir -p /root/cfg/clusters
else
	CFG_ROOT="/root/cfg/clusters"
fi

# Form the cluster name by extracting first name from applicant name (must be in email form) with 
# strimlined date value
CLUSTER=`echo $APPLICANT | cut -d@ -f1`-`date -d $START_DATE +%y%m%d`_`date -d $END_DATE +%y%m%d`
echo "CLUSTER name: $CLUSTER"
CFG_ROOT=$CFG_ROOT/$CLUSTER
mkdir -p $CFG_ROOT
cp $CSV_FILE $CFG_ROOT
echo "Cluster name: $CLUSTER" > $CFG_ROOT/cluster.info
echo "Applicant name: $APPLICANT" >> $CFG_ROOT/cluster.info
echo "Requested resources: " >> $CFG_ROOT/cluster.info
cat $CSV_FILE >> $CFG_ROOT/cluster.info
echo
echo "Expected start date: $START_DATE" >> $CFG_ROOT/cluster.info
echo "Planned end date: $END_DATE" >> $CFG_ROOT/cluster.info


find $CFG_ROOT -type f \( -name cluster.cfg -o -name hosts -o -name rdp.cluster -o -name memsql.cluster -o -name voltdb.cluster -o -name *cmd \) -exec rm {} +  

echo "127.0.0.1   localhost localhost.localdomain" > $CFG_ROOT/hosts

while IFS=, read HOST IP MASK CPU MEM RDPROLE DS DSROLE VHOST
do
	echo "$IP $HOST" >> $CFG_ROOT/hosts
	VCPU=`expr $CPU \* 100`
	echo "$HOST,$IP,$MASK,$VCPU,$MEM,$VHOST" >> $CFG_ROOT/cluster.cfg
	if [[ -e $CFG_ROOT/vhost.lst ]]; then 
		grep $VHOST $CFG_ROOT/vhost.lst > /dev/null
		if (( $? != 0 )); then
			echo $VHOST >> $CFG_ROOT/vhost.lst
		fi
	else
		echo $VHOST >> $CFG_ROOT/vhost.lst
	fi
	if [[ $RDPROLE != "none" ]]; then
		echo $HOST:$RDPROLE >> $CFG_ROOT/rdp.cluster
	fi
	if [[ $DS != "no" ]]; then
		if [[ $DS == "memsql" ]]; then
			echo $HOST:$DSROLE >> $CFG_ROOT/memsql.cluster
		elif [[ $DS == "voltdb" ]]; then
		    echo $HOST:$DSROLE >> $CFG_ROOT/voltdb.cluster
		fi
	fi
done < $CSV_FILE
