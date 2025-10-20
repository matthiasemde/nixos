{
  description = "Nextcloud container flake";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "nextcloud-backend";
    in
    {
      name = "nextcloud";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        {
          hostname,
          domain,
          mkTraefikLabels,
          getServiceEnvFiles,
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          postgresRawImageReference = "postgres:17@sha256:ae3afa4af0906431de8856bf80a8bcf8a9ea6b3609f9e025f927b949ac93467d";
          postgresImageReference = parseDockerImageReference postgresRawImageReference;
          postgresImage = pkgs.dockerTools.pullImage {
            imageName = postgresImageReference.name;
            imageDigest = postgresImageReference.digest;
            finalImageTag = postgresImageReference.tag;
            sha256 = "sha256-2Nqz+MGNn5nzCYCYETWv8JBN2odoq+RuvJ2LGnWT5d8=";
          };

          redisRawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
          redisImageReference = parseDockerImageReference redisRawImageReference;
          redisImage = pkgs.dockerTools.pullImage {
            imageName = redisImageReference.name;
            imageDigest = redisImageReference.digest;
            finalImageTag = redisImageReference.tag;
            sha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
          };
        in
        {
          nextcloud-app = {
            image = "nextcloud-derived:v32.0.0";
            volumes = [
              "/data/services/nextcloud/app/config:/var/www/html/config"
              "/data/services/nextcloud/app/data:/var/www/html/data"
              "/data/services/nextcloud/app/apps:/var/www/html/apps"
            ];
            networks = [
              backendNetwork
              "traefik"
            ];
            environment = {
              POSTGRES_HOST = "nextcloud-database";
              POSTGRES_DB = "nextcloud";
              POSTGRES_USER = "nextcloud";
              # POSTGRES_PASSWORD = "secure-password" # set via secret management;
              REDIS_HOST = "nextcloud-redis";
              # NEXTCLOUD_ADMIN_USER = "admin";
              # NEXTCLOUD_ADMIN_PASSWORD = "adminpassword" # set via secret management;
              NEXTCLOUD_TRUSTED_DOMAINS = "nextcloud.${domain} nextcloud.${hostname}.local";
              TRUSTED_PROXIES = "172.16.0.0/12";
              # Necessary to allow clients to connect through the reverse proxy
              OVERWRITEPROTOCOL = "https";
              OVERWRITECLIURL = "https://nextcloud.${domain}";
              FORWARDED_FOR_HEADERS = "HTTP_X_FORWARDED_FOR";
            };
            environmentFiles = getServiceEnvFiles "nextcloud";
            labels =
              (mkTraefikLabels {
                name = "nextcloud";
                port = "80";
              })
              // {
                # HSTS middleware
                "traefik.http.routers.nextcloud-public.middlewares" = "nextcloud-headers@docker";
                "traefik.http.middlewares.nextcloud-headers.headers.stsSeconds" = "15552000";
                "traefik.http.middlewares.nextcloud-headers.headers.stsIncludeSubdomains" = "true";
                "traefik.http.middlewares.nextcloud-headers.headers.stsPreload" = "true";

                # 🏠 Homepage integration
                "homepage.group" = "Media";
                "homepage.name" = "Nextcloud";
                "homepage.icon" = "nextcloud";
                "homepage.href" = "https://nextcloud.${domain}";
                "homepage.description" = "Home to all our data";
              };
          };

          nextcloud-database = {
            image = postgresImageReference.name + ":" + postgresImageReference.tag;
            imageFile = postgresImage;
            volumes = [ "/data/services/nextcloud/database:/var/lib/postgresql/data" ];
            networks = [ backendNetwork ];
            environment = {
              POSTGRES_DB = "nextcloud";
              POSTGRES_USER = "nextcloud";
              # POSTGRES_PASSWORD = "secure-password" # set via secret management;
            };
            environmentFiles = getServiceEnvFiles "nextcloud";
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          nextcloud-redis = {
            image = redisImageReference.name + ":" + redisImageReference.tag;
            imageFile = redisImage;
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
