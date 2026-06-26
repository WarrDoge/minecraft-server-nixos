# WarrDoge Minecraft Server (NixOS)

Nix flake for a Minecraft server running the **All Create** modpack on **Neoforge**.

Managed via **comin** (gitops pull) + **sops-nix** (secrets).

## Structure

```
.
├── flake.nix                    # Flake entry point
├── .sops.yaml                   # Sops key config
├── hosts/
│   ├── comin.nix                # Comin module (gitops auto-deploy)
│   ├── sops-base.nix            # Sops-nix base config
│   └── minecraft-server/
│       └── configuration.nix    # Host-specific config
├── services/
│   └── minecraft-server/
│       └── default.nix          # Neoforge + modpack service
└── secrets.yaml                 # Encrypted secrets
```

## Quick Start (first install)

```bash
# 1. Boot minimal NixOS ISO on target machine
# 2. Generate hardware config
nixos-generate-config --root /mnt

# 3. Clone this flake
nix-shell -p git
git clone https://github.com/WarrDoge/minecraft-server-nixos.git /mnt/etc/nixos

# 4. Install
nixos-install --flake /mnt/etc/nixos#minecraft-server

# 5. Reboot, set up secrets
sops hosts/secrets.yaml
```

## Bootstrapping comin

After first install, comin auto-updates the machine from this repo's `main` branch.
Just push changes — the server picks them up within a few minutes.

## Updating the modpack

1. Find the latest file ID on [CurseForge](https://www.curseforge.com/minecraft/modpacks/all-create/files)
2. Update `modpack.fileId` in `services/minecraft-server/default.nix`
3. Clear the hash and let Nix compute it on the first rebuild
4. Commit & push — comin applies automatically

## JVM Tuning

JVM args are in `services/minecraft-server/default.nix`. Defaults use Aikar's flags
for GC optimization. Adjust `-Xms`/`-Xmx` to match your server RAM.

## License

MIT
