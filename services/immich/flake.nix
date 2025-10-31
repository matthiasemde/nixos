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

          immichAppRawImageReference = "ghcr.io/immich-app/immich-server:v2.2.0@sha256:90627507693076ec068415daba4d617e48a876ad8069c8cc7e1bc1fdd6f9392b";
          immichAppImageReference = parseDockerImageReference immichAppRawImageReference;
          immichAppImage = pkgs.dockerTools.pullImage {
            imageName = immichAppImageReference.name;
            imageDigest = immichAppImageReference.digest;
            finalImageTag = immichAppImageReference.tag;
            sha256 = "sha256-6/qPGaNO1/neGLbDNyI2qnQddLC6HHZjnXhmhKf3RxE=";
          };

          immichMLRawImageReference = "ghcr.io/immich-app/immich-machine-learning:v2.2.0@sha256:5df77af74af072f1552720d72f1838f63a60d7173d4187ab014686ccd18b567e";
          immichMLImageReference = parseDockerImageReference immichMLRawImageReference;
          immichMLImage = pkgs.dockerTools.pullImage {
            imageName = immichMLImageReference.name;
            imageDigest = immichMLImageReference.digest;
            finalImageTag = immichMLImageReference.tag;
            sha256 = "sha256-Gd8A/3JU7ZjY8vRj7sIZA/+gq7w2kKIiO0IFHSj15KA=";
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
