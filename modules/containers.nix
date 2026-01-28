{ config, lib, ... }:

let
  cfg = config.fbx.containers;

  # Convert registry attrset to sorted list for stable IP allocation
  containerNames = lib.naturalSort (lib.attrNames cfg.registry);

  # Compute address for a container based on its position in sorted list
  addressIndex = name:
    let idx = lib.lists.findFirstIndex (n: n == name) null containerNames;
    in if idx == null
       then throw "Container '${name}' not found in registry"
       else idx;

  computeAddress = name:
    let
      parts = lib.splitString "." cfg.network.hostAddress;
      baseOctets = lib.take 3 parts;
      hostOctet = cfg.network.baseAddress + (addressIndex name);
    in lib.concatStringsSep "." (baseOctets ++ [ (toString hostOctet) ]);

  # Build registry with computed addresses
  registryWithAddresses = lib.mapAttrs (name: value: value // {
    address = value.address or (computeAddress name);
  }) cfg.registry;

in
{
  options.fbx.containers = {
    network = {
      hostAddress = lib.mkOption {
        type = lib.types.str;
        default = "192.168.100.1";
        description = "Host-side IP address for all container veth pairs";
      };

      baseAddress = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Starting last octet for container addresses (first container gets this)";
      };
    };

    registry = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Explicit IP address override (auto-allocated if null)";
          };
        };
      });
      default = {};
      description = "Registry of containers and their network configuration";
    };

    # Computed values available to other modules
    addressFor = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      readOnly = true;
      description = "Function to get the IP address for a container by name";
    };

    networkFor = lib.mkOption {
      type = lib.types.functionTo (lib.types.attrsOf lib.types.str);
      readOnly = true;
      description = "Function to get hostAddress and localAddress for a container";
    };

    addresses = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Map of container names to their addresses";
    };
  };

  config.fbx.containers = {
    addressFor = name: registryWithAddresses.${name}.address;

    networkFor = name: {
      hostAddress = cfg.network.hostAddress;
      localAddress = cfg.addressFor name;
    };

    addresses = lib.mapAttrs (name: value: value.address) registryWithAddresses;
  };
}
