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
CFGROOT="/var/lib/rapidsdb/cfg/clusters"

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

if [[ ! (-e $CFGROOT && -d $CFGROOT) ]]; then
	mkdir -p $CFGROOT
fi

# Form the cluster name by extracting first name from applicant name (must be in email form) with 
# strimlined date value
RANDOMID=`cat /dev/urandom | tr -dc 0-9 | head -c 6`
#CLUSTER=`echo $APPLICANT | cut -d@ -f1`-`date -d $START_DATE +%y%m%d`_`date -d $END_DATE +%y%m%d`
CLUSTER=`echo $APPLICANT | cut -d@ -f1`${RANDOMID}
echo "CLUSTER name: $CLUSTER"
CFGDIR=$CFGROOT/$CLUSTER
mkdir -p $CFGDIR
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
