{ config, pkgs, lib, ... }:

let
  cfg = config.fbx.services.hummingbot;
  fbxLib = config.fbx.lib;

  # Hummingbot Python package
  hummingbot = pkgs.python3Packages.buildPythonApplication rec {
    pname = "hummingbot";
    version = "2.12.0";
    format = "setuptools";

    src = pkgs.fetchFromGitHub {
      owner = "hummingbot";
      repo = "hummingbot";
      rev = "v${version}";
      hash = "sha256-yxNJtkM3Rrc9TwwCI8Ko8CKrER4yICCZ9Q/WYMymYmY=";
    };

    nativeBuildInputs = with pkgs; [
      python3Packages.cython
      python3Packages.numpy
    ];

    buildInputs = with pkgs; [
      stdenv.cc.cc.lib
    ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      aiohttp
      numpy
      pandas
      scipy
      web3
      sqlalchemy
      pydantic
      cryptography
      protobuf
      pyyaml
      requests
      websockets
      ujson
    ];

    doCheck = false;

    preBuild = ''
      export HOME=$TMPDIR
    '';

    meta = with lib; {
      description = "Open-source framework for automated trading strategies";
      homepage = "https://hummingbot.org";
      license = licenses.asl20;
    };
  };

  # Gateway TypeScript/Node.js package (uses pnpm)
  gateway = pkgs.stdenv.mkDerivation rec {
    pname = "hummingbot-gateway";
    version = "2.12.0";

    src = pkgs.fetchFromGitHub {
      owner = "hummingbot";
      repo = "gateway";
      rev = "v${version}";
      hash = "sha256-Z0uB1/7AqPad0ZvmLRly4xpKm4xTuBRRcqo/KaiKn08=";
    };

    pnpmDeps = pkgs.pnpm_9.fetchDeps {
      inherit pname version src;
      fetcherVersion = 3;
      hash = "sha256-EK7Rxr6swq9tcUCAQglkKccRJd8TFPjmS0bse3cg4t8=";
    };

    nativeBuildInputs = with pkgs; [
      nodejs_20
      pnpm_9.configHook
      python3
      pkg-config
    ];

    buildInputs = with pkgs; [
      libusb1
    ];

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/gateway
      cp -r dist node_modules package.json $out/lib/gateway/
      mkdir -p $out/bin
      cat > $out/bin/hummingbot-gateway <<'EOF'
      #!${pkgs.runtimeShell}
      exec ${pkgs.nodejs_20}/bin/node ${placeholder "out"}/lib/gateway/dist/index.js "$@"
      EOF
      chmod +x $out/bin/hummingbot-gateway
      patchShebangs $out/bin
      runHook postInstall
    '';

    meta = with lib; {
      description = "API server for DEX and blockchain interactions";
      homepage = "https://github.com/hummingbot/gateway";
      license = licenses.asl20;
    };
  };
in
{
  options.fbx.services.hummingbot = {
    enable = lib.mkEnableOption "Hummingbot trading bot container";

    hostAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.100.1";
      description = "Host-side IP address for the container network";
    };

    localAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.100.3";
      description = "Container-side IP address";
    };

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
        hostAddress = cfg.hostAddress;
        localAddress = cfg.localAddress;

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
                ExecStart = "${hummingbot}/bin/hummingbot";
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
                exec ${gateway}/bin/hummingbot-gateway
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
