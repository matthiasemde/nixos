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
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          immichAppRawImageReference = "ghcr.io/immich-app/immich-server:v2.0.1@sha256:8286638680f0a38a7cb380be64ed77d1d1cfe6d0e0b843f64bff92b24289078d";
          immichAppImageReference = parseDockerImageReference immichAppRawImageReference;
          immichAppImage = pkgs.dockerTools.pullImage {
            imageName = immichAppImageReference.name;
            imageDigest = immichAppImageReference.digest;
            finalImageTag = immichAppImageReference.tag;
            sha256 = "sha256-+GPEc4qDt8iMwKcw6yeZCuLM/F2LA3/xFFTj+qo22RE=";
          };

          immichMLRawImageReference = "ghcr.io/immich-app/immich-machine-learning:v2.0.1@sha256:45626a33361ef7ed361de41b0d2dc19e5949442cdf0a8eb64b157dc8a04e9855";
          immichMLImageReference = parseDockerImageReference immichMLRawImageReference;
          immichMLImage = pkgs.dockerTools.pullImage {
            imageName = immichMLImageReference.name;
            imageDigest = immichMLImageReference.digest;
            finalImageTag = immichMLImageReference.tag;
            sha256 = "sha256-S7yNuTrPAbI8Qcx+x9PVElQVjDkEqHquVlzNivgEZPM=";
          };

          immichRedisRawImageReference = "docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177";
          immichRedisImageReference = parseDockerImageReference immichRedisRawImageReference;
          immichRedisImage = pkgs.dockerTools.pullImage {
            imageName = immichRedisImageReference.name;
            imageDigest = immichRedisImageReference.digest;
            finalImageTag = immichRedisImageReference.tag;
            sha256 = "sha256-pRgJXPCztxizPzsRTPvBbNAxLC4XXBtIMKtz3joyLPk=";
          };

          immichDatabaseRawImageReference = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:41eacbe83eca995561fe43814fd4891e16e39632806253848efaf04d3c8a8b84";
          immichDatabaseImageReference = parseDockerImageReference immichDatabaseRawImageReference;
          immichDatabaseImage = pkgs.dockerTools.pullImage {
            imageName = immichDatabaseImageReference.name;
            imageDigest = immichDatabaseImageReference.digest;
            finalImageTag = immichDatabaseImageReference.tag;
            sha256 = "sha256-kEW12MDS2g1naTj4NZCUuEiuP39zEZXeuvTqIcJHZYs=";
          };
        in
        {
          immich-app = {
            image = immichAppImageReference.name + ":" + immichAppImageReference.tag;
            imageFile = immichAppImage;
            extraOptions = [ "--dns=1.1.1.1" ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/data/services/immich/upload:/usr/src/app/upload"
              "/data/nas/files/Bilder:/usr/src/app/external/familie:ro"
              "/data/nas/home/Matthias/Pictures:/usr/src/app/external/matthias:ro"
              "/data/nas/home/Theresa/Bilder:/usr/src/app/external/theresa:ro"
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
            image = immichMLImageReference.name + ":" + immichMLImageReference.tag;
            imageFile = immichMLImage;
            volumes = [ "immich-ml-cache:/cache" ];
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-redis = {
            image = immichRedisImageReference.name + ":" + immichRedisImageReference.tag;
            imageFile = immichRedisImage;
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-database = {
            image = immichDatabaseImageReference.name + ":" + immichDatabaseImageReference.tag;
            imageFile = immichDatabaseImage;
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
