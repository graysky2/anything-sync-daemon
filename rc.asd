#!/bin/bash
. /etc/rc.conf
. /etc/rc.d/functions
. /etc/asd.conf

sanity() {
	stat_busy 'Checking configuration'
	if [[ -z "${WHATTOSYNC[0]}" ]]; then
		stat_append '(Must define at least one directory in /etc/asd.conf)'
		stat_die
	fi

	if [[ ! -d "$TMPFS" ]]; then
		stat_append '(I cannot read $TMPFS which is defined in /etc/asd.conf)'
		stat_die
	fi
	stat_done
}

start() {
	stat_busy 'Starting Anything-Sync-Daemon'
	if [[ -f /run/daemons/asd ]]; then
		stat_append '(Anything-Sync-Daemon is already started.)'
		stat_die
	else
		/usr/bin/anything-sync-daemon check	# fix an ungraceful exit
		add_daemon asd
		/usr/bin/anything-sync-daemon sync
		stat_done
	fi
}

sync() {
	stat_busy 'Syncing tmpfs to physical disc'
	if [[ ! -f /run/daemons/asd ]]; then
		stat_append '(Anything-Sync-Daemon is not running... cannot sync.)'
		stat_fail
	else
		/usr/bin/anything-sync-daemon sync
		stat_done
	fi
}

stop() {
	stat_busy 'Stopping Anything-Sync-Daemon'
	if [[ ! -f /run/daemons/asd ]]; then
		stat_append '(Anything-Sync-Daemon has already been stopped.)'
		stat_die	# check if already stopped
	else
		/usr/bin/anything-sync-daemon sync
		/usr/bin/anything-sync-daemon unsync
		rm_daemon asd
		stat_done
	fi
}

case "$1" in
	start)
		sanity
		start
		;;
	stop)
		stop
		;;
	sync)
		sync
		;;	
	restart)
		# restart really has no meaning in the traditional sense
		sync
		;;
	*)
		echo "usage $0 {start|stop|sync}"
esac
exit 0
