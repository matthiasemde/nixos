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
    rawImageReference = "ghcr.io/immich-app/immich-server:v3.3.1@sha256:db996e352359771c6a3db121a0ed8761516b22f727fc092a0f46dcfef82c1bc1";
    nixSha256 = "sha256-p2IKZBVovHyWo/NOVA4uLrkHGZ1hZp8wnryMG7802Tk=";
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
    rawImageReference = "ghcr.io/immich-app/immich-machine-learning:v3.3.1@sha256:513c831cfb010ad319341a0c86b42c575a0d5b688d3e8cae346ee624074a58ed";
    nixSha256 = "sha256-48lX0VIieluZrtmDyoxaF8DUcxLNPG3CWZ2EbaQQ9/A=";
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
    rawImageReference = "ghcr.io/damongolding/immich-kiosk:0.44.2@sha256:9df90bf970b7c0428e97c58de672cb23d08380dbf6d12420d07154dffa149b55";
    nixSha256 = "sha256-sJUJk4JHA8aIgk8aDmdMAEBz8+IRRX02ccSk1nSi8vQ=";
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
