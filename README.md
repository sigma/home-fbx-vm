# Freebox VM NixOS Configuration

NixOS configuration for a VM running on Freebox.

## Services

Services are defined in `modules/services/` and enabled via options in `modules/configuration.nix`:

```nix
fbx.services.home-assistant.enable = true;
fbx.services.hummingbot.enable = true;
```

### Home Assistant

Options under `fbx.services.home-assistant`:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable Home Assistant container |
| `port` | `8123` | Web interface port |
| `timeZone` | system timezone | Time zone |
| `extraComponents` | `["default_config" "met" "esphome"]` | HA components |
| `dataDir` | `/var/lib/hass` | Persistent data directory |

### Hummingbot

Options under `fbx.services.hummingbot`:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable Hummingbot container |
| `gatewayPort` | `15888` | Gateway API port |
| `dataDir` | `/var/lib/hummingbot` | Persistent data directory |

## Secrets Management

This project uses [sops-nix](https://github.com/Mic92/sops-nix) for secrets management. Secrets are encrypted with age keys and decrypted at runtime on the VM.

### Initial Setup

1. Create the encrypted secrets file:
   ```bash
   cp secrets/secrets.yaml.template secrets/secrets.yaml
   nix run nixpkgs#sops -- secrets/secrets.yaml
   ```

2. Edit the secrets in your editor, save, and sops will encrypt the file.

### Adding the VM Host Key

After the VM's first boot, add its SSH host key to enable runtime decryption:

1. Get the VM's age public key:
   ```bash
   ssh freebox-vm "cat /etc/ssh/ssh_host_ed25519_key.pub" | nix run nixpkgs#ssh-to-age
   ```

2. Edit `.sops.yaml` and add the host key:
   ```yaml
   keys:
     # ...existing keys...
     - &freebox-vm age1<output-from-step-1>
   ```

3. Uncomment the `freebox-vm` references in the `creation_rules` section.

4. Re-encrypt secrets with the new key:
   ```bash
   nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml
   ```

### Editing Secrets

To edit existing secrets:
```bash
nix run nixpkgs#sops -- secrets/secrets.yaml
```

### Adding New Secrets

1. Add the secret to `secrets/secrets.yaml`
2. Define it in the relevant service module (e.g., `modules/services/hummingbot.nix`)
3. Reference it via `config.sops.secrets.<name>.path`
