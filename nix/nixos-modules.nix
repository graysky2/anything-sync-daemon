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

        asd-lib = import ./lib.nix {inherit lib;};

        inherit (asd-lib.options) mkDebugOption mkPackageOption mkResyncTimerOption;
        inherit (asd-lib.generators) mkAsdService mkAsdResyncService mkAsdResyncTimer;

        cfg = config.services.asd;

        instanceType = types.submodule (lib.const {
          imports = [asd-lib.modules.instance];
          _module.args = {
            inherit lib pkgs;
            context = cfg;
          };
        });
      in {
        _file = ./nixos-modules.nix;

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
            type = instanceType;
            default = {};
            description = ''
              Options relating to the systemwide
              {command}`anything-sync-daemon` service.
            '';
          };

          user = mkOption {
            type = instanceType;
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
              services = {
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
