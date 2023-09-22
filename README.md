# Anything-sync-daemon

Anything-sync-daemon (asd) is a tiny pseudo-daemon designed to manage user
defined dirs in tmpfs and to periodically sync back to the physical disc
(HDD/SSD). This is accomplished via a symlinking step and an innovative use of
rsync to maintain back-up and synchronization between the two. One of the major
design goals of asd is a completely transparent user experience.

## Documentation

Consult the `asd(1)` man page (available [here](/USAGE.md)) or
[the Arch Linux `asd` wiki page](https://wiki.archlinux.org/index.php/Anything-sync-daemon).

## Installation from Source

To build from source, see [the included INSTALL](/INSTALL) text document.

## Installation from Distro Packages

- ![logo](http://www.monitorix.org/imgs/archlinux.png "arch logo")Arch: in the [AUR](https://aur.archlinux.org/packages/anything-sync-daemon).
