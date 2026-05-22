# Secret Management

Declarative secret management for NixOS hosts using
[sops-nix](https://github.com/Mic92/sops-nix). Secrets are decrypted at boot
and made available under `/run/mysecrets/`.

---

## 📦 Structure

```
../.sops.yaml                                             # Key routing: age keys per host/file
../hosts/<hostname>/secrets/env.yaml                      # SOPS-encrypted YAML: nested env vars per service/container
../hosts/<hostname>/secrets/<service>/<container>/<file>  # Individual SOPS-encrypted secret files
flake.nix                                                 # NixOS module + lib helpers
```

---

## 🔑 Keys

- **Host age key**: `/nix/persist/var/lib/sops-nix/key.txt` - used by sops-nix to decrypt secrets at boot.
- **Admin keys**: configured in `.sops.yaml` (YubiKey and/or age keypair) - used to encrypt/edit secrets from a workstation.

---

## 🔧 How the Module Works

The `nixosModules.default` module wires up all secrets from `hosts/<hostname>/secrets/` automatically.

### 1 - env.yaml (environment secrets)

`env.yaml` is a SOPS-encrypted YAML file with a nested structure:
```yaml
<service>:
  common: "KEY=VALUE\n..."       # shared env for all containers of <service>
  <container>: "KEY=VALUE\n..."  # container-specific env
```

The module reads `env.yaml` at build time, flattens the nested keys into individual
`sops.secrets` entries, and places the decrypted values at:
```
/run/mysecrets/<service>/common/.env
/run/mysecrets/<service>/<container>/.env
```

### 2 - Individual secret files

All other files under `hosts/<hostname>/secrets/` are discovered recursively.
Each file is registered as a `sops.secrets` entry - format auto-detected from
extension (`yaml`, `json`, or binary). Decrypted files appear at the same
relative path:
```
hosts/<hostname>/secrets/<service>/<container>/<file>
-> /run/mysecrets/<service>/<container>/<file>
```

---

## 📚 Lib Helpers

Exported via `secret-mgmt.lib` for use in service flakes:

### `getEnvFiles secrets serviceName containerName`

Returns a list of `/run/mysecrets/.../.env` paths for the given service,
covering both `common` and `<containerName>` entries. Use with
`environmentFiles` in OCI container definitions.

```nix
environmentFiles = secret-mgmt.lib.getEnvFiles config.sops.secrets "firefly" "app";
# ->[ "/run/mysecrets/firefly/common/.env" "/run/mysecrets/firefly/app/.env" ]
```

### `getSecretFile secrets serviceName containerName secretName`

Returns the `/run/secrets/...` path for a single named secret file.

```nix
volumes = [ "${secret-mgmt.lib.getSecretFile config.sops.secrets "firefly" "app" "cert.pem"}:/cert.pem:ro" ];
```

---

## ➕ Adding / Editing Secrets

```bash
# Edit env.yaml interactively (sops opens $EDITOR)
sops edit hosts/<hostname>/secrets/env.yaml

# Edit an individual secret file
sops edit hosts/<hostname>/secrets/<service>/<container>/<file>
```

## 🔄 Re-keying

```bash
# After updating .sops.yaml (new host key, key rotation, etc.)
sops updatekeys hosts/<hostname>/secrets/env.yaml
```

