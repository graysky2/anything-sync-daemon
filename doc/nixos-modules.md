## services\.asd\.package



Package providing the ` anything-sync-daemon `
executable\.



*Type:*
package



*Default:*
` "pkgs.anything-sync-daemon" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.debug

Whether to enable debugging output for the ` asd.service `
and ` asd-resync.service ` services\.



*Type:*
boolean



*Default:*
` true `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.resyncTimer



The amount of time to wait before syncing back to the disk\.

Takes a [` systemd.time(7) `](https://www.freedesktop.org/software/systemd/man/systemd.time.html) time span\. The time unit
defaults to seconds if omitted\.



*Type:*
non-empty string



*Default:*
` "1h" `



*Example:*
` "1h 30min" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system



Options relating to the systemwide
` anything-sync-daemon ` service\.



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.enable



Whether to enable the ` anything-sync-daemon ` service\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.package



Package providing the ` anything-sync-daemon `
executable\.



*Type:*
package



*Default:*
` "pkgs.anything-sync-daemon" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.backupLimit



Number of crash-recovery archives to keep\.  When non-null, it
will be injected into the ` anything-sync-daemon `
configuration file as the value of the ` BACKUP_LIMIT `
variable\.



*Type:*
null or unsigned integer, meaning >=0



*Default:*
` null `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.configFile



The generated ` anything-sync-daemon ` configuration
file used as ` ASDCONF ` in the generated
` anything-sync-daemon ` services\.



*Type:*
path *(read only)*



*Default:*
` <derivation asd.conf> `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.debug



Whether to enable debugging output for the ` asd.service `
and ` asd-resync.service ` services\.



*Type:*
boolean



*Default:*
` true `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.extraConfig



Additional contents for the ` anything-sync-daemon `
configuration file\.



*Type:*
strings concatenated with “\\n”



*Default:*
` "" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.resyncTimer



The amount of time to wait before syncing back to the disk\.

Takes a [` systemd.time(7) `](https://www.freedesktop.org/software/systemd/man/systemd.time.html) time span\. The time unit
defaults to seconds if omitted\.



*Type:*
non-empty string



*Default:*
` "1h" `



*Example:*
` "1h 30min" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.useOverlayFS



Enable the user of overlayfs to improve sync speed even
further and use a smaller memory footprint\.

When enabled, the ` USE_OVERLAYFS ` variable will be set
to ` 1 ` in the ` anything-sync-daemon ` configuration
file; otherwise it will be set to ` 0 `\.



*Type:*
boolean



*Default:*
` false `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.system\.whatToSync



List of paths to synchronize from volatile to durable
storage\.  Will be injected into the
` anything-sync-daemon ` configuration file as the
value of the ` WHATTOSYNC ` array variable\.

**Note** that the ` anything-sync-daemon `
configuration file is a Bash script\.  Please ensure that you
appropriately shell-quote entries in the ` whatToSync `
list\.



*Type:*
list of path



*Default:*
` [ ] `



*Example:*

```
[
  "\"\${XDG_CACHE_HOME}/something-or-other\""
  "~/.stuff"
]
```

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user



Options relating to the per-user
` anything-sync-daemon ` service\.



*Type:*
submodule



*Default:*
` { } `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.enable



Whether to enable the ` anything-sync-daemon ` service\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.package



Package providing the ` anything-sync-daemon `
executable\.



*Type:*
package



*Default:*
` "pkgs.anything-sync-daemon" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.backupLimit



Number of crash-recovery archives to keep\.  When non-null, it
will be injected into the ` anything-sync-daemon `
configuration file as the value of the ` BACKUP_LIMIT `
variable\.



*Type:*
null or unsigned integer, meaning >=0



*Default:*
` null `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.configFile



The generated ` anything-sync-daemon ` configuration
file used as ` ASDCONF ` in the generated
` anything-sync-daemon ` services\.



*Type:*
path *(read only)*



*Default:*
` <derivation asd.conf> `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.debug



Whether to enable debugging output for the ` asd.service `
and ` asd-resync.service ` services\.



*Type:*
boolean



*Default:*
` true `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.extraConfig



Additional contents for the ` anything-sync-daemon `
configuration file\.



*Type:*
strings concatenated with “\\n”



*Default:*
` "" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.resyncTimer



The amount of time to wait before syncing back to the disk\.

Takes a [` systemd.time(7) `](https://www.freedesktop.org/software/systemd/man/systemd.time.html) time span\. The time unit
defaults to seconds if omitted\.



*Type:*
non-empty string



*Default:*
` "1h" `



*Example:*
` "1h 30min" `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.useOverlayFS



Enable the user of overlayfs to improve sync speed even
further and use a smaller memory footprint\.

When enabled, the ` USE_OVERLAYFS ` variable will be set
to ` 1 ` in the ` anything-sync-daemon ` configuration
file; otherwise it will be set to ` 0 `\.



*Type:*
boolean



*Default:*
` false `

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)



## services\.asd\.user\.whatToSync



List of paths to synchronize from volatile to durable
storage\.  Will be injected into the
` anything-sync-daemon ` configuration file as the
value of the ` WHATTOSYNC ` array variable\.

**Note** that the ` anything-sync-daemon `
configuration file is a Bash script\.  Please ensure that you
appropriately shell-quote entries in the ` whatToSync `
list\.



*Type:*
list of path



*Default:*
` [ ] `



*Example:*

```
[
  "\"\${XDG_CACHE_HOME}/something-or-other\""
  "~/.stuff"
]
```

*Declared by:*
 - [nix/nixos-modules\.nix](/nix/nixos-modules.nix)


