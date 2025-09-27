{
  description = "Pterodactyl container flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      panelBaseConfig = {
        image = "docker.io/ccarney16/pterodactyl-panel:v1.11.11";
        volumes = [
          "/data/services/pterodactyl/panel:/data:z"
        ];
        networks = [
          backendNetwork
          "traefik"
        ];
        extraOptions = [ "--dns=1.1.1.1" ];
        environment = {
          # App Settings
          APP_ENV = "production";
          APP_URL = "https://pterodactyl.emdecloud.de";

          # MySQL Settings
          DB_HOST = "pterodactyl-database";
          DB_PORT = "3306";
          DB_DATABASE = "pterodactyl";
          DB_USERNAME = "pterodactyl";
          # DB_PASSWORD = "password"; # set via secret-mgmt

          # Cache/Session Settings
          CACHE_DRIVER = "redis";
          SESSION_DRIVER = "redis";
          QUEUE_CONNECTION = "redis";

          # Redis Settings
          REDIS_HOST = "pterodactyl-redis";
          REDIS_PORT = "6379";

          # Enable Proxy
          TRUSTED_PROXIES = "0.0.0.0/0";

          # SMTP Settings
          MAIL_DRIVER = "smtp";
          MAIL_HOST = "mail.privateemail.com";
          MAIL_PORT = "465";
          MAIL_USERNAME = "no-reply@emdecloud.de";
          # MAIL_PASSWORD = "password"; # set via secret-mgmt
          MAIL_FROM = "no-reply@emdecloud.de";
          MAIL_FROM_NAME = "Pterodactyl Panel";
        };
      };

      backendNetwork = "pterodactyl-backend";
    in
    {
      name = "pterodactyl";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
          pterodactyl_nw = "";
        };
      };
      containers =
        { hostname, getServiceEnvFiles, ... }:
        {
          # ---------------------------
          # Panel
          # ---------------------------
          pterodactyl-panel = panelBaseConfig // {
            environmentFiles = getServiceEnvFiles "pterodactyl";
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.pterodactyl.rule" = "HostRegexp(`pterodactyl.*`)";
              "traefik.http.routers.pterodactyl.entrypoints" = "websecure";
              "traefik.http.routers.pterodactyl.tls.certresolver" = "myresolver";
              "traefik.http.routers.pterodactyl.tls.domains[0].main" = "pterodactyl.emdecloud.de";
              "traefik.http.services.pterodactyl.loadbalancer.server.port" = "80";

              # 🏠 Homepage integration
              "homepage.group" = "Games";
              "homepage.name" = "Pterodactyl";
              "homepage.icon" = "pterodactyl";
              "homepage.href" = "https://pterodactyl.emdecloud.de";
              "homepage.description" = "Game server management";
            };
          };

          # ---------------------------
          # Database
          # ---------------------------
          pterodactyl-database = {
            image = "mariadb:10.11";
            volumes = [
              "/data/services/pterodactyl/database:/var/lib/mysql:z"
            ];
            networks = [ backendNetwork ];
            environment = {
              # Database and user information for pterodactyl
              MARIADB_DATABASE = "pterodactyl";
              MARIADB_USER = "pterodactyl";
              # MARIADB_PASSWORD = "password"; set using secret-mgmt

              # Randomly generate root password and set to localhost only.
              MARIADB_RANDOM_ROOT_PASSWORD = "yes";
              MARIADB_ROOT_HOST = "localhost";
            };
            environmentFiles = getServiceEnvFiles "pterodactyl";
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          # ---------------------------
          # Redis
          # ---------------------------
          pterodactyl-redis = {
            image = "redis:7";
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          # ---------------------------
          # Wings
          # ---------------------------
          pterodactyl-daemon = {
            image = "docker.io/ccarney16/pterodactyl-daemon:v1.11.13";
            # privileged = true;
            networks = [
              backendNetwork
              "frp-ingress"
              "traefik"
              "pterodactyl_nw"
            ];
            extraOptions = [ "--dns=1.1.1.1" ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/var/run/docker.sock:/var/run/docker.sock"
              "/data/services/pterodactyl/daemon/data:/data/services/pterodactyl/daemon/data:z"
              "/data/services/pterodactyl/daemon/config.yml:/etc/pterodactyl/config.yml"
            ];
            environmentFiles = getServiceEnvFiles "pterodactyl";
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.wings.rule" = "Host(`wings.pterodactyl.emdecloud.de`)";
              "traefik.http.routers.wings.entrypoints" = "websecure";
              "traefik.http.routers.wings.tls.certresolver" = "myresolver";
              "traefik.http.services.wings.loadbalancer.server.port" = "8080";
            };
          };

          # ---------------------------
          # Worker
          # ---------------------------
          pterodactyl-worker = panelBaseConfig // {
            cmd = [ "p:worker" ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          # ---------------------------
          # Cron
          # ---------------------------
          pterodactyl-cron = panelBaseConfig // {
            cmd = [ "p:cron" ];
            volumes = [ "/etc/logs/pterodactyl:/var/www/html/storage/logs" ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
