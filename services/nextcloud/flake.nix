{
  description = "Nextcloud container flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

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
        { hostname, getServiceEnvFiles, ... }:
        {
          nextcloud-app = {
            image = "nextcloud-derived:v1.1.1";
            volumes = [
              "/data/services/nextcloud/app:/var/www/html"
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
              NEXTCLOUD_ADMIN_USER = "admin";
              # NEXTCLOUD_ADMIN_PASSWORD = "adminpassword" # set via secret management;
              NEXTCLOUD_TRUSTED_DOMAINS = "nextcloud.emdecloud.de nextcloud.mahler.local";
              # Necessary to allow clients to connect through the reverse proxy
              OVERWRITEPROTOCOL = "https";
              OVERWRITECLIURL = "https://nextcloud.emdecloud.de";
            };
            environmentFiles = getServiceEnvFiles "nextcloud";
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.nextcloud.rule" = "HostRegexp(`nextcloud.*`)";
              "traefik.http.routers.nextcloud.entrypoints" = "websecure";
              "traefik.http.routers.nextcloud.tls.certresolver" = "myresolver";
              "traefik.http.routers.nextcloud.tls.domains[0].main" = "nextcloud.emdecloud.de";
              "traefik.http.services.nextcloud.loadbalancer.server.port" = "80";

              # 🏠 Homepage integration
              "homepage.group" = "Media";
              "homepage.name" = "Nextcloud";
              "homepage.icon" = "nextcloud";
              "homepage.href" = "https://nextcloud.emdecloud.de";
              "homepage.description" = "Home to all our data";
            };
          };

          nextcloud-database = {
            image = "postgres:15";
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
            image = "redis:7";
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
