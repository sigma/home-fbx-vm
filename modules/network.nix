{ config, lib, ... }:

let
  cfg = config.fbx.network;
in
{
  options.fbx.network = {
    tailscale = {
      enable = lib.mkEnableOption "Tailscale VPN";

      useRoutingFeatures = lib.mkOption {
        type = lib.types.enum [ "none" "client" "server" "both" ];
        default = "server";
        description = "Tailscale routing features (server needed for subnet routing/serve)";
      };

      trustInterface = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Trust the tailscale0 interface in the firewall";
      };
    };

    containerNat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NAT for container networking";
      };

      internalInterfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "ve-+" ];
        description = "Internal interfaces to NAT (ve-+ matches all container veths)";
      };

      externalInterface = lib.mkOption {
        type = lib.types.str;
        default = if cfg.tailscale.enable then "tailscale0" else "eth0";
        defaultText = lib.literalExpression ''if cfg.tailscale.enable then "tailscale0" else "eth0"'';
        description = "External interface for NAT (defaults to tailscale0 if Tailscale enabled, eth0 otherwise)";
      };
    };
  };

  config = lib.mkMerge [
    # Tailscale configuration
    (lib.mkIf cfg.tailscale.enable {
      services.tailscale = {
        enable = true;
        useRoutingFeatures = cfg.tailscale.useRoutingFeatures;
      };

      networking.firewall.trustedInterfaces =
        lib.mkIf cfg.tailscale.trustInterface [ "tailscale0" ];
    })

    # Container NAT configuration
    (lib.mkIf cfg.containerNat.enable {
      networking.nat = {
        enable = true;
        internalInterfaces = cfg.containerNat.internalInterfaces;
        externalInterface = cfg.containerNat.externalInterface;
      };
    })
  ];
}
