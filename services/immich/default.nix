{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "immich-backend";
in
{
  myVirtualization.networks.${backendNetwork} = "";

  myVirtualization.containers.immich.app = {
    rawImageReference = "ghcr.io/immich-app/immich-server:v3.4.1@sha256:7c489add298fc2f92cda4c777de6462aa206877e04087b815f62c7664af0b53b";
    nixSha256 = "sha256-FT8G1/0QH3DWi07OHU2vVefwpjIblF+urW9ypc10b8Q=";
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/data/services/immich/upload:/usr/src/app/upload"
      "/data/nas/files/Bilder:/usr/src/app/external/familie"
      "/data/nas/home/Matthias/Pictures:/usr/src/app/external/matthias"
      "/data/nas/home/Theresa/Bilder:/usr/src/app/external/theresa"
    ];
    networks = [
      backendNetwork
      "traefik"
      "home-assistant-backend"
    ];
    environment = {
      DB_HOSTNAME = "immich--database";
      REDIS_HOSTNAME = "immich--redis";
    };
    environmentFiles = getEnvFiles "immich" "app";
    labels =
      (mkTraefikLabels {
        name = "immich";
        port = "2283";
      })
      // {
        "homepage.group" = "Media";
        "homepage.name" = "Immich";
        "homepage.icon" = "immich";
        "homepage.href" = "https://immich.${domain}";
        "homepage.description" = "Home to all our memories";
      };
  };

  myVirtualization.containers.immich.machine-learning = {
    rawImageReference = "ghcr.io/immich-app/immich-machine-learning:v3.4.1@sha256:8adebf414256f6e4f837bfbb66fa94f14f4da7260e3a1d65cbba49e4e35d8764";
    nixSha256 = "sha256-p3pDECCPZzW0zekKQkdF7ireXqg3A+1UG+NuoO5FKVc=";
    volumes = [ "immich-ml-cache:/cache" ];
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.immich.redis = {
    rawImageReference = "docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177";
    nixSha256 = "sha256-pRgJXPCztxizPzsRTPvBbNAxLC4XXBtIMKtz3joyLPk=";
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

  myVirtualization.containers.immich.database = {
    rawImageReference = "ghcr.io/immich-app/postgres:16-vectorchord0.4.3-pgvectors0.2.0@sha256:1a078b237c1d9b420b0ee59147386b4aa60d3a07a8e6a402fc84a57e41b043a4";
    nixSha256 = "sha256-ncgVTBG0lwUr3x+yyXv3Exxrv/z89yUXa9xdYOQlU5Y=";
    networks = [ backendNetwork ];
    environment = {
      POSTGRES_USER = "postgres";
      POSTGRES_DB = "immich";
      POSTGRES_INITDB_ARGS = "--data-checksums";
    };
    volumes = [ "/data/services/immich/database:/var/lib/postgresql/data" ];
    environmentFiles = getEnvFiles "immich" "database";
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.immich.kiosk = {
    rawImageReference = "ghcr.io/damongolding/immich-kiosk:0.45.2@sha256:2059203dbe7d509f529937a39f2def13d6363254bcc0a4f59d963b726c9e58b6";
    nixSha256 = "sha256-Ng+/3Zr+lAF+v0MTwhWt3lGu7TV/S6YGuMqm95Uv/4s=";
    environment = {
      LANG = "de_DE";
      TZ = "Europe/Berlin";
      KIOSK_IMMICH_URL = "http://immich--app:2283";
      KIOSK_DISABLE_UI = "true";
      KIOSK_DURATION = "600";
      KIOSK_BACKGROUND_BLUR_AMOUNT = "200";
      KIOSK_BEHIND_PROXY = "true";
    };
    environmentFiles = getEnvFiles "immich" "kiosk";
    networks = [
      backendNetwork
      "traefik"
    ];
    labels = mkTraefikLabels {
      name = "immich-kiosk";
      port = "3000";
    };
  };
}
