{ config, pkgs, lib, ... }:

let
  # Constants only - no config access
  containerName = "hummingbot";
  userName = "hummingbot";
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

  config = lib.mkIf config.fbx.services.hummingbot.enable {
    # Host user/group
    users.users.${userName} = {
      isSystemUser = true;
      group = userName;
      uid = config.fbx.users.uidFor userName;
    };
    users.groups.${userName}.gid = config.fbx.users.uidFor userName;

    # Data directories
    systemd.tmpfiles.rules =
      let cfg = config.fbx.services.hummingbot;
      in map (dir: "d ${dir} 0750 ${userName} ${userName} -") [
        cfg.dataDir
        "${cfg.dataDir}/conf"
        "${cfg.dataDir}/logs"
        "${cfg.dataDir}/data"
        "${cfg.dataDir}/scripts"
        "${cfg.dataDir}/certs"
        "${cfg.dataDir}/gateway"
      ];

    # Container
    containers.${containerName} = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = (config.fbx.containers.networkFor containerName).hostAddress;
      localAddress = (config.fbx.containers.networkFor containerName).localAddress;

      bindMounts."${config.fbx.services.hummingbot.dataDir}" = {
        hostPath = config.fbx.services.hummingbot.dataDir;
        isReadOnly = false;
      };

      bindMounts."/run/secrets/gateway-passphrase" = {
        hostPath = config.sops.secrets."${userName}/gateway-passphrase".path;
        isReadOnly = true;
      };

      config = { pkgs, ... }: lib.mkMerge [
        config.fbx.lib.containerBaseConfig
        {
          # User
          users.users.${userName} = {
            isSystemUser = true;
            group = userName;
          };
          users.groups.${userName} = {};

          systemd.services.${containerName} = {
            description = "Hummingbot Trading Bot";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "simple";
              User = userName;
              Group = userName;
              WorkingDirectory = "/var/lib/${userName}";
              ExecStart = "${pkgs.hummingbot}/bin/hummingbot";
              Restart = "on-failure";
              RestartSec = 10;
            };

            environment = {
              HOME = "/var/lib/${userName}";
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
              WorkingDirectory = "/var/lib/${userName}/gateway";
              Restart = "always";
              RestartSec = 5;
            };

            script = ''
              export GATEWAY_PASSPHRASE="$(cat /run/secrets/gateway-passphrase)"
              exec ${pkgs.hummingbot-gateway}/bin/hummingbot-gateway
            '';

            environment = {
              PORT = "15888";
            };
          };

          networking.firewall.allowedTCPPorts = [ 15888 ];
        }
      ];
    };

    sops.secrets."${userName}/gateway-passphrase" = {
      owner = userName;
      group = userName;
      mode = "0400";
    };
  };
}
