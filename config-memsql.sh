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
MASTER=`cat ${CFGDIR}/memsql.cluster | grep master | cut -d: -f1`
#MASTER=192.168.10.86

for line in `cat $CFGDIR/memsql.cluster`
do
	IFS=: read HOST DSROLE NODE_COUNT <<< $line
	echo "host: $HOST, Role: $DSROLE, Node Count: $NODE_COUNT"
	if [[ $DSROLE == "master" ]]; then
		echo "Starting MemSQL master agent on $HOST ..."
		ssh $HOST "memsql-ops stop; memsql-ops start -h $HOST"
		AGENTID=`ssh $HOST "memsql-ops agent-list -r primary -q"`
		echo "Checking if master Memsql has been deployed ..."
		ssh $HOST "memsql-ops agent-list --memsql-role master -q"
		if (( $? == 1 )); then
			echo "Deploying master Memsql node on $HOST ..."
			ssh $HOST ifdown eth1
			ssh $HOST "memsql-ops memsql-deploy -r master -a $AGENTID --community-edition"
			if (( $? != 0 )); then
				echo "MemSQL Master deployment is failed, please fix and rerun this program."
				exit 1
			fi
			ssh $HOST ifup eth1
			echo "Master Memsql node deployment is finished."
		fi
	elif [[ $DSROLE == "leaf" ]]; then
		ssh $MASTER "memsql-ops agent-list | grep $HOST > /dev/null"
		if (( $? != 0 )); then
			echo "deploy MemSQL agent to $HOST ..."
            ssh $MASTER "cp /root/.ssh/id_rsa /tmp/id.tmp; chmod 660 /tmp/id.tmp"
            ssh $MASTER "memsql-ops agent-deploy -h $HOST --ops-datadir /opt/data_store/memsql_ops --memsql-installs-dir /opt/data_store/memsql_data -u root -i /tmp/id.tmp"
            if (( $? == 0 )); then
                echo "MemSQL agent is deployed on $HOST."
                ssh $MASTER "rm -rf /tmp/id.tmp"
            fi
		fi
		echo "deploy MemSQL leaf node to $HOST ..."
		AGENTID=`ssh $MASTER "memsql-ops agent-list | grep $HOST" | awk '{ print $1 }'`
		echo "AgentID: $AGENTID"
		i=1
		while (( $i <= $NODE_COUNT ))
		do
			echo "Deploy MemSQL leaf node on $HOST ..."
			PORT=`expr $i + 3305`
			ssh $MASTER "memsql-ops memsql-deploy -a $AGENTID -r leaf -P $PORT"
			echo "MemSQL node is deployed on $HOST:$PORT"
			i=`expr $i + 1`
		done
	else
		echo "The provided role $DSROLE is not recognized."
		exit 1
	fi
done 

ssh $MASTER "memsql-ops memsql-list"
echo "Data store: MemSQL configuration is finished now."
