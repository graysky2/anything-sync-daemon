#!/bin/bash
. /etc/rc.conf
. /etc/rc.d/functions
. /etc/asd.conf

export DAEMON_FILE=/run/asd

case "$1" in
	start)
		stat_busy 'Starting Anything-Sync-Daemon'
		add_daemon asd
		/usr/bin/anything-sync-daemon sync
		stat_done
		;;
	stop)
		stat_busy 'Stopping Anything-Sync-Daemon'
		/usr/bin/anything-sync-daemon unsync
		rm_daemon asd
		stat_done
		;;
	*)
		echo "usage $0 {start|stop}"
		;;
esac
exit 0
