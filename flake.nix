{
  inputs = {
    fbx-vm.url = "github:firefly-engineering/fbx-vm";

    nixpkgs.follows = "fbx-vm/nixpkgs";
    flake-parts.follows = "fbx-vm/flake-parts";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };


  outputs = inputs @ { self, flake-parts, fbx-vm, nixpkgs, sops-nix, ... }:
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
          sops-nix.nixosModules.sops
          ./modules/configuration.nix
        ];
      };
    };
}