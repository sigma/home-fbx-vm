{
  inputs = {
    fbx-vm.url = "github:firefly-engineering/fbx-vm";

    nixpkgs.follows = "fbx-vm/nixpkgs";
    flake-parts.follows = "fbx-vm/flake-parts";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };


  outputs = inputs @ { self, flake-parts, fbx-vm, nixpkgs, sops-nix, ... }:
    let
      overlay = import ./pkgs;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        fbx-vm.flakeModules.freebox
      ];

      systems = [
        "aarch64-linux"
      ];

      flake.overlays.default = overlay;

      perSystem = { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in {
          packages = {
            inherit (pkgs) hummingbot hummingbot-gateway;
          };
        };

      freebox.vm = {
        enable = true;
        modules = [
          sops-nix.nixosModules.sops
          {
            nixpkgs.overlays = [ overlay ];
            # Make overlay available to all modules via _module.args
            _module.args.fbxOverlay = overlay;
          }
          ./modules/configuration.nix
        ];
      };
    };
}