{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "pterodactyl-backend";

  panelBaseConfig = {
    rawImageReference = "ccarney16/pterodactyl-panel:v1.13.0@sha256:7fb199cd87cb9d220eea397a9bb658b27197040928ae73fcd4836c664a54d036";
    nixSha256 = "sha256-D9o3qmcDxxSbbDv/fr8ZNNdZ/+Ebj4yEPuGyajAFoSo=";
    volumes = [
      "/data/services/pterodactyl/panel:/data:z"
    ];
    networks = [
      backendNetwork
      "traefik"
    ];
    environment = {
      APP_ENV = "production";
      APP_URL = "https://pterodactyl.${domain}";
      DB_HOST = "pterodactyl--database";
      DB_PORT = "3306";
      DB_DATABASE = "pterodactyl";
      DB_USERNAME = "pterodactyl";
      CACHE_DRIVER = "redis";
      SESSION_DRIVER = "redis";
      QUEUE_CONNECTION = "redis";
      REDIS_HOST = "pterodactyl--redis";
      REDIS_PORT = "6379";
      LOG_CHANNEL = "stderr";
      TRUSTED_PROXIES = "0.0.0.0/0";
      MAIL_DRIVER = "smtp";
      MAIL_HOST = config.myInfrastructure.smtp.host;
      MAIL_PORT = toString config.myInfrastructure.smtp.port;
      MAIL_USERNAME = config.myInfrastructure.smtp.fromAddress;
      MAIL_FROM = config.myInfrastructure.smtp.fromAddress;
      MAIL_FROM_NAME = "Pterodactyl Panel";
    };
  };
in
{
  myVirtualization.networks.${backendNetwork} = "";
  myVirtualization.networks.pterodactyl_nw = "";

  myVirtualization.containers.pterodactyl.panel = panelBaseConfig // {
    environmentFiles = getEnvFiles "pterodactyl" "panel";
    labels =
      (mkTraefikLabels {
        name = "pterodactyl";
        port = "80";
      })
      // {
        "homepage.group" = "Fun & Games";
        "homepage.name" = "Pterodactyl";
        "homepage.icon" = "pterodactyl";
        "homepage.href" = "https://pterodactyl.${domain}";
        "homepage.description" = "Game server management";
      };
  };

  myVirtualization.containers.pterodactyl.database = {
    rawImageReference = "mariadb:12.3.2@sha256:b1c7bf836e64ed9406a8984af29509f40089d55cea14b32f12c4726a1f17104b";
    nixSha256 = "sha256-d8KIResDeBgNWNsTqHZkJnGGbzk+wcj6n+OOZ2woY6w=";
    volumes = [
      "/data/services/pterodactyl/database:/var/lib/mysql:z"
    ];
    networks = [ backendNetwork ];
    environment = {
      MARIADB_DATABASE = "pterodactyl";
      MARIADB_USER = "pterodactyl";
      MARIADB_RANDOM_ROOT_PASSWORD = "yes";
      MARIADB_ROOT_HOST = "localhost";
    };
    environmentFiles = getEnvFiles "pterodactyl" "database";
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.pterodactyl.redis = {
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

  myVirtualization.containers.pterodactyl.daemon = {
    rawImageReference = "ccarney16/pterodactyl-daemon:v1.13.0@sha256:3c55f2751962394eedcbd0daf814ca5ae0afee8a896c730795a0f05658d1dcf6";
    nixSha256 = "sha256-fZ4fU0Y8xMZdII+CvEm0z4DEsx6o5SFCucUIXUrRVy8=";
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
    labels = mkTraefikLabels {
      name = "wings-pterodactyl";
      port = "443";
    };
  };

  myVirtualization.containers.pterodactyl.worker = panelBaseConfig // {
    cmd = [ "p:worker" ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.pterodactyl.cron = panelBaseConfig // {
    cmd = [ "p:cron" ];
    labels = {
      "traefik.enable" = "false";
    };
  };
}
