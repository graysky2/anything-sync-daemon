{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixos-shell.url = "github:Mic92/nixos-shell";
    nixos-shell.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      self,
      lib,
      ...
    }: {
      debug = true;

      systems = lib.subtractLists [
        "armv5tel-linux"
        "armv6l-linux"
        "mipsel-linux"
        "riscv64-linux"
      ] (lib.intersectLists lib.systems.flakeExposed lib.platforms.linux);

      imports = [
        inputs.devshell.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.treefmt-nix.flakeModule

        ./nix/checks.nix
        ./nix/devshells.nix
        ./nix/nixos-modules.nix
        ./nix/packages.nix
      ];

      perSystem = {
        config,
        self',
        ...
      }: {
        apps.devshell = self'.devShells.default.flakeApp;
        overlayAttrs = {
          inherit (config.packages) anything-sync-daemon;
        };
      };

      flake = {
        nixosConfigurations.example = inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ({config, ...}: {
              # Make the VM more self-contained.
              nixos-shell.mounts = {
                mountHome = false;
                mountNixProfile = false;
                cache = "none";
              };

              # Silence stateVersion warning.
              system.stateVersion = config.system.nixos.release;
            })

            inputs.nixos-shell.nixosModules.nixos-shell
            self.nixosModules.example-profile
          ];
        };
      };
    });
}
