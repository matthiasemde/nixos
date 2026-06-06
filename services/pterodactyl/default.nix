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
    rawImageReference = "ccarney16/pterodactyl-panel:v1.12.3@sha256:cc8aee9ff0ea3e2af03491caadc18a78da9647cd6e935c9f5cdacbe89acdf694";
    nixSha256 = "sha256-YjVi1L8l9q2AVNPMhi10DA0UrFCtkB5hnj2Biw/xh3w=";
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
      DB_HOST = "pterodactyl-database";
      DB_PORT = "3306";
      DB_DATABASE = "pterodactyl";
      DB_USERNAME = "pterodactyl";
      CACHE_DRIVER = "redis";
      SESSION_DRIVER = "redis";
      QUEUE_CONNECTION = "redis";
      REDIS_HOST = "pterodactyl-redis";
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

  myVirtualization.containers.pterodactyl-panel = panelBaseConfig // {
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

  myVirtualization.containers.pterodactyl-database = {
    rawImageReference = "mariadb:12.2.2@sha256:3ba727e641ef0ea24054e47c72a831b1067da32d5139c0405b629c25b115eb89";
    nixSha256 = "sha256-sicAmjf5KrAfOOeVzme1SQrVNZ2QIt6wBvrmYS3rqE0=";
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

  myVirtualization.containers.pterodactyl-redis = {
    rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
    nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.pterodactyl-daemon = {
    rawImageReference = "ccarney16/pterodactyl-daemon:v1.12.3@sha256:abdbb1827f4d40ce44b51522de99235db08b11e08ccd8fc2e74d5acbe137fd21";
    nixSha256 = "sha256-GNhgUcMfBZYud484HHEVsGNSfsZJsJ05osj0eaqvhoo=";
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

  myVirtualization.containers.pterodactyl-worker = panelBaseConfig // {
    cmd = [ "p:worker" ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.pterodactyl-cron = panelBaseConfig // {
    cmd = [ "p:cron" ];
    labels = {
      "traefik.enable" = "false";
    };
  };
}
