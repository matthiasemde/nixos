{
  description = "Paperless-NGX container flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "paperless-backend";
    in
    {
      name = "paperless";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        { getServiceEnvFiles, ... }:
        {
          paperless-app = {
            image = "ghcr.io/paperless-ngx/paperless-ngx:2.17.1";
            extraOptions = [ "--dns=1.1.1.1" ];
            environment = {
              "PAPERLESS_URL" = "https://paperless.emdecloud.de";
              "PAPERLESS_ACCOUNT_ALLOW_SIGNUPS" = "false";
              "PAPERLESS_REDIS" = "redis://paperless-redis:6379";

              # SMTP
              "PAPERLESS_EMAIL_HOST" = "mail.privateemail.com";
              "PAPERLESS_EMAIL_PORT" = "465";
              "PAPERLESS_EMAIL_HOST_USER" = "no-reply@emdecloud.de";
              # "PAPERLESS_EMAIL_HOST_PASSWORD" = "password"; # set via secret management;
              "PAPERLESS_EMAIL_USE_SSL" = "true";
            };
            environmentFiles = getServiceEnvFiles "paperless";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/data/services/paperless/app/data:/usr/src/paperless/data"
              "/data/services/paperless/app/media:/usr/src/paperless/media"
              "/data/services/paperless/app/export:/usr/src/paperless/export"
              "/data/services/paperless/app/consume:/usr/src/paperless/consume"
            ];
            networks = [
              "traefik"
              backendNetwork
            ];
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.paperless.rule" = "HostRegexp(`paperless.*`)";
              "traefik.http.routers.paperless.entrypoints" = "websecure";
              "traefik.http.routers.paperless.tls.certresolver" = "myresolver";
              "traefik.http.routers.paperless.tls.domains[0].main" = "paperless.emdecloud.de";
              "traefik.http.services.paperless.loadbalancer.server.port" = "8000";

              # 🏠 Homepage integration
              "homepage.group" = "Life Management";
              "homepage.name" = "Paperless";
              "homepage.icon" = "paperless";
              "homepage.href" = "https://paperless.emdecloud.de";
              "homepage.description" = "Digitize documents";
            };
          };

          paperless-redis = {
            image = "docker.io/library/redis:8";
            volumes = [
              "/data/services/paperless/redis:/data"
            ];
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
