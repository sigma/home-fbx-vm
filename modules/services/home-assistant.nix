{ config, pkgs, lib, ... }:

let
  # Constants
  containerName = "home-assistant";
  userName = "hass";

  cfg = config.fbx.services.home-assistant;
  fbxLib = config.fbx.lib;
  containerNet = config.fbx.containers.networkFor containerName;
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
      default = "/var/lib/${userName}";
      description = "Directory for Home Assistant persistent data";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 400;
      description = "UID for the ${userName} user (must match between host and container)";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Auto-register in container registry
    { fbx.containers.registry.${containerName} = {}; }

    # Host user/group
    (fbxLib.mkServiceUser { name = userName; uid = cfg.uid; })

    # Data directory
    (fbxLib.mkDataDirs { user = userName; dirs = [ cfg.dataDir ]; })

    # Port forwarding for tailscale serve
    (fbxLib.mkPortForward {
      name = userName;
      port = cfg.port;
      targetAddress = containerNet.localAddress;
      inherit containerName;
    })

    # Container and firewall
    {
      containers.${containerName} = {
        autoStart = true;
        privateNetwork = true;
        inherit (containerNet) hostAddress localAddress;

        bindMounts."${cfg.dataDir}" = {
          hostPath = cfg.dataDir;
          isReadOnly = false;
        };

        config = { config, pkgs, lib, ... }: lib.mkMerge [
          fbxLib.containerDnsConfig
          (fbxLib.mkContainerUser { name = userName; uid = cfg.uid; })
          {
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
                  trusted_proxies = [ containerNet.hostAddress ];
                };
              };
            };

            system.stateVersion = "25.11";
          }
        ];
      };

      networking.firewall.allowedTCPPorts = [ cfg.port ];
    }
  ]);
}
