{
  description = "Firefly III service flake";

  outputs =
    { self, nixpkgs }:
    let
      name = "firefly";
      appName = "${name}-app";
      fintsName = "${name}-fints";
      cronName = "${name}-cron";
      backendNetwork = "firefly-backend";
    in
    {
      inherit name;
      dependencies = {
        files = {
          "/data/services/firefly/app/database/database.sqlite" = "666";
        };
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        {
          domain,
          mkTraefikLabels,
          getContainerEnvFiles,
          ...
        }:
        {
          ${appName} = {
            rawImageReference = "fireflyiii/core:version-6.4.0@sha256:1938b4385ba33e647cc6c1de0234f858ac963229c0156e10f8d1f6b16de10efa";
            nixSha256 = "sha256-lbRGYi6OT3wVu5w2ylQQROxVj6S6SIW1IaV0oZHKjpk=";
            volumes = [
              "/data/services/firefly/app/upload:/var/www/html/storage/upload"
              "/data/services/firefly/app/database/database.sqlite:/var/www/html/storage/database/database.sqlite"
            ];
            networks = [
              "traefik"
              "${backendNetwork}"
            ];
            environment = {
              APP_ENV = "local";
              APP_DEBUG = "false";
              SITE_OWNER = "matthias@emdemail.de";
              DEFAULT_LANGUAGE = "en_US";
              DEFAULT_LOCALE = "de_DE";
              TZ = "Europe/Berlin";
              LOG_CHANNEL = "stderr";
              APP_LOG_LEVEL = "notice";
              AUDIT_LOG_LEVEL = "emergency";
              DB_CONNECTION = "sqlite";
              APP_URL = "https://firefly.${domain}";
              TRUSTED_PROXIES = "**";
            };
            environmentFiles = getContainerEnvFiles "app";
            labels =
              (mkTraefikLabels {
                name = "firefly";
                port = "8080";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Life Management";
                "homepage.name" = "Firefly";
                "homepage.icon" = "firefly";
                "homepage.href" = "https://firefly.${domain}";
                "homepage.description" = "Finance managment";
              };
          };

          ${fintsName} = {
            rawImageReference = "benkl/firefly-iii-fints-importer:2026-01-04@sha256:52601ec2429f4fe1f9b8898af274de77a899769c34f9d66e3b54f917117251de";
            nixSha256 = "sha256-sttTBaP4t8ug2ewdt0bb2hqlgNQEkwHTkVHRoir6RyQ=";
            # ports = [ "8123:8080" ]; # you only need to enable this during configuration
            volumes = [
              "/run/secrets/firefly-fints-gls.json:/data/configurations/gls.json"
              "/run/secrets/firefly-fints-gls-tagesgeldkonto.json:/data/configurations/gls-tagesgeldkonto.json"
            ];
            networks = [
              "${backendNetwork}"
            ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          ${cronName} = {
            rawImageReference = "alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11";
            nixSha256 = "sha256-svJI+DpSqhR8OnybK3+AefJnjcG0ry46R2aWII21Bdg=";
            volumes = [ "/etc/localtime:/etc/localtime:ro" ];
            cmd = [
              "sh"
              "-c"
              ''
                apk add --no-cache tzdata && \
                ( crontab -l 2>/dev/null; \
                  echo "0 3 * * * wget -O - -q 'http://firefly-fints:8080/?automate=true&config=gls.json'; echo"; \
                  echo "5 3 * * * wget -O - -q 'http://firefly-fints:8080/?automate=true&config=gls-tagesgeldkonto.json'; echo" ) | crontab - && \
                crond -f -L /dev/stdout
              ''
            ];
            networks = [
              "${backendNetwork}"
            ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
