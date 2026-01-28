# Freebox VM NixOS Configuration

NixOS configuration for a VM running on Freebox.

## Network

Network configuration is defined in `modules/network.nix`:

```nix
fbx.network.tailscale.enable = true;
# fbx.network.containerNat.enable = true;  # enabled by default
```

### Tailscale

Options under `fbx.network.tailscale`:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable Tailscale VPN |
| `useRoutingFeatures` | `"server"` | Routing features (server needed for subnet routing/serve) |
| `trustInterface` | `true` | Trust tailscale0 in firewall |

### Container NAT

Options under `fbx.network.containerNat`:

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `true` | Enable NAT for container networking |
| `internalInterfaces` | `["ve-+"]` | Internal interfaces to NAT |
| `externalInterface` | `"tailscale0"` or `"eth0"` | External interface (tailscale0 if Tailscale enabled, eth0 otherwise) |

## Containers

Container networking is managed centrally in `modules/containers.nix`. Services auto-register and receive IP addresses automatically.

### Configuration

```nix
fbx.containers.network = {
  hostAddress = "192.168.100.1";  # Host side of veth pairs
  baseAddress = 2;                # First container gets .2
};
```

### Address Allocation

IPs are allocated based on sorted container names:

| Container | Address |
|-----------|---------|
| home-assistant | 192.168.100.2 |
| hummingbot | 192.168.100.3 |

### Service Integration

Services auto-register by adding to the registry:

```nix
# In a service module
config = lib.mkIf cfg.enable (lib.mkMerge [
  { fbx.containers.registry.my-service = {}; }
  # ...
]);
```

Then use the allocated address:

```nix
let
  containerNet = config.fbx.containers.networkFor "my-service";
in {
  containers.my-service = {
    inherit (containerNet) hostAddress localAddress;
    # ...
  };
}
```

### Cross-Container Communication

Services can reference other containers' addresses:

```nix
# Get another container's address
config.fbx.containers.addressFor "hummingbot"  # "192.168.100.3"

# Or via the registry
config.fbx.containers.addresses.hummingbot     # "192.168.100.3"
```

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
