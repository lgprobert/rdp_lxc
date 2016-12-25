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
DQC=`cat ${CFGDIR}/rdp.cluster | grep dqc | cut -d: -f1`

cd $CFGDIR
while IFS=: read HOST ROLE 
do
	echo "Transfering RapidsDB cluster configuration files to target conatiner: $HOST"
	pdcp -w $HOST -l rapids zk.config cluster.config /opt/rdp/current/cfg
done < rdp.cluster 

echo "Starting Zookeeper service ..."
ssh rapids@$DQC "cd /opt/zookeeper/bin; ./zkServer.sh start"
echo "Populate RapidsDB configuration to Zookeeper ..."
ssh rapids@$DQC "cd /opt/rdp/current; ./bootstrapper.sh -a populate"
echo "Starting RapidsDB service ..."
ssh rapids@$DQC "cd /opt/rdp/current; ./bootstrapper.sh -a start"
echo "RapidsDB configuration is finished."
