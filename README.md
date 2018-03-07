# Anything-sync-daemon
Anything-sync-daemon (asd) is a tiny pseudo-daemon designed to manage user defined dirs in tmpfs and to periodically sync back to the physical disc (HDD/SSD). This is accomplished via several bind mounting steps and an innovative use of rsync to maintain back-up and synchronization between the two. One of the major design goals of asd is a completely transparent user experience.

## Documentation
Consult the man page or the wiki page: https://wiki.archlinux.org/index.php/Anything-sync-daemon

## Installation from Source
To build from source, see the included INSTALL text document.

## Installation from Distro Packages
* ![logo](http://www.monitorix.org/imgs/archlinux.png "arch logo")Arch: in the [AUR](https://aur.archlinux.org/packages/anything-sync-daemon).
* ![logo](http://s18.postimg.org/w5jvz71mt/chakra.jpg "chakra logo")Chakra: in the [CCR](http://chakraos.org/ccr/packages.php?ID=3750).

## WARNING
Users of versions older than v5.69 MUST stop asd before upgrading. Data loss can occur if you ignore this warning.

Arch Linux users do not need to worry about if asd is installed from the official PKGBUILD in the AUR. This contains a pre_upgrade scriptlet that will stop asd for you.

I cannot do this for Ubuntu users building this manually.

You have been warned.
