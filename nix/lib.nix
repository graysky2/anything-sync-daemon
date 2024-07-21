{lib}: let
  inherit (lib) mkOption types;
in
  lib.fix (self: {
    options = {
      mkOptionWithDefaults = {...} @ defaults: {default, ...} @ args: mkOption (defaults // args);

      mkPackageOption = self.options.mkOptionWithDefaults {
        type = types.package;
        defaultText = "pkgs.anything-sync-daemon";
        description = ''
          Package providing the {command}`anything-sync-daemon` executable.
        '';
      };

      mkDebugOption = self.options.mkOptionWithDefaults {
        type = types.bool;
        description = ''
          Whether to enable debugging output for the {command}`asd.service`
          and {command}`asd-resync.service` services.
        '';
      };

      mkResyncTimerOption = self.options.mkOptionWithDefaults {
        type = types.nonEmptyStr;
        example = "1h 30min";
        description = ''
          The amount of time to wait before syncing back to the disk.

          Takes a {manpage}`systemd.time(7)` time span. The time unit defaults
          to seconds if omitted.
        '';
      };
    };

    modules = {
      instance = {
        config,
        lib,
        pkgs,
        context,
        ...
      }: {
        options = {
          enable = lib.mkEnableOption "the `anything-sync-daemon` service";

          package = self.options.mkPackageOption {
            default = context.package;
          };

          debug = self.options.mkDebugOption {
            default = context.debug;
          };

          resyncTimer = self.options.mkResyncTimerOption {
            default = context.resyncTimer;
          };

          whatToSync = mkOption {
            type = types.listOf types.path;
            default = [];
            description = ''
              List of paths to synchronize from volatile to durable storage.
              Will be injected into the {command}`anything-sync-daemon`
              configuration file as the value of the {env}`WHATTOSYNC` array
              variable.

              **Note** that the {command}`anything-sync-daemon` configuration
              file is a Bash script.  Please ensure that you appropriately
              shell-quote entries in the {option}`whatToSync` list.
            '';
            example = [
              "\"\${XDG_CACHE_HOME}/something-or-other\""
              "~/.stuff"
            ];
          };

          backupLimit = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            description = ''
              Number of crash-recovery archives to keep.  When non-null, it
              will be injected into the {command}`anything-sync-daemon`
              configuration file as the value of the {env}`BACKUP_LIMIT`
              variable.
            '';
          };

          useOverlayFS = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Enable the use of overlayfs to improve sync speed even further
              and use a smaller memory footprint.

              When enabled, the {env}`USE_OVERLAYFS` variable will be set to
              `1` in the {command}`anything-sync-daemon` configuration file;
              otherwise it will be set to `0`.
            '';
          };

          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Additional contents for the {command}`anything-sync-daemon`
              configuration file.
            '';
          };

          configFile = mkOption {
            type = types.path;
            readOnly = true;
            description = ''
              The generated {command}`anything-sync-daemon` configuration
              file used as {env}`ASDCONF` in the generated
              {command}`anything-sync-daemon` services.
            '';
            default =
              pkgs.writers.makeScriptWriter {
                interpreter = "${pkgs.bash}/bin/bash";
                check = "${pkgs.bash}/bin/bash -n";
              } "asd.conf" ''
                ${lib.optionalString (config.backupLimit != null) ''
                  BACKUP_LIMIT=${lib.escapeShellArg (toString config.backupLimit)}

                ''}
                USE_OVERLAYFS=${lib.escapeShellArg config.useOverlayFS}

                WHATTOSYNC=(
                  ${toString config.whatToSync}
                )

                ${config.extraConfig}
              '';
          };
        };
      };
    };

    generators = {
      mkBaseService = c: mod:
        lib.mkMerge ([
            {
              environment = {
                ASDCONF = c.configFile;
                ASDNOV1PATHS = "yes";
                DEBUG =
                  if c.debug
                  then "1"
                  else "0";
              };

              # Ensure we can find sudo.  Needed when `USE_OVERLAYFS` is
              # enabled.  Note that we add it even if `config.useOverlayFS` is
              # disabled, as users may set `USE_OVERLAYFS` themselves (for
              # instance, in `config.extraConfig`).
              path = ["/run/wrappers"];

              serviceConfig = {
                Type = "oneshot";
                RuntimeDirectory = ["asd"];

                # The pseudo-daemon stores files in this directory that need to
                # last beyond the lifetime of the oneshot.
                RuntimeDirectoryPreserve = true;
              };
            }
          ]
          ++ lib.toList mod);

      mkAsdService = c:
        self.generators.mkBaseService c {
          description = "Anything-sync-daemon";
          wants = ["asd-resync.service"];
          serviceConfig = {
            RemainAfterExit = true;
            ExecStart = "${c.package}/bin/anything-sync-daemon sync";
            ExecStop = "${c.package}/bin/anything-sync-daemon unsync";
          };
        };

      mkAsdResyncService = c:
        self.generators.mkBaseService c {
          description = "Timed resync";
          after = ["asd.service"];
          wants = ["asd-resync.timer"];
          partOf = ["asd.service"];
          wantedBy = ["default.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${c.package}/bin/anything-sync-daemon resync";
          };
        };

      mkAsdResyncTimer = c: {
        partOf = ["asd-resync.service" "asd.service"];
        description = "Timer for anything-sync-daemon - ${c.resyncTimer}";
        timerConfig.OnUnitActiveSec = c.resyncTimer;
      };

      hm = {
        mkBaseService = c: attrs:
          lib.recursiveUpdate {
            Service = {
              Environment = [
                "ASDCONF=${c.configFile}"
                "ASDNOV1PATHS=yes"
                "DEBUG=${
                  if c.debug
                  then "1"
                  else "0"
                }"
                "PATH=$PATH:/run/wrappers/bin"
              ];

              Type = "oneshot";
              RuntimeDirectory = ["asd"];

              # The pseudo-daemon stores files in this directory that need to
              # last beyond the lifetime of the oneshot.
              RuntimeDirectoryPreserve = true;
            };
          }
          attrs;

        mkAsdService = c:
          self.generators.hm.mkBaseService c {
            Unit = {
              Description = "Anything-sync-daemon";
              Wants = ["asd-resync.service"];
            };

            Service = {
              RemainAfterExit = true;
              ExecStart = "${c.package}/bin/anything-sync-daemon sync";
              ExecStop = "${c.package}/bin/anything-sync-daemon unsync";
            };
          };

        mkAsdResyncService = c:
          self.generators.hm.mkBaseService c {
            Install = {
              WantedBy = ["default.target"];
            };

            Unit = {
              Description = "Timed resync";
              After = ["asd.service"];
              Wants = ["asd-resync.timer"];
              PartOf = ["asd.service"];
            };

            Service = {
              Type = "oneshot";
              ExecStart = "${c.package}/bin/anything-sync-daemon resync";
            };
          };

        mkAsdResyncTimer = c: {
          Unit = {
            Description = "Timer for anything-sync-daemon - ${c.resyncTimer}";
            PartOf = ["asd-resync.service" "asd.service"];
          };

          Timer = {
            OnUnitActiveSec = c.resyncTimer;
          };
        };
      };
    };
  })
