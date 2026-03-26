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
          getServiceEnvFiles,
          ...
        }:
        {
          immich-app = {
            rawImageReference = "ghcr.io/immich-app/immich-server:v2.6.3@sha256:0cc1f82953d9598eb9e9dd11cbde1f50fe54f9c46c4506b089e8ad7bfc9d1f0c";
            nixSha256 = "sha256-gk2+L9TS/3/icxEOIcS/kj83aFzHO/4KZ0nT0PVG2oQ=";
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
            environmentFiles = getServiceEnvFiles "immich";
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
            rawImageReference = "ghcr.io/immich-app/immich-machine-learning:v2.6.3@sha256:33b17015c3d14f2565e9b8cd36b48a70027b14b5cd20da7fbfff21a370b0309c";
            nixSha256 = "sha256-5LTrhj51O87c119CWC+J56rv2CV7JMF6eAz/Yx8KupM=";
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
            environmentFiles = getServiceEnvFiles "immich";
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
