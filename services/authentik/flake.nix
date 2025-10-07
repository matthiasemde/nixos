{
  description = "Authentik SSO service";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

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
        { getServiceEnvFiles, ... }:
        {
          authentik-db = {
            image = "docker.io/library/postgres:16-alpine";
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
            image = "docker.io/library/redis:alpine";
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
            image = "ghcr.io/goauthentik/server:2025.8.4";
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
            image = "ghcr.io/goauthentik/server:2025.8.4";
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
