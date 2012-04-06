#!/bin/bash
. /etc/rc.conf
. /etc/rc.d/functions
. /etc/asd.conf

case "$1" in
	start)
		stat_busy 'Starting Anything-Sync-Daemon'
		
		if [[ -f /run/daemons/asd ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is already running!"
			stat_fail && exit 1
		fi
		/usr/bin/anything-sync-daemon check
		add_daemon asd
		/usr/bin/anything-sync-daemon sync
		stat_done
		;;
	stop)
		stat_busy 'Stopping Anything-Sync-Daemon'
		if [[ ! -f /run/daemons/asd ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is not running, nothing to stop!"
			stat_fail
		else
			/usr/bin/anything-sync-daemon sync && /usr/bin/anything-sync-daemon unsync
			rm_daemon asd
			stat_done
		fi
		;;
	sync)
		stat_busy 'Syncing tmpfs to physical disc'
		if [[ ! -f /run/daemons/asd ]]; then
			printf "\n${C_FAIL}Error:${C_CLEAR} Anything-Sync-Daemon is not running... cannot sync!"
			stat_fail
		else
			/usr/bin/anything-sync-daemon sync
			stat_done
		fi
		;;	
	restart)
		# restart really has no meaning in the traditional sense
		stat_busy 'Syncing tmpfs to physical disc'
		if [[ ! -f /run/daemons/asd ]]; then
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
