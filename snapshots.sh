#!/bin/bash
# Creates snapshots from specific subvolumes
# Author: Wanderley Silva
# A simples script that will create snapshots for given subvolumes

path=/mnt/data
snapshot_path=/mnt/data/.snapshots
volumes="nextcloud nextclouddb emby"

for vol in ${volumes}; do
	echo "Creating snapshot for: ${vol}"
	btrfs sub snap -r ${path}/${vol} ${snapshot_path}/${vol}_$(date +%F)
	echo
done
