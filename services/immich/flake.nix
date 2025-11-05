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

          immichAppRawImageReference = "ghcr.io/immich-app/immich-server:v2.2.2@sha256:6f57cf359f57f05c89238680b39ca7cd0e135477e11247ad4beb02cc740bbfda";
          immichAppImageReference = parseDockerImageReference immichAppRawImageReference;
          immichAppImage = pkgs.dockerTools.pullImage {
            imageName = immichAppImageReference.name;
            imageDigest = immichAppImageReference.digest;
            finalImageTag = immichAppImageReference.tag;
            sha256 = "sha256-gE8tdXi5yrlGIN614icBNGNZwmPS9z55ZVvleFgSXwo=";
          };

          immichMLRawImageReference = "ghcr.io/immich-app/immich-machine-learning:v2.2.3@sha256:bf339cbb44af6c2ef25d9128e1da51b2bec0cfd524846a83e3017c21bd71ddb4";
          immichMLImageReference = parseDockerImageReference immichMLRawImageReference;
          immichMLImage = pkgs.dockerTools.pullImage {
            imageName = immichMLImageReference.name;
            imageDigest = immichMLImageReference.digest;
            finalImageTag = immichMLImageReference.tag;
            sha256 = "sha256-9FQ7NCrBgozPfHS4c2905eQ1/fdmyjWXGsu/bTng208=";
          };

          immichRedisRawImageReference = "docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177";
          immichRedisImageReference = parseDockerImageReference immichRedisRawImageReference;
          immichRedisImage = pkgs.dockerTools.pullImage {
            imageName = immichRedisImageReference.name;
            imageDigest = immichRedisImageReference.digest;
            finalImageTag = immichRedisImageReference.tag;
            sha256 = "sha256-pRgJXPCztxizPzsRTPvBbNAxLC4XXBtIMKtz3joyLPk=";
          };

          immichDatabaseRawImageReference = "ghcr.io/immich-app/postgres:16-vectorchord0.4.3-pgvectors0.2.0@sha256:1a078b237c1d9b420b0ee59147386b4aa60d3a07a8e6a402fc84a57e41b043a4";
          immichDatabaseImageReference = parseDockerImageReference immichDatabaseRawImageReference;
          immichDatabaseImage = pkgs.dockerTools.pullImage {
            imageName = immichDatabaseImageReference.name;
            imageDigest = immichDatabaseImageReference.digest;
            finalImageTag = immichDatabaseImageReference.tag;
            sha256 = "sha256-ncgVTBG0lwUr3x+yyXv3Exxrv/z89yUXa9xdYOQlU5Y=";
          };
        in
        {
          immich-app = {
            image = immichAppImageReference.name + ":" + immichAppImageReference.tag;
            imageFile = immichAppImage;
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
