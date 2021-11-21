#!/bin/bash
set -eo pipefail
shopt -s nullglob

# logging functions
pbs_log() {
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}
pbs_note() {
	pbs_log Note "$@"
}
pbs_warn() {
	pbs_log Warn "$@" >&2
}
pbs_error() {
	pbs_log ERROR "$@" >&2
	exit 1
}

# Verify that the minimally required password settings are set for new databases.
docker_verify_minimum_env() {
	if [ -z "$ADMIN_PASSWORD" ]; then
		pbs_error $'Password option is not specified\n\tYou need to specify one of ADMIN_PASSWORD'
	fi
}

import_ca() {
        if [ -n "$IMPORT_CA" ]; then
		update-ca-certificates
	fi
}

# Loads various settings that are used elsewhere in the script
docker_setup_env() {
    declare -g USERS_ALREADY_EXISTS
	if [ -f "/etc/proxmox-backup/user.cfg" ]; then
		USERS_ALREADY_EXISTS='true'
	fi
}

docker_setup_pbs() {
    #Set pbs user
    proxmox-backup-manager user update root@pam --enable 0
    proxmox-backup-manager user create admin@pbs
    proxmox-backup-manager user update admin@pbs --password $ADMIN_PASSWORD
    proxmox-backup-manager acl update /datastore Admin --auth-id admin@pbs
    proxmox-backup-manager acl update /remote Admin --auth-id admin@pbs
    proxmox-backup-manager acl update /system/disks Audit --auth-id admin@pbs
    proxmox-backup-manager acl update /system/log Admin --auth-id admin@pbs
    proxmox-backup-manager acl update /system/network Audit --auth-id admin@pbs
    proxmox-backup-manager acl update /system/services Audit --auth-id admin@pbs
    proxmox-backup-manager acl update /system/status Audit --auth-id admin@pbs
    proxmox-backup-manager acl update /system/tasks Admin --auth-id admin@pbs
    proxmox-backup-manager acl update /system/time Audit --auth-id admin@pbs

    #Set pbs default store
    proxmox-backup-manager datastore create Store1 /backup/store1
}

docker_verify_minimum_env
import_ca

# Start api first in background
/usr/lib/x86_64-linux-gnu/proxmox-backup/proxmox-backup-api &
sleep 10

docker_setup_env

# there's no user setup, so it needs to be initialized
if [ -z "$USERS_ALREADY_EXISTS" ]; then
    docker_setup_pbs
fi

exec gosu backup /usr/lib/x86_64-linux-gnu/proxmox-backup/proxmox-backup-proxy "$@"

