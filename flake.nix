{
  inputs = {
    fbx-vm.url = "github:firefly-engineering/fbx-vm";

    nixpkgs.follows = "fbx-vm/nixpkgs";
    flake-parts.follows = "fbx-vm/flake-parts";
  };


  outputs = inputs @ { self, flake-parts, fbx-vm, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        fbx-vm.flakeModules.freebox
      ];

      systems = [
        "aarch64-darwin"
      ];

      freebox.vm = {
        enable = true;
        modules = [
          ./modules/configuration.nix
        ];
      };
    };
}