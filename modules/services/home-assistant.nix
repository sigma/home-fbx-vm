{ config, pkgs, lib, ... }:

let
  cfg = config.fbx.services.home-assistant;
in
{
  options.fbx.services.home-assistant = {
    enable = lib.mkEnableOption "Home Assistant container";

    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.100.1";
      description = "Host-side IP address for the container network";
    };

    localAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.100.2";
      description = "Container-side IP address";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "Port for Home Assistant web interface";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = config.time.timeZone;
      description = "Time zone for Home Assistant";
    };

    extraComponents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "default_config"
        "met"
        "esphome"
      ];
      description = "Extra Home Assistant components to enable";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hass";
      description = "Directory for Home Assistant persistent data";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 400;
      description = "UID for the hass user (must match between host and container)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create hass user/group on host (matching container) for bind mount permissions
    users.users.hass = {
      isSystemUser = true;
      group = "hass";
      uid = cfg.uid;
    };
    users.groups.hass.gid = cfg.uid;

    # Ensure data directory exists on host with correct ownership
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 hass hass -"
    ];

    # Forward localhost port to container (for tailscale serve)
    systemd.services.hass-port-forward = {
      description = "Forward localhost:${toString cfg.port} to Home Assistant container";
      after = [ "network.target" "container@home-assistant.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString cfg.port},fork,reuseaddr TCP:${cfg.localAddress}:${toString cfg.port}";
        Restart = "always";
      };
    };

    # Home Assistant container
    containers.home-assistant = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = cfg.hostAddress;
      localAddress = cfg.localAddress;

      # Bind mount for persistent config
      bindMounts."${cfg.dataDir}" = {
        hostPath = cfg.dataDir;
        isReadOnly = false;
      };

      config = { config, pkgs, lib, ... }: {
        # Fix DNS resolution in container
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;

        # Match hass user UID/GID with host for bind mount
        users.users.hass.uid = lib.mkForce cfg.uid;
        users.groups.hass.gid = lib.mkForce cfg.uid;

        # Home Assistant service
        services.home-assistant = {
          enable = true;
          openFirewall = true;
          extraComponents = cfg.extraComponents;
          config = {
            homeassistant = {
              name = "Home";
              unit_system = "metric";
              time_zone = cfg.timeZone;
            };
            http = {
              server_port = cfg.port;
              use_x_forwarded_for = true;
              trusted_proxies = [ cfg.hostAddress ];
            };
          };
        };

        system.stateVersion = "25.11";
      };
    };

    # Allow port through firewall
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
