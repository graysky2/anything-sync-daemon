{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({lib, ...}: {
      debug = true;

      systems = ["aarch64-linux" "x86_64-linux"];

      imports = [
        inputs.devshell.flakeModule
        inputs.treefmt-nix.flakeModule

        ./nix/devshells.nix
      ];

      perSystem = {
        config,
        self',
        ...
      }: {
        apps.devshell = self'.devShells.default.flakeApp;
      };
    });
}
