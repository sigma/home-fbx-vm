{
  inputs = {
    fbx-vm.url = "github:firefly-engineering/fbx-vm";

    nixpkgs.follows = "fbx-vm/nixpkgs";
    flake-parts.follows = "fbx-vm/flake-parts";
  };


  outputs = inputs @ { self, flake-parts, fbx-vm, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        fbx-vm.flakeModules.freebox
      ];

      systems = [
        "aarch64-linux"
      ];

      freebox.vm = {
        enable = true;
        modules = [
          ./modules/configuration.nix
          ./modules/home-assistant.nix
          ./modules/hummingbot.nix
        ];
      };
    };
}