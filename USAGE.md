% anything-sync-daemon(1)

# NAME

**anything-sync-daemon** - Symlinks and syncs user specified dirs to RAM thus
reducing HDD/SDD calls and speeding-up the system.

# DESCRIPTION

Anything-sync-daemon (asd) is a tiny pseudo-daemon designed to manage user
specified directories referred to as sync targets from here on out, in tmpfs
and to periodically sync them back to the physical disc (HDD/SSD). This is
accomplished via a bind mounting step and an innovative use of rsync to
maintain synchronization between a tmpfs copy and media-bound backups.
Additionally, asd features several crash-recovery features.

Design goals of asd:

- Completely transparent user experience.
- Reduced wear to physical discs (particularly SSDs).
- Speed.

Since the sync targets is relocated into tmpfs (RAM disk), the corresponding
onslaught of I/O associated with system usage of them is also redirected from
the physical disc to RAM, thus reducing wear to the physical disc and also
improving speed and responsiveness.

# SETUP

`/etc/asd.conf` contains all user managed settings. Optionally another file can
be used by setting the `ASDCONF` environment variable.

**NOTE**: edits made to `/etc/asd.conf` while `asd` is running will be applied
only after `asd` has been restarted from the init service.

- At a minimum, define the sync targets to be managed by asd in the
  `WHATTOSYNC` array. Syntax below.
- Optionally uncomment and define the location of your distro's tmpfs* in the
  `VOLATILE` variable.
- Optionally enable the use of overlayfs to improve sync speed even further and
  use a smaller memory footprint. Do this in the `USE_OVERLAYFS` variable. Note
  that this option requires your kernel to be configured to use either the
  'overlay' or 'overlayfs' module. See the FAQ below for additional details on
  this feature.
- Optionally disable the use of crash-recovery snapshots. Do this in the
  `USE_BACKUPS` variable.
- Optionally define the number of crash-recovery snapshots to keep. Do this in
  the `BACKUP_LIMIT` variable.

**NOTE** that the default value of `/tmp` should work just fine for the
`VOLATILE` setting. If using bleachbit, do NOT invoke it with the `--clean
system.tmp` switch or you will remove a key dot file (`.foo`) from `/tmp` that
asd needs to keep track of sync status. Also note that using a value of
`/dev/shm` can cause problems with systemd's `NAMESPACE` spawning only when
users enable the overlayfs option.

Example:

```bash
WHATTOSYNC=('/var/lib/monitorix' '/srv/http' '/foo/bar')
```

or

```bash
WHATTOSYNC=(
  '/var/lib/monitorix'
  '/srv/http'
  '/foo/bar'
)
```

# RUNNING ASD

## PREVIEW MODE

The preview option can be called to show users exactly what asd will do/is
doing based on the entries in /etc/asd.conf as well printout useful information
such as dir size, paths, and if any recovery snapshots have been created.

```shell-session
$ asd p

Anything-sync-daemon on Arch Linux.

Systemd service is currently active.
Systemd resync service is currently active.
Overlayfs v23 is currently active.

Asd will manage the following per /run/asd.conf settings:

owner/group id:     root/0
target to manage:   /srv/http/serve
sync target:        /srv/http/.serve-backup_asd
tmpfs target:       /tmp/asd-root/srv/http/serve
dir size:           21M
overlayfs size:     15M
recovery dirs:      2 <- delete with the c option
 dir path/size:     /srv/http/.serve-backup_asd-crashrecovery-20141105_124948 (17M)
 dir path/size:     /srv/http/.serve-backup_asd-crashrecovery-20150124_062311 (21M)

owner/group id:     facade/100
target to manage:   /home/facade/logs
sync target:        /home/facade/.logs-backup_asd
tmpfs target:       /tmp/asd-facadey/home/facade/logs
dir size:           1.5M
overlayfs size:     480K
recovery dirs:      none
```

## CLEAN MODE

The clean mode will delete **ALL** recovery snapshots that have accumulated.
Run this only if you are sure that you want to delete them.

Note that if a sync target is owned by root or another user, and if you call
`asd` to clean, it will throw errors based on the permissions of your sync
targets.

```shell-session
$ asd c

Anything-sync-daemon on Arch Linux.

Deleting 2 crashrecovery dirs for sync target /srv/http/serve
 /srv/http/.serve-backup_asd-crashrecovery-20141105_124948
 /srv/http/.serve-backup_asd-crashrecovery-20150124_062311
```

## START AND STOP ASD FOR SYSTEMD USERS

Both a systemd service file and timer are provided, and should be used to start
or stop asd.

The role of the timer is update the tmpfs copies back to the disk. This occurs
once per hour by default. The timer is started automatically with
`asd.service`.

```shell-session
# systemctl [option] asd
```

Available options:

- `start`
- `stop`
- `enable`
- `disable`

## START AND STOP ASD FOR USERS OF OTHER INIT SYSTEMS

For distros not using systemd, another init script should be used to manage the
daemon. Examples are provided and are known to work with Upstart.

Note that for these init systems, the supplied cron script (installed to
`/etc/cron.hourly`) will run the resync option to keep the tmpfs copies
sync'ed.  Of course, the target system must have cron installed and active for
this to happen.

# SUPPORTED DISTROS

At this time, the following distros are officially supported but there is no
reason to think that `asd` will not run on another distro:

- Arch Linux

# FAQ

Q1: What is overlayfs mode?

A1: Overlayfs is a simple union file-system mainlined in the Linux kernel
version 3.18.0. Starting with asd version 5.54, overlayfs can be used to reduce
the memory footprint of asd's tmpfs space and to speed up sync and unsync
operations. The magic is in how the overlay mount only writes out data that has
changed rather than the entire sync target. See Example 1 below. The same
recovery features asd uses in its default mode are also active when running in
overlayfs mode. Overlayfs mode is enabled by uncommenting the USE_OVERLAYFS= in
/etc/asd.conf followed by a restart of the daemon.

There are several versions of overlayfs available to the Linux kernel in
production in various distros. Versions 22 and lower have a module called
'overlayfs' while newer versions (23 and higher) have a module called 'overlay'
-- note the lack of the 'fs' in the newer version. Asd will automatically
detect the overlayfs available to your kernel if it is configured to use one of
them.

See the example in the PREVIEW MODE section above which shows a system using
overlayfs to illustrate the memory savings that can be achieved. Note the
"overlayfs size" report compared to the total "dir size" report for each sync
target. Be aware that these numbers will change depending on just how much data
is written to the sync target, but in common use cases, the overlayfs size will
always be less than the dir size.

Q2: Why do I see directory ".foo-backup_asd" ".foo-backup_asd-old"?

A2: The way the backup process of asd works is that it creates a hard linked
clone of the original directory; this is known as .foo-backup_asd-old. The
other .foo-backup_asd is just a bind mount to the original directory link which
is used to access the contents of the original directory for overlay purposes.

Q3: My system crashed and asd didn't sync back. What do I do?

A3: The "last good" backup of your sync targets is just fine still sitting
happily on your filesystem. Upon restarting asd (on a reboot for example), a
check is preformed to see if asd was exited in some corrupted state. If it is
detected, asd will snapshot the "last good" backup before it rotates it back
into place. Note that, since asd tries to decrease the disk usage, it never
really "copies" the full contents of the directory and just uses the hardlinks
to the previous files. And during the rsync step, it creates new files so that
the previous hardlinks are untouched. So trying to modify the directory during
the time asd is trying to backup can leave the directory in some corrupted
state.

Q4: Where can I find this snapshot?

A4: You will find the snapshot in the same directory as the sync target and it
will contain a date-time-stamp that corresponds to the time at which the
recovery took place. For example, a /foo/bar snapshot will be
/foo/.bar-backup_asd-crashrecovery-20141221_070112.tar.zstd -- of course, the
date_time suffix will be different for you.

Q5: How can I restore the snapshot?

A5: Follow these steps:

1. Stop asd.
2. Confirm that the directories created by asd is not present. If they are, asd
   did not stop correctly for other reasons.
3. Move the "bad" copy of the sync taget to a backup (don't blindly delete
   anything).
4. Untar the snapshot directory to the expected sync target.

Example using `/foo/bar` under systemd:

1. `systemctl stop asd.service`
2. `cd /foo`
3. `mv bar bar-bad`
4. `tar -xvf .bar-backup_asd-crashrecovery-20141221_070112.tar.zstd`

At this point, check that everything is fine with the data on /foo/bar and, if
all is well, it is safe to delete the snapshot.

Q6: Can asd delete the snapshots automatically?

A6: Yes, run asd with the "clean" switch to delete snapshots.

# CONTRIBUTE

Users wishing to contribute to this code, should fork and send a pull request.
Source is freely available on the project page linked below.

# BUGS

Discover a bug? Please open an issue on the project page linked below.

- Currently, asd cannot handle open files on a sync target so if a hung process
  has something open there, it can be messy.

# ONLINE

- Project page: https://github.com/graysky2/anything-sync-daemon
- Wiki page: https://wiki.archlinux.org/index.php/Anything-sync-daemon

# AUTHOR

graysky (graysky AT archlinux DOT us)

# MAINTAINER

Manorit Chawdhry (manorit2001@gmail.com)
