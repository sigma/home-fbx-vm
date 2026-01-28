{
  # Centralized SSH public keys for the system
  # Used for both user authentication and sops-nix secret encryption

  users = {
    yann = {
      # Primary key for sops encryption/decryption
      ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOk2ssX0+PedgzjBV87OZtHIKl6G4EVaSkbLZ7GDkHH1";
      # Legacy key
      ecdsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCH9S6aF3W4/pKY+s/FpZAl8zIXXxI7LHE4fVd+foYdXtQI2mhiIyBX4jtbYkhACOSha5i2TPYKpBqy3NtI/utc=";
    };
  };

  # Helper to get all keys for a user as a list
  allKeysFor = user: with user; [ ed25519 ecdsa ];
}
