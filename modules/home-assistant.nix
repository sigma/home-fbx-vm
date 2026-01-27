{ pkgs, lib, ... }:

{
  # Create hass user/group on host (matching container) for bind mount permissions
  users.users.hass = {
    isSystemUser = true;
    group = "hass";
    uid = 400;  # Fixed UID to match container
  };
  users.groups.hass.gid = 400;

  # Ensure /var/lib/hass exists on host with correct ownership
  systemd.tmpfiles.rules = [
    "d /var/lib/hass 0750 hass hass -"
  ];

  # NAT for container networking
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "tailscale0";
  };

  # Forward localhost:8123 to container (for tailscale serve)
  systemd.services.hass-port-forward = {
    description = "Forward localhost:8123 to Home Assistant container";
    after = [ "network.target" "container@home-assistant.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:8123,fork,reuseaddr TCP:192.168.100.2:8123";
      Restart = "always";
    };
  };

  # Home Assistant container
  containers.home-assistant = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.2";

    # Bind mount for persistent config
    bindMounts."/var/lib/hass" = {
      hostPath = "/var/lib/hass";
      isReadOnly = false;
    };

    # USB passthrough (uncomment when needed):
    # allowedDevices = [
    #   { modifier = "rw"; node = "/dev/ttyUSB0"; }  # Example: Zigbee dongle
    #   { modifier = "rw"; node = "/dev/ttyACM0"; }  # Example: Z-Wave dongle
    # ];

    config = { config, pkgs, lib, ... }: {
      # Fix DNS resolution in container
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;

      # Match hass user UID/GID with host for bind mount
      users.users.hass.uid = lib.mkForce 400;
      users.groups.hass.gid = lib.mkForce 400;

      # Home Assistant service
      services.home-assistant = {
        enable = true;
        openFirewall = true;
        extraComponents = [
          # Common components - can be expanded
          "default_config"
          "met"       # Weather
          "esphome"   # ESPHome devices
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

  # Allow port 8123 through firewall
  networking.firewall.allowedTCPPorts = [ 8123 ];
}
