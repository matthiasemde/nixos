{
  description = "Authentik SSO service";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "authentik-backend";
    in
    {
      name = "authentik";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        { getServiceEnvFiles, parseDockerImageReference, ... }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          authentikRawImageReference = "ghcr.io/goauthentik/server:2025.8.4@sha256:a10398480e7f8292dbcc27b64fe572f6abed6220bd40f4b6d28e9c12d4b78dca";
          authentikImageReference = parseDockerImageReference authentikRawImageReference;
          authentikImage = pkgs.dockerTools.pullImage {
            imageName = authentikImageReference.name;
            imageDigest = authentikImageReference.digest;
            finalImageTag = authentikImageReference.tag;
            sha256 = "sha256-WaBINdtyR4hKfZs5VW47p+WVrQuwqHkYEWIhw4pWs88=";
          };

          postgresRawImageReference = "docker.io/library/postgres:16-alpine@sha256:e75afc5bf90e2cad3f0ee2395ccbc31db663cd10d1d9cabd0de3c99fe4aa5bab";
          postgresImageReference = parseDockerImageReference postgresRawImageReference;
          postgresImage = pkgs.dockerTools.pullImage {
            imageName = postgresImageReference.name;
            imageDigest = postgresImageReference.digest;
            finalImageTag = postgresImageReference.tag;
            sha256 = "sha256-neAQQa92onE6d43OqSSpCBmLA1q5Mykydp1mRFiHPHI=";
          };

          redisRawImageReference = "docker.io/library/redis:8@sha256:b83648c7ab6752e1f52b88ddf5dabc11987132336210d26758f533fb01325865";
          redisImageReference = parseDockerImageReference redisRawImageReference;
          redisImage = pkgs.dockerTools.pullImage {
            imageName = redisImageReference.name;
            imageDigest = redisImageReference.digest;
            finalImageTag = redisImageReference.tag;
            sha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
          };
        in
        {
          authentik-db = {
            image = postgresImageReference.name + ":" + postgresImageReference.tag;
            imageFile = postgresImage;
            environment = {
              "POSTGRES_USER" = "authentik";
              # "POSTGRES_PASSWORD" = "password"; # set via secret-mgmt
              "POSTGRES_DB" = "authentik";
            };
            environmentFiles = getServiceEnvFiles "authentik";
            volumes = [
              "/data/services/authentik/db:/var/lib/postgresql/data"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };

          authentik-redis = {
            image = redisImageReference.name + ":" + redisImageReference.tag;
            imageFile = redisImage;
            cmd = [
              "--save"
              "60"
              "1"
              "--loglevel"
              "warning"
            ];
            volumes = [
              "/data/services/authentik/redis:/data"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };

          authentik-server = {
            image = authentikImageReference.name + ":" + authentikImageReference.tag;
            imageFile = authentikImage;
            cmd = [ "server" ];
            environment = {
              "AUTHENTIK_POSTGRESQL__HOST" = "authentik-db";
              "AUTHENTIK_POSTGRESQL__NAME" = "authentik";
              # "AUTHENTIK_POSTGRESQL__PASSWORD" = "password"; # set via secret-mgmt
              "AUTHENTIK_POSTGRESQL__USER" = "authentik";
              "AUTHENTIK_REDIS__HOST" = "authentik-redis";
              # "AUTHENTIK_SECRET_KEY" = "secret-key"; # set via secret-mgmt
            };
            environmentFiles = getServiceEnvFiles "authentik";
            volumes = [
              "/data/services/authentik/media:/media"
              "/data/services/authentik/custom-templates:/templates"
            ];
            networks = [
              "traefik"
              backendNetwork
            ];
            labels = {
              "traefik.enable" = "true";
              "traefik.http.routers.authentik.rule" = "HostRegexp(`auth.*`)";
              "traefik.http.routers.authentik.entrypoints" = "websecure";
              "traefik.http.routers.authentik.tls.certresolver" = "myresolver";
              "traefik.http.routers.authentik.tls.domains[0].main" = "auth.emdecloud.de";
              "traefik.http.services.authentik.loadbalancer.server.port" = "9000";

              "homepage.group" = "Security";
              "homepage.name" = "Authentik";
              "homepage.icon" = "authentik";
              "homepage.href" = "https://auth.emdecloud.de";
              "homepage.description" = "SSO Provider";
            };
          };

          authentik-worker = {
            image = authentikImageReference.name + ":" + authentikImageReference.tag;
            imageFile = authentikImage;
            cmd = [ "worker" ];
            environment = {
              "AUTHENTIK_POSTGRESQL__HOST" = "authentik-db";
              "AUTHENTIK_POSTGRESQL__NAME" = "authentik";
              # "AUTHENTIK_POSTGRESQL__PASSWORD" = "password"; # set via secret-mgmt
              "AUTHENTIK_POSTGRESQL__USER" = "authentik";
              "AUTHENTIK_REDIS__HOST" = "authentik-redis";
            };
            environmentFiles = getServiceEnvFiles "authentik";
            user = "root";
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/data/services/authentik/media:/media"
              "/data/services/authentik/certs:/certs"
              "/data/services/authentik/custom-templates:/templates"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };
        };
    };
}
