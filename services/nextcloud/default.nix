{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  hostname = config.networking.hostName;
  backendNetwork = "nextcloud-backend";

  externalStorage = {
    files = "/data/nas/files";
    home = "/data/nas/home";
    navidrome = "/data/nas/navidrome";
    audiobookshelf = "/data/nas/audiobookshelf";
  };
in
{
  myVirtualization.networks.${backendNetwork} = "";

  myVirtualization.containers.nextcloud-app = {
    rawImageReference = "nextcloud:34.0.0-apache@sha256:e15ff2ff02d04bf272940bb63f2157599bc9440d45b688cc60f09b72be7ae717";
    nixSha256 = "sha256-refs0utDnFYpCbetHFxsgjJU9uBKg4iKyx8QZLfqgRU=";
    volumes = [
      "/data/services/nextcloud/app/config:/var/www/html/config"
      "/data/services/nextcloud/app/data:/var/www/html/data"
      "/data/services/nextcloud/app/custom_apps:/var/www/html/custom_apps"
      "${./apache-custom.conf}:/etc/apache2/sites-enabled/000-default.conf:ro"
    ]
    ++ map (name: "${externalStorage.${name}}:/mnt/${name}") (builtins.attrNames externalStorage);
    networks = [
      backendNetwork
      "traefik"
    ];
    environment = {
      POSTGRES_HOST = "nextcloud-database";
      POSTGRES_DB = "nextcloud";
      POSTGRES_USER = "nextcloud";
      REDIS_HOST = "nextcloud-redis";
      NEXTCLOUD_TRUSTED_DOMAINS = "nextcloud.${domain} nextcloud.${hostname}.local";
      TRUSTED_PROXIES = "172.16.0.0/12";
      OVERWRITEPROTOCOL = "https";
      OVERWRITECLIURL = "https://nextcloud.${domain}";
      FORWARDED_FOR_HEADERS = "HTTP_X_FORWARDED_FOR";
    };
    environmentFiles = getEnvFiles "nextcloud" "app";
    labels =
      (mkTraefikLabels {
        name = "nextcloud";
        port = "80";
      })
      // {
        "traefik.http.routers.nextcloud-public.middlewares" = "nextcloud-headers@docker";
        "traefik.http.middlewares.nextcloud-headers.headers.stsSeconds" = "15552000";
        "traefik.http.middlewares.nextcloud-headers.headers.stsIncludeSubdomains" = "true";
        "traefik.http.middlewares.nextcloud-headers.headers.stsPreload" = "true";

        "homepage.group" = "Media";
        "homepage.name" = "Nextcloud";
        "homepage.icon" = "nextcloud";
        "homepage.href" = "https://nextcloud.${domain}";
        "homepage.description" = "Home to all our data";
      };
  };

  myVirtualization.containers.nextcloud-database = {
    rawImageReference = "postgres:17@sha256:ae3afa4af0906431de8856bf80a8bcf8a9ea6b3609f9e025f927b949ac93467d";
    nixSha256 = "sha256-2Nqz+MGNn5nzCYCYETWv8JBN2odoq+RuvJ2LGnWT5d8=";
    volumes = [ "/data/services/nextcloud/database:/var/lib/postgresql/data" ];
    networks = [ backendNetwork ];
    environment = {
      POSTGRES_DB = "nextcloud";
      POSTGRES_USER = "nextcloud";
    };
    environmentFiles = getEnvFiles "nextcloud" "database";
    cmd = [
      "postgres"
      "-c"
      "log_checkpoints=off"
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.nextcloud-redis = {
    rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
    nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
    networks = [ backendNetwork ];
    cmd = [
      "redis-server"
      "--loglevel"
      "warning"
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.nextcloud-cron = {
    rawImageReference = "alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11";
    nixSha256 = "sha256-svJI+DpSqhR8OnybK3+AefJnjcG0ry46R2aWII21Bdg=";
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/var/run/docker.sock:/var/run/docker.sock:ro"
    ];
    cmd = [
      "sh"
      "-c"
      ''
        apk add --no-cache docker tzdata && \
        ( crontab -l 2>/dev/null; \
          echo "*/5 * * * * docker exec -u www-data nextcloud-app php -f /var/www/html/cron.php" ) | crontab - && \
        crond -f -L /dev/stdout
      ''
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };
}
