#!/bin/bash
# Incremental backup using btrfs send | receive
# Author: Wanderley Silva
#
# This simple script will create a snapshot for a given btrfs subvolme and
# creates a backup for a given path.
# If a base snapshot already exists a new one will be created and an incremental backup will be taken.
# In this scenario, all previous snapshots will be erased and the latest one will be set as the current.

echo "Starting backup..."
subvols='nextclouddb nextcloud emby'
#subvols='emby'
source_dir=/mnt/data
snapshots_dir=/mnt/data/.snapshots
backup_dir=/mnt/backup
is_incremental_backup=0

create_snapshot() {
	# Creates the snapshots.
	echo "Creating snapshot..."
	echo "${source_dir}/$1"
	source_subvol=${source_dir}/$1

	if [[ -d ${snapshots_dir}/$1 && -d ${snapshots_dir}/$1_$(date +%F) ]]; then
		echo "Snapshot ${snapshots_dir}/$1_$(date +%F) already exists. Doing nothing here!" 
	elif [ -d ${snapshots_dir}/$1 ]; then
	        snapshot=${snapshots_dir}/$1_$(date +%F)
		btrfs subvol snap -r ${source_subvol} ${snapshot}
	else
	        snapshot=${snapshots_dir}/$1
		btrfs subvol snap -r ${source_subvol} ${snapshot}
	fi
}

create_backup() {
	# Case a base snapshot already exists, an incremental backup will e taken
	# by comparing the old snapshot with the latest one.
	snapshot=${snapshots_dir}/$1
	newer_snapshot=${snapshots_dir}/$1_$(date +%F)

	if [[ -d ${snapshot}  &&  -d ${newer_snapshot} ]]; then
		if [ -d ${backup_dir}/$1/$1_$(date +%F) ]; then
			echo "Backup already exists. Skiping ${newer_snapshot}"
		else
			echo "Using Parent for backup"
			btrfs send -p ${snapshot} ${newer_snapshot} | \
				btrfs receive ${backup_dir}/$1 
			is_incremental_backup=1
		fi
	else
		echo "No previous snapshots, using: ${snapshot}"
		btrfs send ${snapshot} | \
			btrfs receive ${backup_dir}/$1
	fi
}

update_snapshot() {
	# If an incremental backup has been taken, the old snapshot will be discarded
	# and the latest one will be renamed.
	echo "Updating snapshot to the latest version ..."
	latest_snapshot=${snapshots_dir}/$1_$(date +%F)
	btrfs subvol delete ${snapshots_dir}/$1
	mv ${latest_snapshot} ${snapshots_dir}/$1
}
clear_old_snapshots() {
	# If an incremental backup has been taken, the all previoues snapshots will be discarded
	# this is useful when running this progam on a weekly or monthly basis, for example
	ls ${snapshots_dir}/$1_* 2>/dev/null
	if [ $? == 0 ]; then
	        echo "Removing old snapshots"
		btrfs subvol delete ${snapshots_dir}/$1_*
	fi
}

for subvol in ${subvols}; do
	create_snapshot ${subvol}
	create_backup ${subvol}
	if [ ${is_incremental_backup} == 1 ]; then
		update_snapshot ${subvol}
		clear_old_snapshots ${subvol}
	fi
done

