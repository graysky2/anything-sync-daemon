{
  lib,
  inputs,
  ...
}: {
  perSystem = {
    config,
    inputs',
    pkgs,
    system,
    ...
  }: {
    devshells.default = {
      commands =
        [
          {
            name = "fmt";
            category = "linting";
            help = "Lint and format this project's shell and Nix code";
            command = ''
              exec ${config.treefmt.build.wrapper}/bin/treefmt "$@"
            '';
          }
        ]
        ++ lib.optional (lib.hasAttr system inputs.nixos-shell.packages) {
          category = "dev";
          package = inputs'.nixos-shell.packages.nixos-shell;
          help = "Spawn lightweight NixOS VMs in a shell";
        };

      devshell = {
        packages = with pkgs; [gnumake gzip];
        packagesFrom = [config.packages.anything-sync-daemon];
      };
    };

    treefmt = {
      programs.alejandra.enable = true;
      programs.shellcheck.enable = true;

      settings.formatter.shellcheck = {
        includes = [
          "common/anything-sync-daemon.in"
          "common/asd-mount-helper"
        ];

        options = [
          # Follow `source` statements even when the file is not specified as
          # input.
          "-x"
        ];
      };

      flakeFormatter = true;
      projectRootFile = "flake.nix";
    };
  };
}
