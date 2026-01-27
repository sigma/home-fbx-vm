{ pkgs, ... }:

{
  # Minimal NixOS configuration for Freebox VM
  # Base hardware config and stateVersion are provided by the flake-parts module

  networking.hostName = "freebox-vm";
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Regular user
  users.users.yann = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCH9S6aF3W4/pKY+s/FpZAl8zIXXxI7LHE4fVd+foYdXtQI2mhiIyBX4jtbYkhACOSha5i2TPYKpBqy3NtI/utc="
    ];
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
}
