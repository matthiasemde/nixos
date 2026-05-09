# Secret Management

This flake provides declarative secret management for NixOS hosts using
[sops-nix](https://github.com/Mic92/sops-nix) with per-host SOPS-encrypted
YAML files.  Secrets are automatically decrypted at boot and made available
under `/run/secrets/`.

---

## 📦 Structure

```
.sops.yaml                   # Key routing: which age keys encrypt which files
hosts/
  mahler/secrets.yaml        # All mahler + service secrets (SOPS-encrypted)
  vogel/secrets.yaml         # vogel host secrets (SOPS-encrypted)
  bartok/secrets.yaml        # bartok service secrets (SOPS-encrypted)
services/<svc>/secrets/      # .age marker files (determine YAML key names)
hosts/<host>/secrets/        # .age marker files (determine YAML key names)
secret-mgmt/
  flake.nix                  # NixOS module + lib helpers
  add_secret.sh              # Add/edit secrets interactively
  migrate.sh                 # One-time migration from agenix → sops-nix
```

---

## 🔑 Key Naming Convention

| Component        | Example                          |
|------------------|----------------------------------|
| `.age` marker    | `services/firefly/secrets/app_key.env.age` |
| SOPS YAML key    | `firefly-app_key_env`  (dots → underscores) |
| Runtime path     | `/run/secrets/firefly-app_key.env` (dots preserved) |

---

## 🚀 Initial Setup

### 1 — Generate keys

**Post-quantum admin key** (run once on your workstation):
```bash
# rage supports ML-KEM-768 + X25519 hybrid (post-quantum)
rage-keygen -o secrets/admin-pq-key.txt
# Keep the private key offline; note the public key printed to stdout
```

**YubiKey identity** (if not already configured):
```bash
age-plugin-yubikey --generate
age-plugin-yubikey --list   # shows age1yubikey1... public key
```

### 2 — Configure `.sops.yaml`

Replace the `TODO` placeholders with the actual public keys:
```yaml
keys:
  - &admin_yubikey "age1yubikey1..."
  - &admin_pq      "age1pq..."
  - &mahler_host   "age1..."    # from /etc/sops/age/keys.txt on mahler
  - &vogel_host    "age1..."
  - &bartok_host   "age1..."
```

### 3 — Place host private keys on each server

```bash
sudo install -Dm600 /path/to/host-private.key /etc/sops/age/keys.txt
```

### 4 — Run the migration (first time only)

```bash
./secret-mgmt/migrate.sh
```

---

## ➕ Adding a New Secret

```bash
# Interactive – opens the host's secrets.yaml in $EDITOR via sops
./secret-mgmt/add_secret.sh -n my-secret.env -s <service>
./secret-mgmt/add_secret.sh -n my-secret.env -h <hostname>

# Non-interactive – set a key directly
sops set hosts/mahler/secrets.yaml '["service-my-secret_env"]' '"VALUE"'
```

By convention, service secrets default to `hosts/mahler/secrets.yaml`.
Override with `HOST_OVERRIDE=bartok ./secret-mgmt/add_secret.sh …` for
services running on bartok.

---

## 🔧 How the NixOS Module Works

1. Scans `*.age` marker files in each service/host secrets dir to discover key names.
2. Sets `sops.defaultSopsFile = hosts/<hostname>/secrets.yaml`.
3. Registers `sops.secrets."<yaml-key>" = { path = "/run/secrets/<original-name>"; }` for each key.
4. `getServiceEnvFiles "svc"` → list of `/run/secrets/svc-*.env` paths (for `environmentFiles`).
5. `getServiceSecrets  "svc"` → list of all `/run/secrets/svc-*` paths.

---

## 🔄 Re-keying / Key Rotation

```bash
# Rotate all secrets in a file to new recipient keys (after updating .sops.yaml)
sops updatekeys hosts/mahler/secrets.yaml

# Edit a single file in-place
sops edit hosts/mahler/secrets.yaml
```

---

## 🔐 YubiKey + Post-Quantum Age: How They Fit Together

| Key                | Purpose                                      | Stored                        |
|--------------------|----------------------------------------------|-------------------------------|
| YubiKey age key    | Admin encryption + offline backup decryption | Hardware token                |
| PQ admin key       | Admin encryption from workstation            | `secrets/admin-pq-key.txt` (gitignored) |
| Host age key       | Server-side decryption at boot               | `/etc/sops/age/keys.txt` on host |

All three are listed as recipients for each host's `secrets.yaml`, so any
one of them is sufficient to decrypt (useful for key rotation or emergency
access).

