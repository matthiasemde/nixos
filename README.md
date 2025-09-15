# Project Pandora
This repository holds the configuration of my homelab powered by NixOS
<!-- DIRECTORY_STRUCTURE_START -->

```
.
├── .editorconfig
├── flake.lock
├── flake.nix
├── .gitignore
├── hosts
│   └── mahler
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── README.md
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
│   ├── cloudflared
│   │   ├── config
│   │   │   └── config.yaml
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── .env.age
│   │       └── .env.age.nix
│   ├── firefly
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── app_key.env.age
│   │       ├── app_key.env.age.nix
│   │       ├── gls.json.age
│   │       └── gls.json.age.nix
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
│   ├── radicale
│   │   ├── config
│   │   │   └── config
│   │   ├── flake.nix
│   │   ├── README.md
│   │   └── users
│   ├── traefik
│   │   ├── config
│   │   │   ├── error.html
│   │   │   ├── nginx.conf
│   │   │   └── traefik.toml
│   │   ├── flake.nix
│   │   └── secrets
│   │       ├── cf-token.env.age
│   │       └── cf-token.env.age.nix
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
└── virtualization
    └── flake.nix

38 directories, 82 files
```

<!-- DIRECTORY_STRUCTURE_END -->
