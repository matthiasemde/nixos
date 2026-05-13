{
  description = "Immich container flake";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "immich-backend";
    in
    {
      name = "immich";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        {
          domain,
          mkTraefikLabels,
          getContainerEnvFiles,
          ...
        }:
        {
          immich-app = {
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
              DB_HOSTNAME = "immich-database";
              REDIS_HOSTNAME = "immich-redis";
            };
            environmentFiles = getContainerEnvFiles "app";
            labels =
              (mkTraefikLabels {
                name = "immich";
                port = "2283";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Media";
                "homepage.name" = "Immich";
                "homepage.icon" = "immich";
                "homepage.href" = "https://immich.${domain}";
                "homepage.description" = "Home to all our memories";
              };
          };

          immich-machine-learning = {
            rawImageReference = "ghcr.io/immich-app/immich-machine-learning:v2.7.5@sha256:a2501141440f10516d329fdfba2c68082e19eb9ba6016c061ac80d23beadf7f3";
            nixSha256 = "sha256-SAaFwRI8VQujL8tiEoRW33J57GqdeJ66Re/BdxRO9Hs=";
            volumes = [ "immich-ml-cache:/cache" ];
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-redis = {
            rawImageReference = "docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177";
            nixSha256 = "sha256-pRgJXPCztxizPzsRTPvBbNAxLC4XXBtIMKtz3joyLPk=";
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-database = {
            rawImageReference = "ghcr.io/immich-app/postgres:16-vectorchord0.4.3-pgvectors0.2.0@sha256:1a078b237c1d9b420b0ee59147386b4aa60d3a07a8e6a402fc84a57e41b043a4";
            nixSha256 = "sha256-ncgVTBG0lwUr3x+yyXv3Exxrv/z89yUXa9xdYOQlU5Y=";
            networks = [ backendNetwork ];
            environment = {
              # POSTGRES_PASSWORD = set via secret management (use only the characters `A-Za-z0-9`);
              POSTGRES_USER = "postgres";
              POSTGRES_DB = "immich";
              POSTGRES_INITDB_ARGS = "--data-checksums";
            };
            volumes = [ "/data/services/immich/database:/var/lib/postgresql/data" ];
            environmentFiles = getContainerEnvFiles "database";
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-kiosk = {
            rawImageReference = "ghcr.io/damongolding/immich-kiosk:0.38.1@sha256:28cf751b556e5c9fefc18f0c2b0ed2d6fe672df734ca3c860d6adc9b2b7fdffb";
            nixSha256 = "sha256-X0BPuNpWR6p0q7mIn+JTFJVN/UseRqikYsmFURpgEMM=";
            environment = {
              LANG = "de_DE";
              TZ = "Europe/Berlin";
              KIOSK_IMMICH_URL = "http://immich-app:2283";
              KIOSK_DISABLE_UI = "true";
              KIOSK_DURATION = "3600"; # 1 hour
              KIOSK_BACKGROUND_BLUR_AMOUNT = "200";
              KIOSK_BEHIND_PROXY = "true";
            };
            environmentFiles = getContainerEnvFiles "kiosk";
            networks = [
              backendNetwork
              "traefik"
            ];
            labels = mkTraefikLabels {
              name = "immich-kiosk";
              port = "3000";
            };
          };
        };
    };
}
