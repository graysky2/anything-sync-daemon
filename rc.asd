#!/bin/bash
. /etc/rc.conf
. /etc/rc.d/functions
. /etc/asd.conf

export DAEMON_FILE=/run/daemons/asd

case "$1" in
	start)
		if [[ -f $DAEMON_FILE ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is already running!"
			stat_fail && exit 1
		fi
		/usr/bin/anything-sync-daemon check
		add_daemon psd
		/usr/bin/anything-sync-daemon sync
		stat_done
		;;
	stop)
		stat_busy 'Stopping Anything-Sync-Daemon'
		if [[ ! -f $DAEMON_FILE ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is not running, nothing to stop!"
			stat_fail
		else
			/usr/bin/anything-sync-daemon unsync
			rm_daemon psd
			stat_done
		fi
		;;
	sync)
		stat_busy 'Syncing browser profiles in tmpfs to physical disc'
		if [[ ! -f $DAEMON_FILE ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is not running... cannot sync!"
			stat_fail
		else
			/usr/bin/anything-sync-daemon sync
			stat_done
		fi
		;;
	restart)
		# restart really has no meaning in the traditional sense
		stat_busy 'Syncing browser profiles in tmpfs to physical disc'
		if [[ ! -f $DAEMON_FILE ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is not running... cannot sync!"
			stat_fail
		else
			/usr/bin/anything-sync-daemon sync
			stat_done
		fi
		;;
	*)
		echo "usage $0 {start|stop|sync}"
esac
exit 0

