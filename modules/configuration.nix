{ pkgs, lib, ... }:

let
  keys = import ./keys.nix;
in
{
  imports = [
    ./lib
    ./containers.nix
    ./network.nix
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

  # Services
  fbx.services.home-assistant.enable = true;
  fbx.services.hummingbot.enable = true;
}
