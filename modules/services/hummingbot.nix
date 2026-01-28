{ config, pkgs, lib, ... }:

let
  # Constants
  containerName = "hummingbot";
  userName = "hummingbot";

  cfg = config.fbx.services.hummingbot;
  fbxLib = config.fbx.lib;
  containerNet = config.fbx.containers.networkFor containerName;
  uid = config.fbx.users.uidFor userName;
in
{
  options.fbx.services.hummingbot = {
    enable = lib.mkEnableOption "Hummingbot trading bot container";

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 15888;
      description = "Port for Hummingbot Gateway API";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/${userName}";
      description = "Directory for Hummingbot persistent data";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Auto-register in container registry
    { fbx.containers.registry.${containerName} = {}; }

    # Host user/group
    (fbxLib.mkServiceUser { name = userName; uid = uid; })

    # Data directories
    (fbxLib.mkDataDirs {
      user = userName;
      dirs = [
        cfg.dataDir
        "${cfg.dataDir}/conf"
        "${cfg.dataDir}/logs"
        "${cfg.dataDir}/data"
        "${cfg.dataDir}/scripts"
        "${cfg.dataDir}/certs"
        "${cfg.dataDir}/gateway"
      ];
    })

    # Container and secrets
    {
      containers.${containerName} = {
        autoStart = true;
        privateNetwork = true;
        inherit (containerNet) hostAddress localAddress;

        bindMounts."${cfg.dataDir}" = {
          hostPath = cfg.dataDir;
          isReadOnly = false;
        };

        bindMounts."/run/secrets/gateway-passphrase" = {
          hostPath = config.sops.secrets."${userName}/gateway-passphrase".path;
          isReadOnly = true;
        };

        config = { config, pkgs, lib, ... }: lib.mkMerge [
          fbxLib.containerDnsConfig
          (fbxLib.mkContainerUser { name = userName; uid = uid; home = cfg.dataDir; })
          {
            systemd.services.${containerName} = {
              description = "Hummingbot Trading Bot";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = userName;
                Group = userName;
                WorkingDirectory = cfg.dataDir;
                ExecStart = "${pkgs.hummingbot}/bin/hummingbot";
                Restart = "on-failure";
                RestartSec = 10;
              };

              environment = {
                HOME = cfg.dataDir;
              };
            };

            systemd.services."${containerName}-gateway" = {
              description = "Hummingbot Gateway";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = userName;
                Group = userName;
                WorkingDirectory = "${cfg.dataDir}/gateway";
                Restart = "always";
                RestartSec = 5;
              };

              script = ''
                export GATEWAY_PASSPHRASE="$(cat /run/secrets/gateway-passphrase)"
                exec ${pkgs.hummingbot-gateway}/bin/hummingbot-gateway
              '';

              environment = {
                PORT = toString cfg.gatewayPort;
              };
            };

            networking.firewall.allowedTCPPorts = [ cfg.gatewayPort ];

            system.stateVersion = "25.11";
          }
        ];
      };

      sops.secrets."${userName}/gateway-passphrase" = {
        owner = userName;
        group = userName;
        mode = "0400";
      };
    }
  ]);
}
