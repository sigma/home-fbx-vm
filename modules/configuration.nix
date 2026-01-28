{ pkgs, lib, ... }:

let
  keys = import ./keys.nix;
in
{
  imports = [
    ./lib
    ./containers.nix
    ./network.nix
    ./users.nix
    ./sops.nix
    ./services
  ];

  # NixOS configuration for Freebox VM
  # Base hardware config and stateVersion are provided by the flake-parts module

  networking.hostName = "freebox-vm";
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Regular user
  users.users.yann = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = keys.allKeysFor keys.users.yann;
  };

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Minimal packages
  environment.systemPackages = with pkgs; [
    zile
    git
    htop
    tmux
  ];

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Network
  fbx.network.tailscale.enable = true;

  # Service users/groups (centralized UID/GID allocation)
  fbx.users.serviceUsers = {
    hass = { uid = 400; description = "Home Assistant"; };
    hummingbot = { uid = 401; description = "Hummingbot trading bot"; };
  };
  fbx.users.serviceGroups = {
    hass = { gid = 400; description = "Home Assistant"; };
    hummingbot = { gid = 401; description = "Hummingbot trading bot"; };
  };

  # Services
  fbx.services.home-assistant.enable = true;
  fbx.services.hummingbot.enable = true;
}
