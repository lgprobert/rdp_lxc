#!/bin/sh
usage() {
	echo "usage: $0 start|stop|destroy|help container1 container2 ... containerN"
  }

case $1 in
	start)
		for node in "${@:2}"
		do
			echo "Starting $node"
			lxc-start -n $node
		done
		echo "All started"
		;;
	stop)
		for node in "${@:2}"
        do  
			echo "Stopping $node ..."
            lxc-stop -n $node
        done
		echo "All stopped"
        ;;
	destroy)
		for node in "${@:2}"
        do  
			echo "Destroying $node ..."
			lxc-stop -n $node
            lxc-destroy -n $node
            shift
        done
		echo "All destroyed"
        ;;
	help)
		usage
		exit 0
		;;
	*)
		echo "Error: Wrong command option"
		exit 1
		;;
esac

