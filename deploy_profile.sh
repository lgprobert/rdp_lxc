#!/bin/sh

TEMPLATE_DIR="template"

for host in "$@"
do
	cp $TEMPLATE/root_profile /container/$host/rootfs/root/.bash_profile
	cp $TEMPLATE/root_bashrc /container/$host/rootfs/root/.bashrc
	\cp $TEMPLATE/rapids_profile /container/$host/rootfs/home/rapids/.bash_profile
	\cp $TEMPLATE/rapids_bashrc /container/$host/rootfs/home/rapids/.bashrc
	chown 1000:1000 /container/$host/rootfs/home/rapids
done
