{
  description = "Firefly III service flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

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
        { getServiceEnvFiles, ... }:
        {
          ${appName} = {
            image = "fireflyiii/core:version-6.4.0";
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
              APP_URL = "https://firefly.emdecloud.de";
              TRUSTED_PROXIES = "**";
            };
            environmentFiles = getServiceEnvFiles name;
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.${appName}.rule" = "HostRegexp(`firefly.*`)";
              "traefik.http.routers.${appName}.entrypoints" = "websecure";
              "traefik.http.routers.${appName}.tls.certresolver" = "myresolver";
              "traefik.http.routers.${appName}.tls.domains[0].main" = "firefly.emdecloud.de";
              "traefik.http.services.${appName}.loadbalancer.server.port" = "8080";

              # 🏠 Homepage integration
              "homepage.group" = "Life Management";
              "homepage.name" = "Firefly";
              "homepage.icon" = "firefly";
              "homepage.href" = "https://firefly.emdecloud.de";
              "homepage.description" = "Finance managment";
            };
          };

          ${fintsName} = {
            image = "docker.io/benkl/firefly-iii-fints-importer:latest";
            # ports = [ "8123:8080" ]; # you only need to enable this during configuration
            extraOptions = [ "--dns=1.1.1.1" ];
            volumes = [
              "/run/agenix/firefly-gls.json:/data/configurations/gls.json"
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
            image = "alpine";
            volumes = [ "/etc/localtime:/etc/localtime:ro" ];
            extraOptions = [ "--dns=1.1.1.1" ];
            cmd = [
              "sh"
              "-c"
              ''
                apk add --no-cache tzdata && \
                echo "0 3 * * * wget -O - -q 'http://firefly-fints:8080/?automate=true&config=gls.json'; echo" | crontab - && \
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
