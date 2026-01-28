{ config, pkgs, lib, ... }:

let
  cfg = config.fbx.services.hummingbot;
  fbxLib = config.fbx.lib;
  containerNet = config.fbx.containers.networkFor "hummingbot";
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
      default = "/var/lib/hummingbot";
      description = "Directory for Hummingbot persistent data";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 401;
      description = "UID for the hummingbot user (must match between host and container)";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Auto-register in container registry
    { fbx.containers.registry.hummingbot = {}; }

    # Host user/group
    (fbxLib.mkServiceUser { name = "hummingbot"; uid = cfg.uid; })

    # Data directories
    (fbxLib.mkDataDirs {
      user = "hummingbot";
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
      containers.hummingbot = {
        autoStart = true;
        privateNetwork = true;
        inherit (containerNet) hostAddress localAddress;

        bindMounts."${cfg.dataDir}" = {
          hostPath = cfg.dataDir;
          isReadOnly = false;
        };

        bindMounts."/run/secrets/gateway-passphrase" = {
          hostPath = config.sops.secrets."hummingbot/gateway-passphrase".path;
          isReadOnly = true;
        };

        config = { config, pkgs, lib, ... }: lib.mkMerge [
          fbxLib.containerDnsConfig
          (fbxLib.mkContainerUser { name = "hummingbot"; uid = cfg.uid; home = cfg.dataDir; })
          {
            systemd.services.hummingbot = {
              description = "Hummingbot Trading Bot";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = "hummingbot";
                Group = "hummingbot";
                WorkingDirectory = cfg.dataDir;
                ExecStart = "${pkgs.hummingbot}/bin/hummingbot";
                Restart = "on-failure";
                RestartSec = 10;
              };

              environment = {
                HOME = cfg.dataDir;
              };
            };

            systemd.services.hummingbot-gateway = {
              description = "Hummingbot Gateway";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = "hummingbot";
                Group = "hummingbot";
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

      sops.secrets."hummingbot/gateway-passphrase" = {
        owner = "hummingbot";
        group = "hummingbot";
        mode = "0400";
      };
    }
  ]);
}
