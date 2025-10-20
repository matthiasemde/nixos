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
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          pterodactylPanelRawImageReference = "ccarney16/pterodactyl-panel:v1.11.11@sha256:9bcf170fb6dfd40665e825cb37bc1532e9ab4828868a5e9af3c08ac7f8a4840d";
          pterodactylPanelImageReference = parseDockerImageReference pterodactylPanelRawImageReference;
          pterodactylPanelImage = pkgs.dockerTools.pullImage {
            imageName = pterodactylPanelImageReference.name;
            imageDigest = pterodactylPanelImageReference.digest;
            finalImageTag = pterodactylPanelImageReference.tag;
            sha256 = "sha256-7H5ybzd6RzlPsxFZKUp1bmiLfG9Q6we021FW5nQCPk4=";
          };

          pterodactylDaemonRawImageReference = "ccarney16/pterodactyl-daemon:v1.11.13@sha256:e0d870157253f9919831372abd687e86b2fce4204fad2957dea38e976692197d";
          pterodactylDaemonImageReference = parseDockerImageReference pterodactylDaemonRawImageReference;
          pterodactylDaemonImage = pkgs.dockerTools.pullImage {
            imageName = pterodactylDaemonImageReference.name;
            imageDigest = pterodactylDaemonImageReference.digest;
            finalImageTag = pterodactylDaemonImageReference.tag;
            sha256 = "sha256-qIHlP9PHfO4aHgP+JyFm9mIxdT1pAM8Ep1XtyaDz+oU=";
          };

          mariadbRawImageReference = "mariadb:12.0.2@sha256:5b6a1eac15b85b981a61afb89aea2a22bf76b5f58809d05f0bcc13ab6ec44cb8";
          mariadbImageReference = parseDockerImageReference mariadbRawImageReference;
          mariadbImage = pkgs.dockerTools.pullImage {
            imageName = mariadbImageReference.name;
            imageDigest = mariadbImageReference.digest;
            finalImageTag = mariadbImageReference.tag;
            sha256 = "sha256-CCCankztFYHK4DaJ5hdSR5OqUW6FmpLNEdfd/r5fqVA=";
          };

          redisRawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
          redisImageReference = parseDockerImageReference redisRawImageReference;
          redisImage = pkgs.dockerTools.pullImage {
            imageName = redisImageReference.name;
            imageDigest = redisImageReference.digest;
            finalImageTag = redisImageReference.tag;
            sha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
          };

          panelBaseConfig = {
            image = pterodactylPanelImageReference.name + ":" + pterodactylPanelImageReference.tag;
            imageFile = pterodactylPanelImage;
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
                "homepage.group" = "Games";
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
            image = mariadbImageReference.name + ":" + mariadbImageReference.tag;
            imageFile = mariadbImage;
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
            image = redisImageReference.name + ":" + redisImageReference.tag;
            imageFile = redisImage;
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
            image = pterodactylDaemonImageReference.name + ":" + pterodactylDaemonImageReference.tag;
            imageFile = pterodactylDaemonImage;
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
