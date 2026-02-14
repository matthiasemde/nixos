{
  description = "Pterodactyl container flake";

  outputs =
    { self, nixpkgs }:
    let
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
        {
          domain,
          mkTraefikLabels,
          getServiceEnvFiles,
          ...
        }:
        let
          panelBaseConfig = {
            rawImageReference = "ccarney16/pterodactyl-panel:v1.12.0@sha256:0283aafa61190762f7b8da29e8a1f7bbd76dc4fc02efbbdf82f861470923bcb8";
            nixSha256 = "sha256-1xNMwSknh2egnK48CNadht3I36Pj1BBQWtL+PTxtF58=";
            volumes = [
              "/data/services/pterodactyl/panel:/data:z"
            ];
            networks = [
              backendNetwork
              "traefik"
            ];
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
        in
        {
          # ---------------------------
          # Panel
          # ---------------------------
          pterodactyl-panel = panelBaseConfig // {
            environmentFiles = getServiceEnvFiles "pterodactyl";
            labels =
              (mkTraefikLabels {
                name = "pterodactyl";
                port = "80";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Fun & Games";
                "homepage.name" = "Pterodactyl";
                "homepage.icon" = "pterodactyl";
                "homepage.href" = "https://pterodactyl.${domain}";
                "homepage.description" = "Game server management";
              };
          };

          # ---------------------------
          # Database
          # ---------------------------
          pterodactyl-database = {
            rawImageReference = "mariadb:12.2.2@sha256:3ba727e641ef0ea24054e47c72a831b1067da32d5139c0405b629c25b115eb89";
            nixSha256 = "sha256-sicAmjf5KrAfOOeVzme1SQrVNZ2QIt6wBvrmYS3rqE0=";
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
            rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
            nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
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
            rawImageReference = "ccarney16/pterodactyl-daemon:v1.11.13@sha256:e0d870157253f9919831372abd687e86b2fce4204fad2957dea38e976692197d";
            nixSha256 = "sha256-qIHlP9PHfO4aHgP+JyFm9mIxdT1pAM8Ep1XtyaDz+oU=";
            # privileged = true;
            networks = [
              backendNetwork
              "frp-ingress"
              "traefik"
              "pterodactyl_nw"
            ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/var/run/docker.sock:/var/run/docker.sock"
              "/data/services/pterodactyl/daemon/data:/data/services/pterodactyl/daemon/data:z"
              "/data/services/pterodactyl/daemon/config.yml:/etc/pterodactyl/config.yml"
            ];
            environmentFiles = getServiceEnvFiles "pterodactyl";
            labels = mkTraefikLabels {
              name = "wings-pterodactyl";
              port = "443";
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
