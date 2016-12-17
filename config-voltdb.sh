#!/bin/sh
usage() {
  echo "usage: $0 -n <cluster_name>"
}

if (( $# < 2 )); then
        echo "You must provide the cluster name."
        usage
        exit
fi

while getopts ":n:" opt_char
do
    case $opt_char in
        n)  
            CFGDIR=/var/lib/rapids/cfg/clusters/$OPTARG
            ;;  
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

CLUSTER=`basename $CFGDIR`
grep master $CFGDIR/voltdb.cluster > /dev/null 
if (( $? == 1 )); then
	echo "Error: VoltDB should have a master node." 
	exit 1
else
	MASTER=`grep master $CFGDIR/voltdb.cluster | cut -d: -f1`
fi
sed "s/MASTER/'"$MASTER"'/" startds.sh.sample > startds.sh
HOSTQTY=`wc -l $CFGDIR/voltdb.cluster | awk '{print $1}'`
sed 's/HOSTCOUNT/'"${HOSTQTY}"'/' deploy.xml.sample > deploy.xml

mv deploy.xml $CFGDIR
mv startds.sh $CFGDIR

# stop any running Voltdb instances if possible
echo "Clean up target environment"
for line in `cat $CFGDIR/voltdb.cluster`
do
    IFS=: read HOST ROLE <<< $line
	ssh rapids@$HOST 'jps | grep VoltDB | grep -v grep | awk "{print $1}" | xargs kill > /dev/null 2>&1'
done

while IFS=: read HOST ROLE 
do
	echo "host: $HOST, Role: $DSROLE"
	echo "Transfer configuration data to: $HOST"
	pdcp -w $HOST -l rapids $CFGDIR/deploy.xml $CFGDIR/startds.sh /home/rapids/scripts
done < $CFGDIR/voltdb.cluster

echo "Starting  Voltdb service on master node $MASTER ..."
ssh rapids@$MASTER "cd /home/rapids/scripts; ./startds.sh > msg.out 2>&1"
sleep 3
ssh rapids@$MASTER "jps | grep VoltDB > /dev/null"
if (( $? != 0 )); then
    echo "Error: VoltDB start is failed, please check."
    exit 1
else
    echo "VoltDB master node is started."
fi  

for line in `cat $CFGDIR/voltdb.cluster`
do
	IFS=: read HOST ROLE <<< $line
	if [[ $HOST != $MASTER ]]; then
		echo "Starting Voltdb service on node $HOST ..."
		ssh rapids@$HOST "cd /home/rapids/scripts; ./startds.sh> msg.out 2>&1"
		sleep 3
		ssh rapids@$HOST "jps | grep VoltDB > /dev/null"
		if (( $? != 0 )); then
			echo "Error: VoltDB start is failed, please check."
			exit 1
		else
			echo "VoltDB worker node is started."
		fi
	fi
done 

echo "VoltDB data store service configuration is finished."
