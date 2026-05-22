#!/usr/bin/env bash
# migrate-secrets.sh (v2 – two-phase redesign)
#
# Migrates secrets from the old per-file .age format to new per-host SOPS YAMLs
# using the new naming convention:
#
#   Service env:  <svc>-<container|common>_env
#   Service file: <svc>-<container|common>-<name>_<ext>
#   Host env:     <host>_env
#   Host file:    <host>-<name>_<ext>
#
# ─── PHASE 1  --prepare [--host <host>] [--test] ─────────────────────────────
#   Decrypts old .age files, merges env files per container, and writes
#   plaintext staging files to  hosts/<host>/secrets-staging/.
#   Review and correct them before running phase 2.
#
# ─── PHASE 2  --commit [--host <host>] ───────────────────────────────────────
#   Reads staging files → builds SOPS YAML → encrypts → hosts/<host>/secrets.yaml
#   Creates new empty .age marker files, deletes old .age files, purges staging.
#
# USAGE
#   ./secret-mgmt/migrate.sh --prepare              # all hosts
#   ./secret-mgmt/migrate.sh --prepare --host mahler
#   # review/edit hosts/mahler/secrets-staging/*
#   ./secret-mgmt/migrate.sh --commit --host mahler

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ── Bootstrap: ensure all tools are in PATH via a single nix shell ────────────
if ! command -v age-plugin-yubikey >/dev/null 2>&1 \
   || ! command -v yq              >/dev/null 2>&1 \
   || ! command -v sops            >/dev/null 2>&1; then
  exec nix shell \
    nixpkgs#age \
    nixpkgs#age-plugin-yubikey \
    nixpkgs#sops \
    nixpkgs#yq-go \
    --command bash "$0" "$@"
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "ℹ️  $*"; }
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*" >&2; }

# ── Secret mapping ────────────────────────────────────────────────────────────
# Each entry: "NEW_SOPS_KEY|TYPE|OLD_AGE_FILE1[|OLD_AGE_FILE2|...]"
#   TYPE = "env"  – env-var files; multiple sources are concatenated
#        = "file" – raw file; only one source
#   Paths are relative to REPO_ROOT.
declare -a SECRET_MAPPING=(
  # ── authentik ────────────────────────────────────────────────────────────
  "authentik-server_env|env|services/authentik/secrets/AUTHENTIK_SECRET_KEY.env.age|services/authentik/secrets/db-credentials.env.age|services/authentik/secrets/smtp-credentials.env.age"

  # ── firefly ──────────────────────────────────────────────────────────────
  "firefly-firefly_env|env|services/firefly/secrets/app_key.env.age"
  "firefly-common-gls_json|file|services/firefly/secrets/gls.json.age"
  "firefly-common-gls-tagesgeldkonto_json|file|services/firefly/secrets/gls-tagesgeldkonto.json.age"

  # ── frp ──────────────────────────────────────────────────────────────────
  "frp-frp_env|env|services/frp/secrets/FRP_TOKEN.env.age"

  # ── grafana ──────────────────────────────────────────────────────────────
  "grafana-grafana_env|env|services/grafana/secrets/authentik-credentials.env.age|services/grafana/secrets/smtp-credentials.env.age"

  # ── immich ───────────────────────────────────────────────────────────────
  "immich-server_env|env|services/immich/secrets/DB_PASSWORD.env.age|services/immich/secrets/kiosk-credentials.env.age"
  "immich-db_env|env|services/immich/secrets/POSTGRES_PASSWORD.env.age"

  # ── kopia ────────────────────────────────────────────────────────────────
  "kopia-kopia_env|env|services/kopia/secrets/KOPIA_PASSWORD.env.age|services/kopia/secrets/KOPIA_SERVER_CREDENTIALS.env.age"
  "kopia-server_env|env|services/kopia/secrets/KOPIA_SERVER_CONTROL_CREDENTIALS.env.age"

  # ── mealie ───────────────────────────────────────────────────────────────
  "mealie-mealie_env|env|services/mealie/secrets/authentik-credentials.env.age|services/mealie/secrets/db-credentials.env.age|services/mealie/secrets/openai-credentials.env.age|services/mealie/secrets/smtp-credentials.env.age"

  # ── nas ──────────────────────────────────────────────────────────────────
  "nas-nas-fileshare_pw|file|services/nas/secrets/fileshare-pw.age"

  # ── nextcloud ────────────────────────────────────────────────────────────
  "nextcloud-nextcloud_env|env|services/nextcloud/secrets/NEXTCLOUD_ADMIN_PASSWORD.env.age|services/nextcloud/secrets/POSTGRES_PASSWORD.env.age"

  # ── ollama ───────────────────────────────────────────────────────────────
  "ollama-open-webui_env|env|services/ollama/secrets/open-webui-oidc-credentials.env.age|services/ollama/secrets/open-webui-secrets.env.age"

  # ── outline ──────────────────────────────────────────────────────────────
  "outline-outline_env|env|services/outline/secrets/POSTGRES_PASSWORD.env.age|services/outline/secrets/secrets.env.age"

  # ── paperless ────────────────────────────────────────────────────────────
  "paperless-paperless_env|env|services/paperless/secrets/PAPERLESS_SECRET_KEY.env.age|services/paperless/secrets/smtp-credentials.env.age"

  # ── pterodactyl ──────────────────────────────────────────────────────────
  "pterodactyl-pterodactyl_env|env|services/pterodactyl/secrets/db_credentials.env.age|services/pterodactyl/secrets/smtp_credentials.env.age"

  # ── synapse ──────────────────────────────────────────────────────────────
  "synapse-synapse_env|env|services/synapse/secrets/app-credentials.env.age|services/synapse/secrets/authentik-credentials.env.age|services/synapse/secrets/database-credentials.env.age|services/synapse/secrets/livekit-credentials.env.age|services/synapse/secrets/matrix-secret.env.age|services/synapse/secrets/smtp-credentials.env.age"
  "synapse-synapse-matrix-auth-secrets_yaml|file|services/synapse/secrets/matrix-auth-secrets.yaml.age"

  # ── traefik ──────────────────────────────────────────────────────────────
  "traefik-traefik_env|env|services/traefik/secrets/cf-token.env.age"

  # ── vaultwarden ──────────────────────────────────────────────────────────
  "vaultwarden-vaultwarden_env|env|services/vaultwarden/secrets/ADMIN_TOKEN.env.age|services/vaultwarden/secrets/smtp-credentials.env.age"

  # ── woodpecker (server + agent share all secrets) ────────────────────────
  "woodpecker-common_env|env|services/woodpecker/secrets/github-credentials.env.age|services/woodpecker/secrets/service-credentials.env.age"
)

# Host-specific secrets (single entry per host, empty string = none)
declare -A HOST_SECRET_ENTRY=(
  [mahler]=""
  [vogel]="vogel_env|env|hosts/vogel/secrets/smb-credentials.env.age"
  [bartok]=""
)

# Which service path prefixes each host uses (space-separated, relative to REPO_ROOT)
# "services/" means all services (mahler); specific dirs for bartok; empty for vogel
declare -A HOST_SERVICE_PREFIXES=(
  [mahler]="services/"
  [vogel]=""
  [bartok]="services/frp/ services/kopia/ services/traefik/"
)

# Returns true if a SECRET_MAPPING entry belongs to a host
_entry_belongs_to_host() {
  local entry="$1" host="$2"
  local first_old; first_old="$(cut -d'|' -f3 <<< "$entry")"
  local prefixes="${HOST_SERVICE_PREFIXES[$host]:-}"
  [[ -z "$prefixes" ]] && return 1
  # "services/" means match everything under services/
  [[ "$prefixes" == "services/" ]] && return 0
  for prefix in $prefixes; do
    [[ "$first_old" == "$prefix"* ]] && return 0
  done
  return 1
}

# Emits all mapping entries for a given host (service + host-specific)
_entries_for_host() {
  local host="$1"
  for entry in "${SECRET_MAPPING[@]}"; do
    _entry_belongs_to_host "$entry" "$host" && echo "$entry" || true
  done
  local he="${HOST_SECRET_ENTRY[$host]:-}"
  [[ -n "$he" ]] && echo "$he" || true
}

# ── Argument parsing ──────────────────────────────────────────────────────────
PHASE=""
TARGET_HOSTS=("mahler" "vogel" "bartok")
TEST_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare) PHASE="prepare"; shift ;;
    --commit)  PHASE="commit";  shift ;;
    --host)    TARGET_HOSTS=("$2"); shift 2 ;;
    --test)    TEST_MODE=true;  shift ;;
    *) die "Unknown argument: $1  (use --prepare or --commit)" ;;
  esac
done

[[ -n "$PHASE" ]] || die "Specify --prepare or --commit"
[[ "$TEST_MODE" == true ]] && info "TEST MODE – only the first entry of the first host"

# ── YubiKey setup (needed only for --prepare) ─────────────────────────────────
YUBIKEY_IDENTITY_FILE=""

setup_yubikey() {
  info "Detecting YubiKey age identity…"

  _yk_list() { age-plugin-yubikey --list 2>/dev/null | grep -E '^age1yubikey' || true; }

  _ensure_pcscd() {
    systemctl is-active --quiet pcscd 2>/dev/null && return
    read -rp "  pcscd is not running. Start with sudo? [Y/n] " _ans
    [[ "${_ans,,}" == "n" ]] && return
    sudo systemctl start pcscd && ok "pcscd started" || warn "Could not start pcscd"
  }

  local slot=""
  while true; do
    _ensure_pcscd
    mapfile -t _yk_keys < <(_yk_list)
    if [[ ${#_yk_keys[@]} -ge 1 ]]; then
      if [[ ${#_yk_keys[@]} -eq 1 ]]; then
        slot=1
      else
        echo "Multiple YubiKey identities found:"
        for i in "${!_yk_keys[@]}"; do echo "  $((i+1))) ${_yk_keys[$i]}"; done
        read -rp "  Select slot [1]: " slot; slot="${slot:-1}"
      fi
      ok "YubiKey slot ${slot}: ${_yk_keys[$((slot-1))]}"
      break
    fi
    echo "No YubiKey found.  1) Retry  2) Provision new slot  3) Skip"
    read -rp "Choice [1]: " _c
    case "${_c:-1}" in
      1) echo "Insert YubiKey and press Enter…"; read -r ;;
      2) read -rp "Slot [1]: " _s; age-plugin-yubikey --generate --slot "${_s:-1}" ;;
      3) warn "Skipping YubiKey – decryption will fail if secrets require it"; return ;;
    esac
  done

  YUBIKEY_IDENTITY_FILE="$(mktemp --suffix=".yubikey-identity")"
  trap 'rm -f "$YUBIKEY_IDENTITY_FILE"' EXIT
  age-plugin-yubikey --identity --slot "$slot" > "$YUBIKEY_IDENTITY_FILE" 2>/dev/null || true
  if [[ -s "$YUBIKEY_IDENTITY_FILE" ]]; then
    ok "YubiKey identity exported (touch may be required during decryption)"
  else
    warn "Could not export identity – falling back to key-file-only decryption"
    rm -f "$YUBIKEY_IDENTITY_FILE"; YUBIKEY_IDENTITY_FILE=""
  fi
}

# Decrypts an .age file; reads identity from YubiKey + any key files in secrets/
_age_decrypt() {
  gpgconf --kill scdaemon 2>/dev/null || true
  local args=()
  [[ -n "${YUBIKEY_IDENTITY_FILE:-}" && -s "${YUBIKEY_IDENTITY_FILE}" ]] \
    && args+=("-i" "$YUBIKEY_IDENTITY_FILE")
  for kf in "${REPO_ROOT}"/secrets/host-key.nix.*; do
    [[ -f "$kf" ]] && args+=("-i" "$kf")
  done
  age -d "${args[@]}" "$@"
}

# For env files: replace every KEY=value with KEY=<secret>, preserving comments
_sanitize_env() {
  sed -E 's/^(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=.*/\1\2=<secret>/'
}

# ── Phase 1: --prepare ────────────────────────────────────────────────────────
run_prepare() {
  setup_yubikey

  local first_host=true
  for host in "${TARGET_HOSTS[@]}"; do
    info "══════════════════════════════════════════"
    info "Preparing host: $host"

    local staging_dir="${REPO_ROOT}/hosts/${host}/secrets-staging"
    mkdir -p "$staging_dir"

    local count=0
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue

      # In test mode: only first entry of first host
      if [[ "$TEST_MODE" == true ]]; then
        [[ "$first_host" == false ]] && break
        [[ $count -gt 0 ]] && break
      fi

      local new_key type old_files_str
      new_key="$(cut -d'|' -f1 <<< "$entry")"
      type="$(cut -d'|' -f2 <<< "$entry")"
      old_files_str="$(cut -d'|' -f3- <<< "$entry")"
      IFS='|' read -ra old_files <<< "$old_files_str"

      local staging_file="${staging_dir}/${new_key}"
      > "$staging_file"

      local first_src=true any_ok=false
      for age_file in "${old_files[@]}"; do
        local full_path="${REPO_ROOT}/${age_file}"
        if [[ ! -f "$full_path" ]]; then
          warn "Missing: $age_file – skipping"
          continue
        fi

        local tmp; tmp="$(mktemp)"
        if ! _age_decrypt -o "$tmp" "$full_path" 2>/tmp/age-err; then
          warn "Could not decrypt $age_file:"
          sed 's/^/  /' /tmp/age-err >&2
          rm -f "$tmp"; continue
        fi

        # For env files: ensure a newline between concatenated sources
        if [[ "$type" == "env" && "$first_src" == false ]]; then
          local last_char; last_char="$(tail -c1 "$staging_file" | wc -c)"
          [[ "$last_char" -gt 0 ]] && echo "" >> "$staging_file"
        fi

        cat "$tmp" >> "$staging_file"
        rm -f "$tmp"
        first_src=false any_ok=true
      done

      if $any_ok; then
        ok "  [${type}] ${new_key}  ($(wc -c < "$staging_file") bytes)"

        # Write sanitized version next to the old files (env values → <secret>)
        # This becomes the committed marker showing the format without real secrets.
        local first_old="${old_files[0]}"
        local marker_dir="${REPO_ROOT}/$(dirname "$first_old")"
        local marker_file="${marker_dir}/${new_key}"
        if [[ "$type" == "env" ]]; then
          _sanitize_env < "$staging_file" > "$marker_file"
          info "    → marker: $(realpath --relative-to="$REPO_ROOT" "$marker_file") (sanitized)"
        else
          cp "$staging_file" "$marker_file"
          info "    → marker: $(realpath --relative-to="$REPO_ROOT" "$marker_file") (fix secrets manually)"
        fi
      else
        warn "  ${new_key}: all sources failed – staging file is empty"
      fi
      count=$(( count + 1 ))
    done < <(_entries_for_host "$host")

    info "Staging: $staging_dir"
    info "Review the files, then run:  ./secret-mgmt/migrate.sh --commit --host $host"

    [[ "$TEST_MODE" == true ]] && break
    first_host=false
  done
}

# ── Phase 2: --commit ─────────────────────────────────────────────────────────
run_commit() {
  for host in "${TARGET_HOSTS[@]}"; do
    info "══════════════════════════════════════════"
    info "Committing host: $host"

    local staging_dir="${REPO_ROOT}/hosts/${host}/secrets-staging"
    local secrets_yaml="${REPO_ROOT}/hosts/${host}/secrets.yaml"
    [[ -d "$staging_dir" ]] || die "No staging dir for $host at $staging_dir – run --prepare first"

    # Build plaintext YAML from all staging files
    echo "{}" > "$secrets_yaml"
    local count=0
    while IFS= read -r -d '' f; do
      local key; key="$(basename "$f")"
      local content; content="$(cat "$f")"
      PLAINTEXT="$content" yq -i ".\"${key}\" = strenv(PLAINTEXT)" "$secrets_yaml"
      count=$(( count + 1 ))
    done < <(find "$staging_dir" -maxdepth 1 -type f -print0 | sort -z)

    [[ $count -eq 0 ]] && { warn "No staging files for $host – skipping"; rm -f "$secrets_yaml"; continue; }
    info "  Built YAML with $count secrets"

    # Encrypt in-place (recipients from .sops.yaml)
    sops encrypt --in-place "$secrets_yaml"
    ok "  Encrypted → $secrets_yaml"

    # Delete old .age files (markers were already written by --prepare)
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      local old_files_str; old_files_str="$(cut -d'|' -f3- <<< "$entry")"
      IFS='|' read -ra old_files <<< "$old_files_str"
      for old_file in "${old_files[@]}"; do
        local full="${REPO_ROOT}/${old_file}"
        if [[ -f "$full" ]]; then
          rm -f "$full"
          info "  Deleted: $old_file"
        fi
      done
    done < <(_entries_for_host "$host")

    # Purge plaintext staging files
    rm -rf "$staging_dir"
    ok "  Staging dir purged"
  done

  ok "Done. Run 'nixos-rebuild switch' on each affected host."
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$PHASE" in
  prepare) run_prepare ;;
  commit)  run_commit  ;;
esac
