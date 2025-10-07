{
  description = "Immich container flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

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
        { hostname, getServiceEnvFiles, ... }:
        let
          version = "v1.142.1";
        in
        {
          immich-app = {
            image = "ghcr.io/immich-app/immich-server:${version}";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/data/services/immich/upload:/usr/src/app/upload"
              "/data/nas/files/Bilder:/usr/src/app/external/familie:ro"
              "/data/nas/home/Matthias/Bilder:/usr/src/app/external/matthias:ro"
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
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.immich.rule" = "HostRegexp(`immich.*`)";
              "traefik.http.routers.immich.entrypoints" = "websecure";
              "traefik.http.routers.immich.tls.certresolver" = "myresolver";
              "traefik.http.routers.immich.tls.domains[0].main" = "immich.emdecloud.de";
              "traefik.http.services.immich.loadbalancer.server.port" = "2283";

              # 🏠 Homepage integration
              "homepage.group" = "Media";
              "homepage.name" = "Immich";
              "homepage.icon" = "immich";
              "homepage.href" = "https://immich.emdecloud.de";
              "homepage.description" = "Home to all our memories";
            };
          };

          immich-machine-learning = {
            image = "ghcr.io/immich-app/immich-machine-learning:${version}";
            volumes = [ "immich-ml-cache:/cache" ];
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-redis = {
            image = "docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177";
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          immich-database = {
            image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
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
