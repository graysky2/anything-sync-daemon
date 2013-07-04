#Anything-sync-daemon
Anything-sync-daemon (asd) is a tiny pseudo-daemon designed to manage user defined dirs in tmpfs and to periodically sync back to the physical disc (HDD/SSD). This is accomplished via a symlinking step and an innovative use of rsync to maintain back-up and synchronization between the two. One of the major design goals of psd is a completely transparent user experience.

##Links
* AUR Package: https://aur.archlinux.org/packages/anything-sync-daemon

##Documentation
Consult the man page or the wiki page: https://wiki.archlinux.org/index.php/Anything-sync-daemon

##WARNING
Users of versions older than v3.15 MUST stop asd before upgrading.
Data loss can occur if you ignore this warning.

Arch Linux users do not need to worry about if asd is installed from the
official PKGBUILD in the AUR. This contains a pre_upgrade scriptlet that
will stop asd for you.

I cannot do this for Ubuntu users building this manually.

You have been warned.
