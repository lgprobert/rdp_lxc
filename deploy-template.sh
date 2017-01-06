#!/bin/sh 
usage() {
	  echo "usage: $0 -n <container_template_name> -s <template_source_host> -d <destination_host>"
  } 

while getopts ":n:s:d:h" opt_char
do
    case $opt_char in
        n)
            TEMPLATE=$OPTARG
            ;;
        s)  
            SRCHOST=$OPTARG
            ;;  
		d)
			DESTHOST=$OPTARG
			;;
        \h)
            usage
            exit 0
            ;;
        \?)
            echo "$OPTARG is not a valid option."
            usage
            exit
            ;;
    esac
done
if (( $# < 2 )); then
	echo "Error: there is no command options provided."
    usage
    exit 1
fi

echo
echo "Copying template $TEMPLATE from $SRCHOST to $DESTHOST"
ssh $SRCHOST "zfs snapshot zfspool/lxc/$TEMPLATE@backup"
echo "List snapshot: `ssh $SRCHOST zfs list -t snapshot`"
ssh $SRCHOST "zfs send zfspool/lxc/$TEMPLATE@backup | ssh $DESTHOST zfs receive zfspool/lxc/$TEMPLATE"
ssh $DESTHOST "zfs set mountpoint=/container/$TEMPLATE/rootfs zfspool/lxc/$TEMPLATE"
scp $SRCHOST:/container/$TEMPLATE/config $DESTHOST:/container/$TEMPLATE
ssh $SRCHOST "zfs destroy zfspool/lxc/$TEMPLATE@backup"

echo "The deployment of template $TEMPLATE from $SRCHOST to $DESTHOST is finished."
