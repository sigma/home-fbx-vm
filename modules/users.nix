{ config, lib, ... }:

let
  cfg = config.fbx.users;

  # Collect all UIDs to check for duplicates
  allUids = lib.mapAttrsToList (name: user: { inherit name; uid = user.uid; }) cfg.serviceUsers;
  uidValues = map (u: u.uid) allUids;
  duplicateUids = lib.filter (uid: lib.count (x: x == uid) uidValues > 1) uidValues;

  # Collect all GIDs
  allGids = lib.mapAttrsToList (name: group: { inherit name; gid = group.gid; }) cfg.serviceGroups;
  gidValues = map (g: g.gid) allGids;
  duplicateGids = lib.filter (gid: lib.count (x: x == gid) gidValues > 1) gidValues;

in
{
  options.fbx.users = {
    serviceUsers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          uid = lib.mkOption {
            type = lib.types.int;
            description = "UID for the service user";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Description of what this user is for";
          };
        };
      });
      default = {};
      description = "Registry of service users with their UIDs";
    };

    serviceGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          gid = lib.mkOption {
            type = lib.types.int;
            description = "GID for the service group";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Description of what this group is for";
          };
        };
      });
      default = {};
      description = "Registry of service groups with their GIDs";
    };

    # Helper to get UID for a user
    uidFor = lib.mkOption {
      type = lib.types.functionTo lib.types.int;
      readOnly = true;
      description = "Function to get UID for a service user";
    };

    # Helper to get GID for a group
    gidFor = lib.mkOption {
      type = lib.types.functionTo lib.types.int;
      readOnly = true;
      description = "Function to get GID for a service group";
    };
  };

  config = {
    # Assertions for uniqueness
    assertions = [
      {
        assertion = duplicateUids == [];
        message = "Duplicate UIDs found in fbx.users.serviceUsers: ${toString (lib.unique duplicateUids)}";
      }
      {
        assertion = duplicateGids == [];
        message = "Duplicate GIDs found in fbx.users.serviceGroups: ${toString (lib.unique duplicateGids)}";
      }
    ];

    fbx.users = {
      uidFor = name:
        if cfg.serviceUsers ? ${name}
        then cfg.serviceUsers.${name}.uid
        else throw "Service user '${name}' not found in fbx.users.serviceUsers";

      gidFor = name:
        if cfg.serviceGroups ? ${name}
        then cfg.serviceGroups.${name}.gid
        else throw "Service group '${name}' not found in fbx.users.serviceGroups";
    };
  };
}
