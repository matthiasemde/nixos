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
    rawImageReference = "ghcr.io/immich-app/immich-server:v2.7.5@sha256:c15bff75068effb03f4355997d03dc7e0fc58720c2b54ad6f7f10d1bc57efaa5";
    nixSha256 = "sha256-NYgLfm8rX8o3GYLoavG8i3gqwyKKLIeJLXGGYLZUazY=";
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
    rawImageReference = "ghcr.io/immich-app/immich-machine-learning:v2.7.5@sha256:a2501141440f10516d329fdfba2c68082e19eb9ba6016c061ac80d23beadf7f3";
    nixSha256 = "sha256-SAaFwRI8VQujL8tiEoRW33J57GqdeJ66Re/BdxRO9Hs=";
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
    rawImageReference = "ghcr.io/damongolding/immich-kiosk:0.39.3@sha256:b65371b9fbe93cde8355c06ba095fb4801bbb5d7c8c51065a5bfa02183536771";
    nixSha256 = "sha256-ik2Mc3cbPmVg511wivMqttC3ZAOLXCP80CeI+LcmjKg=";
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
