#!/bin/sh
usage() {
  echo "usage: $0 -d <cluster_name>"
}

if (( $# < 2 )); then
        echo "You must provide the cluster name."
        usage
        exit
fi

while getopts ":d:" opt_char
do
    case $opt_char in
        d)  
            CFGDIR=/root/cfg/clusters/$OPTARG
            ;;  
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done

CLUSTER=`basename $CFGDIR`
MASTER=`cat ${CFGDIR}/memsql.cluster | grep master | cut -d: -f1`

while IFS=: read HOST DSROLE NODE_COUNT
do
	echo "host: $HOST, Role: $DSROLE, Node Count: $NODE_COUNT"
	if [[ $DSROLE == "primary" ]]; then
		echo "Starting MemSQL master agent on $HOST ..."
		ssh $HOST "memsql-ops start -h $HOST"
		AGENTID=`ssh $HOST "memsql-ops agent-list --memsql-role master -q"`
		echo "Deploying master Memsql node on $HOST ..."
		ssh $HOST "memsql-ops memsql-deploy -r master -a $AGENTID --community-edition"
		if (( $? != 0 )); then
			echo "MemSQL Master deployment is failed, please fix and rerun this program."
			exit 1
		fi
		echo "Master Memsql node deployment is finished."
	elif [[ $DSROLE == "leaf" ]]; then
		ssh $HOST "memsql-ops agent-list | grep $HOST > /dev/null"
		if (( $? != 0 )); then
            ssh $MASTER "cp /root/.ssh/id_rsa /tmp/id.tmp; chmod 660 /tmp/id.tmp"
            ssh $MASTER "memsql-ops agent-deploy -h $HOST --ops-datadir /opt/data_store/memsql_ops -
-memsql-installs-dir /opt/data_store/memsql_data -u root -i /tmp/id.tmp"
            if (( $? == 0 )); then
                echo "MemSQL agent is deployed on $HOST."
                ssh $MASTER "rm -rf /tmp/id.tmp"
            fi
		fi
		AGENTID=`ssh $MASTER "memsql-ops agent-list | grep dqe1 | awk '{ print $1 }'"`
		i=1
		while (( $i <= $NODE_COUNT ))
		do
			echo "Deploy MemSQL leaf node on $HOST ..."
			PORT=`expr $i + 3305`
			ssh $MASTER "memsql-ops memsql-deploy -a $AGENTID -r leaf -P $PORT"
			echo "MemSQL node is deployed on $HOST:$PORT"
			i = `expr $i + 1`
		done
	else
		echo "The provided role $DSROLE is not recognized."
		exit 1
	fi
done < $CFGDIR/memsql.cluster

ssh $MASTER "memsql-ops memsql-list"
echo "Data store: MemSQL configuration is finished now."
