# Changelog for `anything-sync-daemon`

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Support running as an unprivileged user.
- Document usage in [a Markdown file](/USAGE.md) readable in GitHub's web UI.
- Document significant environment variables in the manual page.
- Add [a Nix derivation](/nix/packages.nix) for `anything-sync-daemon`.
- Add [NixOS modules](/nix/nixos-modules.nix) for managing
  `anything-sync-daemon`.
- Support OverlayFS when running as an unprivileged user by managing mounts
  through the new [`asd-mount-helper`](/common/asd-mount-helper) script.
  For this to work, the user in question must be able to run `asd-mount-helper`
  as root via `sudo` without entering a password.
- Install the example systemd unit files to the `/user/` unit file hierarchy
  when executing the `install-systemd` Make target.

### Fixed

- Only unmount bind mounts if they have the expected source, and only unmount
  volatile paths if they are OverlayFS mountpoints.
- Ensure that `asd.conf`'s parent directory exists before attempt to copy
  `asd.conf` into it.
- Deduplicate sync targets (entries in the `WHATTOSYNC` array).  This means
  testing for string equality on said targets' canonicalized representations,
  as determined by `realpath -m` or `readlink -m`, if those commands are
  available and respect the `-m` ("canonicalize missing") option, or otherwise
  by a native shell routine that simply removes trailing slashes.
  `anything-sync-daemon` issues a non-fatal warning if it detects duplicate
  sync targets.
- Ensure that all intended mount points are mounted as expected when performing
  the "ungraceful state" check.  This means checking that bind mounts exist and
  have the expected source (e.g. `/foo/bar/.baz-backup_asd-old` has the source
  `/foo/bar/baz`) and that (when `USE_OVERLAYFS` is in effect) overlay mount
  targets have the same mount options as their mount sources.  This makes it
  possible for `asd` to recover from partial mount states -- that is, to
  sensibly re-mount intended mount points before performing re-synchronization.
- In the "ungraceful state" check, only unmount intended mountpoints if they
  are mounted as expected (in the manner described immediately above).  This
  means that `asd` is no longer liable to unmount other filesystems that may
  happen to be mounted in the relevant locations.
- Install the `asd.conf` parent directory before attempting to copy `asd.conf`
  into place.

### Changed

- **BREAKING CHANGE**: Load `asd.conf` in a subprocess. This is a breaking
  change for configurations that attempt to inspect or modify the
  `anything-sync-daemon` script's internal state.
- **BREAKING CHANGE**: Enforce a timeout of configurable
  duration on loading `asd.conf` operation.  This is a breaking change for
  configurations that do not load within said timeout, though this can be
  addressed by specifying a longer timeout in the `ASDCONFTIMEOUT` environment
  variable.
- **BREAKING CHANGE**: Use the portable shebang `#!/usr/bin/env bash` rather
  than using `#!/bin/bash`.  This is a breaking change for any setups that (a)
  have a `bash` under an entry in `PATH` that takes precedence over
  `/bin/bash`, and (b) are compatible with `/bin/bash` but not the
  higher-precedence `bash`.  It is also incompatible with setups that lack
  `/bin` in `PATH`.
- Respect [the `NO_COLOR` environment variable](https://no-color.org); that is,
  do not colorize output if `NO_COLOR` is set to a non-empty value.
- **BREAKING CHANGE**: Attempt to obtain an exclusive lock in-process (via
  `flock -n <file-descriptor>`) rather than by re-executing when the `FLOCKER`
  environment variable is unset or empty.  This breaks setups that bypass
  locking by setting `FLOCKER` to a non-empty value.
- **BREAKING CHANGE**: detect the presence of `asd.service` by running
  `systemd list-unit-files asd.service`, in addition to checking for the unit
  file at `/usr/lib/systemd/system/asd.service` (or, if running `asd` as a
  non-root user, `/usr/lib/systemd/user/asd.service`).  This makes `asd` liable
  to conclude that it is being run under systemd when previously it would have
  concluded otherwise.
- **BREAKING CHANGE**: detect the `INVOCATION_ID` environment variable and, if
  it is present, determine the name of the corresponding systemd service, if
  one exists.  If a service is detected, assume that `asd` is running under
  systemd.  As with the item just above, this makes `asd` liable to conclude
  that it is being run under systemd when previously it would have concluded
  otherwise.

### Removed

- Removed the `asd.conf` "syntax check".  Now, `anything-sync-daemon` accepts
  any valid Bash code in `asd.conf`.
