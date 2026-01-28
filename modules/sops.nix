{ config, ... }:

{
  # sops-nix configuration
  # Secrets are decrypted at activation time using the host's SSH key

  sops = {
    # Default sops file for secrets
    defaultSopsFile = ../secrets/secrets.yaml;

    # Use the host's SSH key for decryption at runtime
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # Service-specific secrets are defined in their respective modules
}
