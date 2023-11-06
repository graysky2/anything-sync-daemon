{
  self,
  config,
  moduleWithSystem,
  ...
}: {
  flake = {
    nixosModules = {
      default = config.flake.nixosModules.anything-sync-daemon;

      anything-sync-daemon = moduleWithSystem ({config, ...} @ perSystem: {
        config,
        lib,
        pkgs,
        ...
      }: let
        inherit (lib) mkOption types;

        cfg = config.services.asd;

        mkOptionWithDefaults = {...} @ defaults: {default, ...} @ args: mkOption (defaults // args);

        mkPackageOption = mkOptionWithDefaults {
          type = types.package;
          defaultText = "pkgs.anything-sync-daemon";
          description = ''
            Package providing the {command}`anything-sync-daemon`
            executable.
          '';
        };

        mkDebugOption = mkOptionWithDefaults {
          type = types.bool;
          description = ''
            Whether to enable debugging output for the {command}`asd.service`
            and {command}`asd-resync.service` services.
          '';
        };

        mkResyncTimerOption = mkOptionWithDefaults {
          type = types.nonEmptyStr;
          example = "1h 30min";
          description = ''
            The amount of time to wait before syncing back to the disk.

            Takes a {manpage}`systemd.time(7)` time span. The time unit
            defaults to seconds if omitted.
          '';
        };

        common = {config, ...}: {
          options = {
            enable = lib.mkEnableOption "the `anything-sync-daemon` service";

            package = mkPackageOption {
              default = cfg.package;
            };

            debug = mkDebugOption {
              default = cfg.debug;
            };

            resyncTimer = mkResyncTimerOption {
              default = cfg.resyncTimer;
            };

            whatToSync = mkOption {
              type = types.listOf types.path;
              default = [];
              description = ''
                List of paths to synchronize from volatile to durable
                storage.  Will be injected into the
                {command}`anything-sync-daemon` configuration file as the
                value of the {env}`WHATTOSYNC` array variable.

                **Note** that the {command}`anything-sync-daemon`
                configuration file is a Bash script.  Please ensure that you
                appropriately shell-quote entries in the {option}`whatToSync`
                list.
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
                Enable the user of overlayfs to improve sync speed even
                further and use a smaller memory footprint.

                When enabled, the {env}`USE_OVERLAYFS` variable will be set
                to `1` in the {command}`anything-sync-daemon` configuration
                file; otherwise it will be set to `0`.
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

        mkBaseService = c: mod:
          lib.mkMerge ([
              {
                enable = true;

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
          mkBaseService c {
            description = "Anything-sync-daemon";
            wants = ["asd-resync.service"];
            serviceConfig = {
              RemainAfterExit = "yes";
              ExecStart = "${c.package}/bin/anything-sync-daemon sync";
              ExecStop = "${c.package}/bin/anything-sync-daemon unsync";
            };
          };

        mkAsdResyncService = c:
          mkBaseService c {
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
          timerConfig.OnUnitActiveSec = "${c.resyncTimer}";
        };
      in {
        options.services.asd = {
          package = mkPackageOption {
            default = perSystem.config.packages.anything-sync-daemon;
          };

          debug = mkDebugOption {
            default = true;
          };

          resyncTimer = mkResyncTimerOption {
            default = "1h";
          };

          system = mkOption {
            type = types.submodule common;
            default = {};
            description = ''
              Options relating to the systemwide
              {command}`anything-sync-daemon` service.
            '';
          };

          user = mkOption {
            type = types.submodule common;
            default = {};
            description = ''
              Options relating to the per-user
              {command}`anything-sync-daemon` service.
            '';
          };
        };

        config = lib.mkMerge [
          {
            assertions = [
              {
                assertion = (cfg.system.useOverlayFS || cfg.user.useOverlayFS) -> config.security.sudo.enable;
                message = ''
                  asd: `config.security.sudo` must be enabled when `useOverlayFS` is in effect.
                '';
              }
            ];
          }

          (lib.mkIf cfg.system.enable {
            # Just a convenience; the `asd.service` unit sets the `ASDCONF`
            # variable to `cfg.system.configFile`.
            environment.etc."asd/asd.conf" = {
              source = cfg.system.configFile;
            };

            systemd = {
              services = {
                asd = lib.mkMerge [
                  (mkAsdService cfg.system)
                  {
                    wantedBy = ["multi-user.target"];
                  }
                ];

                asd-resync = mkAsdResyncService cfg.system;
              };

              timers.asd-resync = mkAsdResyncTimer cfg.system;
            };
          })

          (lib.mkIf cfg.user.enable {
            systemd.user = {
              services = let
              in {
                asd = lib.mkMerge [
                  (mkAsdService cfg.user)
                  {
                    wantedBy = ["default.target"];
                  }
                ];

                asd-resync = mkAsdResyncService cfg.user;
              };

              timers.asd-resync = mkAsdResyncTimer cfg.user;
            };
          })
        ];
      });

      example-profile = {
        config,
        lib,
        ...
      }: let
        inherit (config.users.users) asduser;

        cfg = config.services.asd;

        common = {
          enable = true;
          resyncTimer = "3s";
          backupLimit = 2;
          useOverlayFS = true;
        };
      in {
        imports = [
          self.nixosModules.anything-sync-daemon
        ];

        # Install `anything-sync-daemon` and `asd-mount-helper` globally.
        # Makes it possible to run `asd-mount-helper` in the `check.sh`
        # helper script.
        environment.systemPackages = [cfg.package];

        security.sudo = {
          enable = true;
          extraRules = [
            {
              users = [config.users.users.asduser.name];
              commands = [
                {
                  command = "${cfg.package}/bin/asd-mount-helper";
                  options = ["NOPASSWD" "SETENV"];
                }

                # Permit running `asd-mount-helper` as superuser in
                # `check.sh`.
                {
                  command = "/run/current-system/sw/bin/asd-mount-helper";
                  options = ["NOPASSWD" "SETENV"];
                }
              ];
            }
          ];
        };

        # `false` is the default; set it here anyway to document that we want
        # user processes (e.g. `asd-resync`) to persist after the user
        # session closes.
        services.logind.killUserProcesses = false;

        services.asd.system = lib.mkMerge [
          common

          {
            whatToSync = [
              "/var/lib/what-to-sync"
            ];
          }
        ];

        services.asd.user = lib.mkMerge [
          common

          {
            whatToSync = [
              "${asduser.home}/what-to-sync"
            ];
          }
        ];

        systemd.tmpfiles.rules = let
          system = map (d: "d ${d} 0755 root root - -") cfg.system.whatToSync;
          user = map (d: "d ${d} 0755 ${asduser.name} ${asduser.group} - -") cfg.user.whatToSync;
        in
          system ++ user;

        users.users.asduser = {
          createHome = true;
          home = "/home/asduser";
          isNormalUser = true;
        };
      };
    };
  };
}
