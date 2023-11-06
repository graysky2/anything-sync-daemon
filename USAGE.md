% anything-sync-daemon(1)

[OverlayFS]: https://en.wikipedia.org/wiki/OverlayFS
[`rsync`]: https://github.com/WayneD/rsync
[BleachBit]: https://www.bleachbit.org/

# NAME

`anything-sync-daemon` - Symlinks and syncs user specified dirs to RAM thus
reducing HDD/SDD calls and speeding-up the system.

# DESCRIPTION

`anything-sync-daemon` (`asd`) is a tiny pseudo-daemon designed to manage
user-specified directories (referred to as "sync targets" from here on out) in
tmpfs and to periodically sync them back to the physical disc (HDD/SSD).  This
is accomplished via a bind-mounting step and an innovative use of [`rsync`][]
to maintain synchronization between a tmpfs copy and media-bound backups.
Additionally, `asd` features several crash-recovery features.

Design goals of `asd`:

- Completely transparent user experience.
- Reduced wear to physical discs (particularly SSDs).
- Speed.

Since sync targets are relocated into tmpfs (RAM disk), the corresponding
onslaught of I/O associated with their use by the system is redirected from the
physical disc to RAM, reducing wear to the physical disc and improving speed
and responsiveness.

# SETUP

The `asd` configuration file contains all user-managed settings.  See the entry
on `ASDCONF` in the [`ENVIRONMENT VARIABLES`](#environment-variables) section
for information on the default `asd` configuration file location.  The
configuration file location can be overridden by specifying a pathname in the
`ASDCONF` environment variable.  For instance, to load `asd` settings from
`/here/for/some/reason/lives/asd.conf`:

```shell-session
$ ASDCONF=/here/for/some/reason/lives/asd.conf asd <subcommand>
```

**Note** that edits made to the `asd` configuration file while `asd` is running
will be applied only after `asd` has been restarted.

In the `asd` configuration file, you may define the following variables:

`WHATTOSYNC`

: A list (more specifically, a Bash array) defining the sync targets for `asd`
  to manage.  This variable is **mandatory**.  If you do not define
  `WHATTOSYNC`, or if you set it to the empty list, `asd` will complain and
  bail out.

`VOLATILE`

: A path that lives on a tmpfs or zram mount.  This is where `asd` will store
  the data eventually synchronized back to the physical disk.  By default,
  when running as `root` and `ASDNOV1PATHS` is unset or set to a false value,
  `asd` sets `VOLATILE=/tmp`.  Otherwise, `VOLATILE` defaults to `ASDRUNDIR`.
  **Note** that it is a fatal error to set `VOLATILE` to a path that does not
  live on a tmpfs or zram mount.

`USE_OVERLAYFS`

: A boolean variable controlling whether to use OverlayFS to improve sync speed
  even further and use a smaller memory footprint.  **Note** that this option
  requires your kernel to be configured to use either the `overlay` or
  `overlayfs` module.  See [the FAQ](#q1-what-is-overlayfs-mode) below for
  additional details on this feature.

`USE_BACKUPS`

: A boolean variable controlling whether to create crash-recovery snapshots.

`BACKUP_LIMIT`

: An unsigned integer defining the number of crash-recovery snapshots to keep.

`DEBUG`

: A boolean variable controlling whether to issue debugging output.

**Note** that the default values of `/tmp`/`ASDRUNDIR` should work just fine
for the `VOLATILE` setting.  If using [`bleachbit`][BleachBit], do NOT invoke
it with the `--clean system.tmp` switch or you will remove a key dot file
(`.foo`) from `/tmp` that `asd` needs to keep track of sync status.  Also note
that using a value of `/dev/shm` can cause problems with systemd's `NAMESPACE`
spawning only when users enable the OverlayFS option.

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

## ENVIRONMENT VARIABLES

`asd` recognizes the following environment variables:

`ASDCONF`

: Path to the `asd` configuration file.  Defaults to `/etc/asd.conf` when `asd`
  is running as `root` and `ASDNOV1PATHS` is unset or set to a false value;
  otherwise, defaults to `${ASDCONFDIR}/asd.conf`.

`ASDNOV1PATHS`

: A boolean variable controlling whether to use "version 1" paths or not.  When
  set to a false value, `asd` will use old-style defaults for its daemon file
  (`/run/asd`), lock file (`/run/asd-lock`), and configuration file
  (`/etc/asd.conf`).  **NOTE** that this variable is ignored when `asd` is
  running as a non-`root` user.  Defaults to disabled (effectively,
  `ASDNOV1PATHS=0`).

`ASDCONFDIR`

: Parent directory of `asd.conf` if `ASDCONF` is not defined.  Ignored when
  running as `root` and `ASDNOV1PATHS` is unset or set to a false value.
  Otherwise, defaults to the first (leftmost) of the colon-separated paths in
  the `CONFIGURATION_DIRECTORY` environment variable (which is set when `asd`
  runs under systemd and the `asd.service` unit defines at least one
  `ConfigurationDirectory` entry), falling back to `/etc/asd` when running as
  `root` and `${XDG_CONFIG_DIR}/asd` when running as a non-`root` user.

`ASDRUNDIR`

: Directory where `asd` should store runtime state.  Ignored when running as
  `root` and `ASDNOV1PATHS` is unset or set to a false value.  Otherwise,
  defaults to the first (leftmost) of the colon-separated paths in the
  `RUNTIME_DIRECTORY` (which is set when `asd` runs under systemd and the
  `asd.service` unit defines at least one `RuntimeDirectory` entry), falling
  back to `/run/asd` when running as `root` and `${XDG_RUNTIME_DIR}/asd` when
  running as a non-`root` user.

`ASDCONFTIMEOUT`

: `asd` enforces a limit on how long it takes to load `asd.conf`.  By default,
  that limit is 10 seconds.  You may influence this timeout by setting
  `ASDCONFTIMEOUT` to a duration expression recognized by your system's
  implementation of the `timeout` command.  For instance, you could set
  `ASDCONFTIMEOUT=30` to allow `asd.conf` loading to take 30 seconds, or set
  `ASDCONFTIMEOUT=1m` to allow one minute.

**Note** that, with the exception of `WHATTOSYNC`, all [variables recognized in
`asd.conf`](#setup) can be specified as environment variables.  However, these
environment variables will be overridden if there are any conflicting
definitions in `asd.conf`.

## PREVIEW MODE

The preview option can be called to show users exactly what `asd` will do/is
doing based on the entries in the `asd` configuration file as well as print
useful information such as directory size, paths, and data about any recovery
snapshots that have been created.

```shell-session
$ asd p

Anything-sync-daemon on Arch Linux.

Systemd service is currently active.
Systemd resync service is currently active.
OverlayFS v23 is currently active.

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
or stop `asd`.

The role of the timer is update the tmpfs copies back to the disk.  This occurs
once per hour by default.  The timer is started automatically with
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
daemon.  Examples are provided and are known to work with Upstart.

Note that for these init systems, the supplied cron script (installed to
`/etc/cron.hourly`) will run the resync option to keep the tmpfs copies
synchronized.  Of course, the target system must have cron installed and active
for this to happen.

# SUPPORTED DISTROS

At this time, the following distros are officially supported but there is no
reason to think that `asd` will not run on another distro:

- Arch Linux

# FAQ

## Q1: What is "OverlayFS mode"?

## A1:

[OverlayFS][] is a simple union filesystem mainlined in the Linux kernel
version 3.18.0.  Starting with `asd` version 5.54, OverlayFS can be used to
reduce the memory footprint of `asd`'s tmpfs space and to speed up sync and
unsync operations.  The magic is in how the overlay mount only writes out data
that has changed rather than writing out the entire sync target.  The same
recovery features `asd` uses in its default mode are also active when running
in OverlayFS mode.  OverlayFS mode is enabled by setting the `USE_OVERLAYFS`
variable to a truthy value (e.g. `USE_OVERLAYFS=1`) in the `asd` configuration
(followed by a restart of the daemon if `asd` is already active).

There are several versions of OverlayFS available to the Linux kernel in
production in various distros.  Versions 22 and lower have a module called
`overlayfs` while newer versions (23 and higher) have a module called `overlay`
-- note the lack of the "fs" in the newer version.  `asd` will automatically
detect the OverlayFS version available to your kernel when `USE_OVERLAYFS` is
enabled.

See the example in [the "PREVIEW MODE" section](#preview-mode) above which
shows a system using OverlayFS to illustrate the memory savings that can be
achieved.  Note the "overlayfs size" report compared to the total "dir size"
report for each sync target.  Be aware that these numbers will change depending
on just how much data is written to the sync target, but in common use cases,
the OverlayFS size will always be less than the dir size.

## Q2: Why do I see the directories `.foo-backup_asd` and `.foo-backup_asd-old`?

## A2:

The `asd` backup process works by creating a hard-linked clone of the original
directory; this is known as `.foo-backup_asd-old`.  The other `.foo-backup_asd`
is just a bind mount to the original directory link which is used to access the
contents of the original directory for overlay purposes.

## Q3: My system crashed and `asd` didn't sync back.  What do I do?

## A3:

The "last good" backup of your sync targets is just fine still sitting
happily on your filesystem.  Upon restarting `asd` (on a reboot for example), a
check is preformed to see if `asd` was exited in some corrupted state.  If it is
detected, `asd` will snapshot the "last good" backup before it rotates it back
into place.  Note that, since `asd` tries to decrease the disk usage, it never
really "copies" the full contents of the directory and just uses the hardlinks
to the previous files.  And during the `rsync` step, it creates new files so
that the previous hardlinks are untouched.  So trying to modify the directory
during the time `asd` is trying to backup can leave the directory in some
corrupted state.

## Q4: Where can I find the crash-recovery snapshot?

## A4:

You will find the snapshot in the same directory as the sync target.  It will
contain a `<date>_<time>` suffix that corresponds to the time at which the
recovery took place.  For example, a `/foo/bar` snapshot will have a path like
`/foo/.bar-backup_asd-crashrecovery-20141221_070112.tar.zstd` -- of course, the
`<date>_<time>` suffix will be different for you.

## Q5: How can I restore the crash-recovery snapshot?

## A5:

Follow these steps:

1. Stop `asd`.
2. Confirm that the directories created by `asd` are not present.  If they are,
   `asd` did not stop correctly for other reasons.
3. Move the "bad" copy of the sync taget to a backup (don't blindly delete
   anything).
4. Untar the snapshot directory to the expected sync target.

Example using `/foo/bar` under systemd:

```shell-session
# systemctl stop asd.service
# cd /foo
# mv bar bar-bad
# tar -xvf .bar-backup_asd-crashrecovery-20141221_070112.tar.zstd
```

At this point, check that everything is fine with the data on `/foo/bar`.  If
all is well, it is safe to delete the snapshot.

## Q6: Can `asd` delete the snapshots automatically?

## A6:

Yes, run `asd` with the `clean` switch to delete snapshots.  See the ["CLEAN
MODE"](#clean-mode) section for details.

# CONTRIBUTE

Users wishing to contribute to this code should fork and send a pull request.
Source is freely available on the project page linked below.

# BUGS

Discover a bug? Please open an issue on the project page linked below.

## KNOWN BUGS

- Currently, `asd` cannot handle open files on a sync target, so if a hung
  process has something open there, it can be messy.

# ONLINE

- Project page: https://github.com/graysky2/anything-sync-daemon
- Wiki page: https://wiki.archlinux.org/index.php/Anything-sync-daemon

# SEE ALSO

`bash`(1), `cron`(8), `crontab`(1), `crontab`(5), `mount`(5),
`systemd.exec`(5), `systemd.service`(5), `systemd.timer`(5), `systemd.unit`(5)

# AUTHOR

graysky (graysky AT archlinux DOT us)

# MAINTAINER

Manorit Chawdhry (manorit2001@gmail.com)
