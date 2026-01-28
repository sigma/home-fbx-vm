{ config, pkgs, lib, ... }:

let
  # Constants only - no config access
  containerName = "home-assistant";
  userName = "hass";
in
{
  options.fbx.services.home-assistant = {
    enable = lib.mkEnableOption "Home Assistant container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "Port for Home Assistant web interface";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Paris";
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
      default = "/var/lib/${userName}";
      description = "Directory for Home Assistant persistent data";
    };
  };

  config = lib.mkIf config.fbx.services.home-assistant.enable {
    # Host user/group
    users.users.${userName} = {
      isSystemUser = true;
      group = userName;
      uid = config.fbx.users.uidFor userName;
    };
    users.groups.${userName}.gid = config.fbx.users.uidFor userName;

    # Data directory
    systemd.tmpfiles.rules = [
      "d ${config.fbx.services.home-assistant.dataDir} 0750 ${userName} ${userName} -"
    ];

    # Port forwarding for tailscale serve
    systemd.services."${userName}-port-forward" = {
      description = "Forward localhost:${toString config.fbx.services.home-assistant.port} to ${userName} container";
      after = [ "network.target" "container@${containerName}.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString config.fbx.services.home-assistant.port},fork,reuseaddr TCP:${(config.fbx.containers.networkFor containerName).localAddress}:${toString config.fbx.services.home-assistant.port}";
        Restart = "always";
      };
    };

    # Container
    containers.${containerName} = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = (config.fbx.containers.networkFor containerName).hostAddress;
      localAddress = (config.fbx.containers.networkFor containerName).localAddress;

      bindMounts."${config.fbx.services.home-assistant.dataDir}" = {
        hostPath = config.fbx.services.home-assistant.dataDir;
        isReadOnly = false;
      };

      config = { config, pkgs, lib, ... }: {
        # DNS
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;

        # User
        users.users.${userName} = {
          isSystemUser = true;
          group = userName;
        };
        users.groups.${userName} = {};

        services.home-assistant = {
          enable = true;
          openFirewall = true;
          extraComponents = [
            "default_config"
            "met"
            "esphome"
          ];
          config = {
            homeassistant = {
              name = "Home";
              unit_system = "metric";
              time_zone = "Europe/Paris";
            };
            http = {
              server_port = 8123;
              use_x_forwarded_for = true;
              trusted_proxies = [ "192.168.100.1" ];
            };
          };
        };

        system.stateVersion = "25.11";
      };
    };

    networking.firewall.allowedTCPPorts = [ config.fbx.services.home-assistant.port ];
  };
}
