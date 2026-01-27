{ pkgs, lib, ... }:

{
  # Create hummingbot user/group on host (matching container) for bind mount permissions
  users.users.hummingbot = {
    isSystemUser = true;
    group = "hummingbot";
    uid = 401;  # Fixed UID to match container
  };
  users.groups.hummingbot.gid = 401;

  # Ensure /var/lib/hummingbot exists on host with correct ownership
  systemd.tmpfiles.rules = [
    "d /var/lib/hummingbot 0750 hummingbot hummingbot -"
    "d /var/lib/hummingbot/conf 0750 hummingbot hummingbot -"
    "d /var/lib/hummingbot/logs 0750 hummingbot hummingbot -"
    "d /var/lib/hummingbot/data 0750 hummingbot hummingbot -"
    "d /var/lib/hummingbot/scripts 0750 hummingbot hummingbot -"
    "d /var/lib/hummingbot/certs 0750 hummingbot hummingbot -"
    "d /var/lib/hummingbot/gateway 0750 hummingbot hummingbot -"
  ];

  # Forward localhost:15888 to container (for tailscale serve if needed)
  systemd.services.hummingbot-gateway-forward = {
    description = "Forward localhost:15888 to Hummingbot Gateway container";
    after = [ "network.target" "container@hummingbot.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:15888,fork,reuseaddr TCP:192.168.100.3:15888";
      Restart = "always";
    };
  };

  # Hummingbot container
  containers.hummingbot = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.3";

    # Bind mount for persistent data
    bindMounts."/var/lib/hummingbot" = {
      hostPath = "/var/lib/hummingbot";
      isReadOnly = false;
    };

    config = { config, pkgs, lib, ... }:
      let
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
      in {
        # Fix DNS resolution in container
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;

        # Match hummingbot user UID/GID with host for bind mount
        users.users.hummingbot = {
          isSystemUser = true;
          group = "hummingbot";
          uid = lib.mkForce 401;
          home = "/var/lib/hummingbot";
        };
        users.groups.hummingbot.gid = lib.mkForce 401;

        # Hummingbot service
        systemd.services.hummingbot = {
          description = "Hummingbot Trading Bot";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            User = "hummingbot";
            Group = "hummingbot";
            WorkingDirectory = "/var/lib/hummingbot";
            ExecStart = "${hummingbot}/bin/hummingbot";
            Restart = "on-failure";
            RestartSec = 10;
          };

          environment = {
            HOME = "/var/lib/hummingbot";
          };
        };

        # Gateway service
        systemd.services.hummingbot-gateway = {
          description = "Hummingbot Gateway";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            User = "hummingbot";
            Group = "hummingbot";
            WorkingDirectory = "/var/lib/hummingbot/gateway";
            ExecStart = "${gateway}/bin/hummingbot-gateway";
            Restart = "always";
            RestartSec = 5;
          };

          environment = {
            GATEWAY_PASSPHRASE = "admin";  # TODO: use secrets manager
            PORT = "15888";
          };
        };

        # Open ports inside container
        networking.firewall.allowedTCPPorts = [ 15888 ];

        system.stateVersion = "25.11";
      };
  };

  # Allow gateway port through host firewall
  networking.firewall.allowedTCPPorts = [ 15888 ];
}
