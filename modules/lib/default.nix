{ config, pkgs, lib, fbxOverlay ? null, ... }:

{
  options.fbx.lib = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Helper functions for fbx modules";
  };

  # Store overlay for use by other modules
  options.fbx.pkgs.overlay = lib.mkOption {
    type = lib.types.nullOr (lib.types.functionTo (lib.types.functionTo lib.types.attrs));
    default = fbxOverlay;
    description = "The packages overlay for this configuration";
  };

  config.fbx.lib = {
    # Create a system user and group with matching UID/GID on the host
    # for bind mount permissions with containers
    mkServiceUser = { name, uid, home ? null }: {
      users.users.${name} = {
        isSystemUser = true;
        group = name;
        inherit uid;
      } // lib.optionalAttrs (home != null) { inherit home; };
      users.groups.${name}.gid = uid;
    };

    # Create a socat port forwarding service
    mkPortForward = {
      name,
      port,
      targetAddress,
      containerName ? name,
      description ? "Forward localhost:${toString port} to ${name} container"
    }: {
      systemd.services."${name}-port-forward" = {
        inherit description;
        after = [ "network.target" "container@${containerName}.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString port},fork,reuseaddr TCP:${targetAddress}:${toString port}";
          Restart = "always";
        };
      };
    };

    # Create tmpfiles rules for data directories
    mkDataDirs = { user, dirs }: {
      systemd.tmpfiles.rules = map (dir: "d ${dir} 0750 ${user} ${user} -") dirs;
    };

    # Common container base configuration (overlay + DNS + stateVersion)
    containerBaseConfig = lib.mkMerge [
      {
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        system.stateVersion = "25.11";
      }
      (lib.mkIf (config.fbx.pkgs.overlay != null) {
        nixpkgs.overlays = [ config.fbx.pkgs.overlay ];
      })
    ];

    # Deprecated: use containerBaseConfig instead
    containerDnsConfig = {
      networking.useHostResolvConf = lib.mkForce false;
      services.resolved.enable = true;
    };

    # Create matching user inside container
    mkContainerUser = { name, uid, home ? null }: {
      users.users.${name} = {
        isSystemUser = true;
        group = name;
        uid = lib.mkForce uid;
      } // lib.optionalAttrs (home != null) { inherit home; };
      users.groups.${name}.gid = lib.mkForce uid;
    };
  };
}
