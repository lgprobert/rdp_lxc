#!/bin/sh

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
esac

