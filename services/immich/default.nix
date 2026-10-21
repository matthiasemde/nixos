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
    rawImageReference = "ghcr.io/immich-app/immich-server:v3.3.5@sha256:485d546a2e31d6a8b4db8423fcba5c109de8c218d93410af115fd1ccfc4352a6";
    nixSha256 = "sha256-pGxdm3yvAwR0Ai0+xZ0TAurUSFbCwQuh4WvG6PCnC2U=";
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
    rawImageReference = "ghcr.io/immich-app/immich-machine-learning:v3.3.5@sha256:5b28c9352c8374b8a1ed96fbdd8d6755fea6e43510ec43fdf6538aa02ea40f56";
    nixSha256 = "sha256-ib76IBJfvx/lJHXp9C4Fj1l47NB1DkZFGLqe0kCE88E=";
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
    rawImageReference = "ghcr.io/damongolding/immich-kiosk:0.45.1@sha256:4f03ec4f6ef2a562ad79dbcf5330a26a8d8565f95b31a26f45afe74d2fc22d98";
    nixSha256 = "sha256-Oeg5IYzf8HVnbxP1LOOop0faf0T1XsE3IQeEeiy/EUI=";
    environment = {
      LANG = "de_DE";
      TZ = "Europe/Berlin";
      KIOSK_IMMICH_URL = "http://immich--app:2283";
      KIOSK_DISABLE_UI = "true";
      KIOSK_DURATION = "3600";
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
