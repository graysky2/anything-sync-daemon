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

          {
            name = "mkoptdocs";
            category = "maintenance";
            help = "Generate NixOS module options documentation";
            command = ''
              docs="$(${pkgs.nix}/bin/nix "$@" build --print-out-paths --no-link "''${PRJ_ROOT}#docs")" || exit

              seen=0
              while read -r path; do
                seen="$((seen + 1))"
                if [ "$seen" -gt 1 ]; then
                  printf 1>&2 -- 'error: more than one output path...\n'
                  exit 1
                fi
                install -Dm0644 "$path" "''${PRJ_ROOT}/doc/nixos-modules.md"
              done <<DOCS
              $docs
              DOCS
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
