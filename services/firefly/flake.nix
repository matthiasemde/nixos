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
          getServiceEnvFiles,
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
              LOG_CHANNEL = "stack";
              APP_LOG_LEVEL = "notice";
              AUDIT_LOG_LEVEL = "emergency";
              DB_CONNECTION = "sqlite";
              APP_URL = "https://firefly.${domain}";
              TRUSTED_PROXIES = "**";
            };
            environmentFiles = getServiceEnvFiles name;
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
            rawImageReference = "docker.io/benkl/firefly-iii-fints-importer:latest@sha256:c8abed41fdcd5f1f234ee1141c2f006c60b5e1865640fc1e45de738b4bbdef23";
            nixSha256 = "sha256-R/zqzFFGZwiSuzM17OFsdEYCLkJ0zC50pAuxVad6FSM=";
            # ports = [ "8123:8080" ]; # you only need to enable this during configuration
            volumes = [
              "/run/agenix/firefly-gls.json:/data/configurations/gls.json"
              "/run/agenix/firefly-gls-tagesgeldkonto.json:/data/configurations/gls-tagesgeldkonto.json"
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
            rawImageReference = "alpine:3.23.2@sha256:c93cec902b6a0c6ef3b5ab7c65ea36beada05ec1205664a4131d9e8ea13e405d";
            nixSha256 = "sha256-OGF7lmDWGB6zg63bYyV1UDTWHCzTejvlZJw5w47CElY=";
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
