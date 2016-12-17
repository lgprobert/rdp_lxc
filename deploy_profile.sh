#!/bin/sh

for host in "$@"
do
	cp root_profile /container/$host/rootfs/root/.bash_profile
	cp root_bashrc /container/$host/rootfs/root/.bashrc
	\cp rapids_profile /container/$host/rootfs/home/rapids/.bash_profile
	\cp rapids_bashrc /container/$host/rootfs/home/rapids/.bashrc
	chown 1000:1000 /container/$host/rootfs/home/rapids
done
