{
  self,
  config,
  moduleWithSystem,
  ...
}: {
  flake = {
    homeModules = {
      default = config.flake.homeModules.anything-sync-daemon;

      anything-sync-daemon = moduleWithSystem ({config, ...} @ perSystem: {
        config,
        lib,
        pkgs,
        ...
      }: let
        inherit (lib) mkOption types;

        asd-lib = import ./lib.nix {inherit lib;};

        inherit (asd-lib.options) mkDebugOption mkPackageOption mkResyncTimerOption;
        inherit (asd-lib.generators.hm) mkAsdService mkAsdResyncService mkAsdResyncTimer;

        cfg = config.services.asd;
      in {
        _file = ./home-modules.nix;

        options.services.asd = mkOption {
          type = types.submodule (lib.const {
            imports = [asd-lib.modules.instance];
            _module.args = {
              inherit lib pkgs;
              context = {
                package = perSystem.config.packages.anything-sync-daemon;
                debug = true;
                resyncTimer = "1h";
              };
            };
          });
          default = {};
          description = ''
            Configuration for anything-sync-daemon (`asd`).
          '';
        };

        config = lib.mkIf cfg.enable {
          systemd.user = {
            services = {
              asd = lib.mkMerge [
                (mkAsdService cfg)
                {
                  Install.WantedBy = ["default.target"];
                }
              ];

              asd-resync = mkAsdResyncService cfg;
            };

            timers.asd-resync = mkAsdResyncTimer cfg;
          };
        };
      });
    };
  };
}
