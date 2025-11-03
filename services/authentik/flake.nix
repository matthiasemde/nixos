{
  description = "Authentik SSO service";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "authentik-backend";
      env = {
        # SMTP Config
        "AUTHENTIK_EMAIL__HOST" = "mail.privateemail.com";
        "AUTHENTIK_EMAIL__PORT" = "465";
        # "AUTHENTIK_EMAIL__USERNAME" = ""; # set via secret-mgmt
        # "AUTHENTIK_EMAIL__PASSWORD" = ""; # set via secret-mgmt
        # Use StartTLS
        "AUTHENTIK_EMAIL__USE_TLS" = "false";
        # Use SSL
        "AUTHENTIK_EMAIL__USE_SSL" = "true";
        "AUTHENTIK_EMAIL__TIMEOUT" = "30";
        # Email address authentik will send from, should have a correct @domain
        "AUTHENTIK_EMAIL__FROM" = "no-reply@emdecloud.de"; # Authentik Event < my.email.address@gmail.com >
      };
    in
    {
      name = "authentik";
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

          authentikRawImageReference = "ghcr.io/goauthentik/server:2025.10.1@sha256:8f70895ad48bb7de656a2aac7c78c2bec6a4e820e009a570b0c285fe406eadac";
          authentikImageReference = parseDockerImageReference authentikRawImageReference;
          authentikImage = pkgs.dockerTools.pullImage {
            imageName = authentikImageReference.name;
            imageDigest = authentikImageReference.digest;
            finalImageTag = authentikImageReference.tag;
            sha256 = "sha256-vBRm6C1nIrF7VSqTm/tdHjPWIFO6SkJtuLkA8sxF26A=";
          };

          postgresRawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
          postgresImageReference = parseDockerImageReference postgresRawImageReference;
          postgresImage = pkgs.dockerTools.pullImage {
            imageName = postgresImageReference.name;
            imageDigest = postgresImageReference.digest;
            finalImageTag = postgresImageReference.tag;
            sha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
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
          authentik-database = {
            image = postgresImageReference.name + ":" + postgresImageReference.tag;
            imageFile = postgresImage;
            environment = env // {
              "POSTGRES_USER" = "authentik";
              # "POSTGRES_PASSWORD" = "password"; # set via secret-mgmt
              "POSTGRES_DB" = "authentik";
            };
            environmentFiles = getServiceEnvFiles "authentik";
            volumes = [
              "/data/services/authentik/database:/var/lib/postgresql/18/docker"
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
            environment = env // {
              "AUTHENTIK_POSTGRESQL__HOST" = "authentik-database";
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
            labels =
              (mkTraefikLabels {
                name = "auth";
                port = "9000";
              })
              // {
                "homepage.group" = "Utilities";
                "homepage.name" = "Authentik";
                "homepage.icon" = "authentik";
                "homepage.href" = "https://auth.${domain}";
                "homepage.description" = "SSO Provider";
              };
          };

          authentik-worker = {
            image = authentikImageReference.name + ":" + authentikImageReference.tag;
            imageFile = authentikImage;
            cmd = [ "worker" ];
            environment = env // {
              "AUTHENTIK_POSTGRESQL__HOST" = "authentik-database";
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
