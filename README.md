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
│   ├── bartok
│   │   ├── alloy
│   │   │   └── config.alloy
│   │   ├── configuration.nix
│   │   ├── frpc.toml
│   │   ├── hardware-configuration.nix
│   │   ├── secrets
│   │   │   ├── env.yaml
│   │   │   ├── grafana
│   │   │   │   └── alloy
│   │   │   │       ├── ca.crt
│   │   │   │       ├── client.crt
│   │   │   │       └── client.key
│   │   │   └── minio
│   │   │       └── server
│   │   │           └── license
│   │   └── services.nix
│   ├── common.nix
│   ├── hindemith
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   ├── mahler
│   │   ├── alloy
│   │   │   └── config.alloy
│   │   ├── configuration.nix
│   │   ├── frpc.toml
│   │   ├── hardware-configuration.nix
│   │   ├── secrets
│   │   │   ├── env.yaml
│   │   │   ├── firefly
│   │   │   │   └── fints
│   │   │   │       ├── gls.json
│   │   │   │       └── gls-tagesgeldkonto.json
│   │   │   ├── grafana
│   │   │   │   └── alloy
│   │   │   │       ├── ca.crt
│   │   │   │       ├── server.crt
│   │   │   │       └── server.key
│   │   │   ├── nas
│   │   │   │   └── fileshare
│   │   │   │       └── password
│   │   │   ├── synapse
│   │   │   │   └── matrix-auth-app
│   │   │   │       └── secrets.yaml
│   │   │   └── traefik
│   │   │       └── server
│   │   │           └── crowdsec.toml
│   │   └── services.nix
│   └── vogel
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── README.md
├── renovate.json
├── secret-mgmt
│   ├── default.nix
│   └── README.md
├── service-module.nix.template
├── services
│   ├── adguard
│   │   ├── config
│   │   │   └── AdGuardHome.yaml
│   │   └── default.nix
│   ├── audiobookshelf
│   │   └── default.nix
│   ├── authentik
│   │   └── default.nix
│   ├── crowdsec
│   │   ├── appsec.yaml
│   │   ├── config.yaml.local
│   │   └── default.nix
│   ├── firefly
│   │   └── default.nix
│   ├── fl-hofmusic
│   │   ├── config
│   │   │   └── nginx.conf
│   │   └── default.nix
│   ├── frp
│   │   ├── default.nix
│   │   └── .env
│   ├── grafana
│   │   ├── config
│   │   │   ├── datasources.yml
│   │   │   ├── loki.yml
│   │   │   └── prometheus.yml
│   │   ├── default.nix
│   │   └── README.md
│   ├── home-assistant
│   │   ├── config
│   │   │   ├── automations.yaml
│   │   │   ├── configuration.yaml
│   │   │   ├── scenes.yaml
│   │   │   └── scripts.yaml
│   │   └── default.nix
│   ├── homepage
│   │   ├── config
│   │   │   ├── bookmarks.yaml
│   │   │   ├── custom.css
│   │   │   ├── custom.js
│   │   │   ├── docker.yaml
│   │   │   ├── services.yaml
│   │   │   ├── settings.yaml
│   │   │   └── widgets.yaml
│   │   ├── default.nix
│   │   └── README.md
│   ├── immich
│   │   └── default.nix
│   ├── kopia
│   │   ├── create_repository.sh
│   │   ├── default.nix
│   │   ├── do-remote-backup.sh
│   │   └── README.md
│   ├── lovebox
│   │   ├── config
│   │   │   ├── nginx.conf
│   │   │   └── php-fpm.conf
│   │   ├── default.nix
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
│   │   └── default.nix
│   ├── microbin
│   │   ├── default.nix
│   │   └── .env
│   ├── minio
│   │   └── default.nix
│   ├── nas
│   │   └── default.nix
│   ├── navidrome
│   │   ├── default.nix
│   │   ├── music-sync.sh
│   │   └── README.md
│   ├── nextcloud
│   │   ├── apache-custom.conf
│   │   ├── default.nix
│   │   └── README.md
│   ├── ollama
│   │   └── default.nix
│   ├── outline
│   │   └── default.nix
│   ├── paperless
│   │   └── default.nix
│   ├── pterodactyl
│   │   └── default.nix
│   ├── radicale
│   │   ├── config
│   │   │   └── config
│   │   ├── default.nix
│   │   ├── README.md
│   │   └── users
│   ├── silverbullet
│   │   └── default.nix
│   ├── synapse
│   │   ├── config
│   │   │   ├── homeserver.yaml.j2
│   │   │   ├── livekit-config.yaml
│   │   │   ├── log.config
│   │   │   ├── matrix-auth-config.yaml.j2
│   │   │   ├── synapse-admin-config.json
│   │   │   └── wellknown-nginx.conf
│   │   ├── default.nix
│   │   ├── ELEMENT_CALL_README.md
│   │   ├── entrypoint.sh
│   │   ├── livekit-entrypoint.sh
│   │   ├── matrix-auth-entrypoint.sh
│   │   ├── README.md
│   │   └── render-config.py
│   ├── traefik
│   │   ├── config
│   │   │   ├── error.html
│   │   │   ├── middlewares.toml
│   │   │   ├── nginx.conf
│   │   │   └── traefik.toml
│   │   └── default.nix
│   ├── uptime-kuma
│   │   └── default.nix
│   ├── vaultwarden
│   │   └── default.nix
│   ├── web-projects
│   │   ├── config
│   │   │   ├── index.html
│   │   │   └── nginx.conf
│   │   └── default.nix
│   └── woodpecker
│       ├── default.nix
│       └── README.md
├── SETUP.md
├── .sops.yaml
├── tools
│   ├── install-precommit-hook.sh
│   ├── migrate-db.sh
│   ├── migrate.sh
│   └── pre-commit-hook.sh
└── virtualization
    └── default.nix

73 directories, 142 files
```

<!-- DIRECTORY_STRUCTURE_END -->
