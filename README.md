# Project Pandora
This repository holds the configuration of my homelab powered by NixOS
<!-- DIRECTORY_STRUCTURE_START -->

```
.
├── AGENTS.md
├── .editorconfig
├── flake.lock
├── flake.nix
├── .github
│   ├── scripts
│   │   └── update-docker-hashes.sh
│   └── workflows
│       └── update-docker-hashes.yml
├── .gitignore
├── hosts
│   └── mahler
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── README.md
├── renovate.json
├── secret-mgmt
│   ├── add_secret.sh
│   ├── flake.nix
│   └── README.md
├── secrets
│   ├── host-key.nix.mahler
│   └── yubi-key.nix.mahler
├── services
│   ├── adguard
│   │   ├── config
│   │   │   └── AdGuardHome.yaml
│   │   └── flake.nix
│   ├── authentik
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── AUTHENTIK_SECRET_KEY.env.age
│   │       ├── AUTHENTIK_SECRET_KEY.env.age.nix
│   │       ├── db-credentials.env.age
│   │       ├── db-credentials.env.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   ├── firefly
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── app_key.env.age
│   │       ├── app_key.env.age.nix
│   │       ├── gls.json.age
│   │       ├── gls.json.age.nix
│   │       ├── gls-tagesgeldkonto.json.age
│   │       └── gls-tagesgeldkonto.json.age.nix
│   ├── frp
│   │   ├── config
│   │   │   └── frpc.toml
│   │   ├── .env
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── FRP_TOKEN.env.age
│   │       └── FRP_TOKEN.env.age.nix
│   ├── glances
│   │   └── flake.nix
│   ├── grafana
│   │   ├── config
│   │   │   ├── datasources.yml
│   │   │   └── prometheus.yml
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── authentik-credentials.env.age
│   │       ├── authentik-credentials.env.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   ├── home-assistant
│   │   ├── config
│   │   │   ├── automations.yaml
│   │   │   ├── configuration.yaml
│   │   │   ├── scenes.yaml
│   │   │   └── scripts.yaml
│   │   └── flake.nix
│   ├── homepage
│   │   ├── config
│   │   │   ├── bookmarks.yaml
│   │   │   ├── custom.css
│   │   │   ├── custom.js
│   │   │   ├── docker.yaml
│   │   │   ├── services.yaml
│   │   │   ├── settings.yaml
│   │   │   └── widgets.yaml
│   │   ├── flake.nix
│   │   └── README.md
│   ├── immich
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── DB_PASSWORD.env.age
│   │       ├── DB_PASSWORD.env.age.nix
│   │       ├── POSTGRES_PASSWORD.env.age
│   │       └── POSTGRES_PASSWORD.env.age.nix
│   ├── kopia
│   │   ├── create_repository.sh
│   │   ├── flake.nix
│   │   ├── README.md
│   │   └── secrets
│   │       ├── KOPIA_PASSWORD.env.age
│   │       ├── KOPIA_PASSWORD.env.age.nix
│   │       ├── KOPIA_SERVER_CONTROL_CREDENTIALS.env.age
│   │       ├── KOPIA_SERVER_CONTROL_CREDENTIALS.env.age.nix
│   │       ├── KOPIA_SERVER_CREDENTIALS.env.age
│   │       └── KOPIA_SERVER_CREDENTIALS.env.age.nix
│   ├── mealie
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── authentik-credentials.env.age
│   │       ├── authentik-credentials.env.age.nix
│   │       ├── db-credentials.env.age
│   │       ├── db-credentials.env.age.nix
│   │       ├── openai-credentials.env.age
│   │       ├── openai-credentials.env.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   ├── nas
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── fileshare-pw.age
│   │       └── fileshare-pw.age.nix
│   ├── nextcloud
│   │   ├── Dockerfile
│   │   ├── flake.nix
│   │   ├── README.md
│   │   ├── secrets
│   │   │   ├── NEXTCLOUD_ADMIN_PASSWORD.env.age
│   │   │   ├── NEXTCLOUD_ADMIN_PASSWORD.env.age.nix
│   │   │   ├── POSTGRES_PASSWORD.env.age
│   │   │   └── POSTGRES_PASSWORD.env.age.nix
│   │   └── supervisord.conf
│   ├── paperless
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── PAPERLESS_SECRET_KEY.env.age
│   │       ├── PAPERLESS_SECRET_KEY.env.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   ├── pterodactyl
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── db_credentials.env.age
│   │       ├── db_credentials.env.age.nix
│   │       ├── smtp_credentials.env.age
│   │       └── smtp_credentials.env.age.nix
│   ├── radicale
│   │   ├── config
│   │   │   └── config
│   │   ├── flake.nix
│   │   ├── README.md
│   │   └── users
│   ├── synapse
│   │   ├── config
│   │   │   ├── homeserver.yaml.j2
│   │   │   ├── log.config
│   │   │   └── synapse-admin-config.json
│   │   ├── entrypoint.sh
│   │   ├── flake.nix
│   │   ├── README.md
│   │   ├── render-config.py
│   │   └── secrets
│   │       ├── app-credentials.env.age
│   │       ├── app-credentials.env.age.nix
│   │       ├── authentik-credentials.env.age
│   │       ├── authentik-credentials.env.age.nix
│   │       ├── database-credentials.env.age
│   │       ├── database-credentials.env.age.nix
│   │       ├── homeserver.yaml.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   ├── traefik
│   │   ├── config
│   │   │   ├── error.html
│   │   │   ├── nginx.conf
│   │   │   └── traefik.toml
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── cf-token.env.age
│   │       └── cf-token.env.age.nix
│   ├── uptime-kuma
│   │   └── flake.nix
│   ├── vaultwarden
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── ADMIN_TOKEN.env.age
│   │       ├── ADMIN_TOKEN.env.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   └── vscode-server
│       └── flake.nix
├── SETUP.md
├── tools
│   ├── install-precommit-hook.sh
│   ├── migrate-db.sh
│   └── pre-commit-hook.sh
└── virtualization
    └── flake.nix

54 directories, 141 files
```

<!-- DIRECTORY_STRUCTURE_END -->
