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
│   ├── mahler
│   │   ├── configuration.nix
│   │   ├── hardware-configuration.nix
│   │   └── secrets
│   │       ├── WEBHOOK_SECRET.env.age
│   │       └── WEBHOOK_SECRET.env.age.nix
│   └── vogel
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── secrets
│           ├── smb-credentials.env.age
│           └── smb-credentials.env.age.nix
├── README.md
├── renovate.json
├── secret-mgmt
│   ├── add_secret.sh
│   ├── flake.nix
│   └── README.md
├── secrets
│   ├── host-key.nix.mahler
│   └── yubi-key.nix.mahler
├── service-flake.nix.template
├── services
│   ├── adguard
│   │   ├── config
│   │   │   └── AdGuardHome.yaml
│   │   └── flake.nix
│   ├── audiobookshelf
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
│   ├── fl-hofmusic
│   │   ├── config
│   │   │   └── nginx.conf
│   │   └── flake.nix
│   ├── frp
│   │   ├── config
│   │   │   └── frpc.toml
│   │   ├── .env
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── FRP_TOKEN.env.age
│   │       └── FRP_TOKEN.env.age.nix
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
│   │       ├── kiosk-credentials.env.age
│   │       ├── kiosk-credentials.env.age.nix
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
│   ├── lovebox
│   │   ├── config
│   │   │   ├── nginx.conf
│   │   │   └── php-fpm.conf
│   │   ├── flake.nix
│   │   └── server
│   │       ├── createBitmap.php
│   │       ├── cropImage.php
│   │       ├── favicon.ico
│   │       ├── heart-background.jpg
│   │       ├── index.php
│   │       ├── inputEmoji.js
│   │       ├── lovebox_logo.png
│   │       ├── send.php
│   │       ├── styles.css
│   │       └── upload.php
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
│   ├── microbin
│   │   ├── .env
│   │   └── flake.nix
│   ├── nas
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── fileshare-pw.age
│   │       └── fileshare-pw.age.nix
│   ├── navidrome
│   │   ├── flake.nix
│   │   ├── music-sync.sh
│   │   └── README.md
│   ├── nextcloud
│   │   ├── flake.nix
│   │   ├── README.md
│   │   └── secrets
│   │       ├── NEXTCLOUD_ADMIN_PASSWORD.env.age
│   │       ├── NEXTCLOUD_ADMIN_PASSWORD.env.age.nix
│   │       ├── POSTGRES_PASSWORD.env.age
│   │       └── POSTGRES_PASSWORD.env.age.nix
│   ├── ollama
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── open-webui-oidc-credentials.env.age
│   │       ├── open-webui-oidc-credentials.env.age.nix
│   │       ├── open-webui-secrets.env.age
│   │       └── open-webui-secrets.env.age.nix
│   ├── outline
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── POSTGRES_PASSWORD.env.age
│   │       ├── POSTGRES_PASSWORD.env.age.nix
│   │       ├── secrets.env.age
│   │       └── secrets.env.age.nix
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
│   ├── silverbullet
│   │   └── flake.nix
│   ├── synapse
│   │   ├── config
│   │   │   ├── homeserver.yaml.j2
│   │   │   ├── livekit-config.yaml
│   │   │   ├── log.config
│   │   │   ├── matrix-auth-config.yaml.j2
│   │   │   ├── synapse-admin-config.json
│   │   │   └── wellknown-nginx.conf
│   │   ├── ELEMENT_CALL_README.md
│   │   ├── entrypoint.sh
│   │   ├── flake.nix
│   │   ├── livekit-entrypoint.sh
│   │   ├── matrix-auth-entrypoint.sh
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
│   │       ├── livekit-credentials.env.age
│   │       ├── livekit-credentials.env.age.nix
│   │       ├── matrix-auth-secrets.yaml.age
│   │       ├── matrix-auth-secrets.yaml.age.nix
│   │       ├── matrix-secret.env.age
│   │       ├── matrix-secret.env.age.nix
│   │       ├── smtp-credentials.env.age
│   │       └── smtp-credentials.env.age.nix
│   ├── traefik
│   │   ├── config
│   │   │   ├── error.html
│   │   │   ├── middlewares.toml
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
│   ├── vscode-server
│   │   └── flake.nix
│   ├── web-projects
│   │   ├── config
│   │   │   ├── index.html
│   │   │   └── nginx.conf
│   │   └── flake.nix
│   └── woodpecker
│       ├── flake.nix
│       ├── README.md
│       └── secrets
│           ├── github-credentials.env.age
│           ├── github-credentials.env.age.nix
│           ├── service-credentials.env.age
│           └── service-credentials.env.age.nix
├── SETUP.md
├── tools
│   ├── deploy.sh
│   ├── install-precommit-hook.sh
│   ├── migrate-db.sh
│   ├── pre-commit-hook.sh
│   └── webhook-listener.py
├── virtualization
│   └── flake.nix
└── .woodpecker
    └── deploy.yaml

74 directories, 202 files
```

<!-- DIRECTORY_STRUCTURE_END -->
