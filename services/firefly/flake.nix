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
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          fireflyRawImageReference = "fireflyiii/core:version-6.4.0@sha256:1938b4385ba33e647cc6c1de0234f858ac963229c0156e10f8d1f6b16de10efa";
          fireflyImageReference = parseDockerImageReference fireflyRawImageReference;
          fireflyImage = pkgs.dockerTools.pullImage {
            imageName = fireflyImageReference.name;
            imageDigest = fireflyImageReference.digest;
            finalImageTag = fireflyImageReference.tag;
            sha256 = "sha256-lbRGYi6OT3wVu5w2ylQQROxVj6S6SIW1IaV0oZHKjpk=";
          };

          fintsRawImageReference = "docker.io/benkl/firefly-iii-fints-importer:latest@sha256:c8abed41fdcd5f1f234ee1141c2f006c60b5e1865640fc1e45de738b4bbdef23";
          fintsImageReference = parseDockerImageReference fintsRawImageReference;
          fintsImage = pkgs.dockerTools.pullImage {
            imageName = fintsImageReference.name;
            imageDigest = fintsImageReference.digest;
            finalImageTag = fintsImageReference.tag;
            sha256 = "sha256-R/zqzFFGZwiSuzM17OFsdEYCLkJ0zC50pAuxVad6FSM=";
          };

          alpineRawImageReference = "alpine:3.22.2@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412";
          alpineImageReference = parseDockerImageReference alpineRawImageReference;
          alpineImage = pkgs.dockerTools.pullImage {
            imageName = alpineImageReference.name;
            imageDigest = alpineImageReference.digest;
            finalImageTag = alpineImageReference.tag;
            sha256 = "sha256-j4kP+bImWttrQwre7dYR6A6c9XaYh9lAAXjsKazj0MI=";
          };
        in
        {
          ${appName} = {
            image = fireflyImageReference.name + ":" + fireflyImageReference.tag;
            imageFile = fireflyImage;
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
            image = fintsImageReference.name + ":" + fintsImageReference.tag;
            imageFile = fintsImage;
            # ports = [ "8123:8080" ]; # you only need to enable this during configuration
            extraOptions = [ "--dns=1.1.1.1" ];
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
            image = alpineImageReference.name + ":" + alpineImageReference.tag;
            imageFile = alpineImage;
            volumes = [ "/etc/localtime:/etc/localtime:ro" ];
            extraOptions = [ "--dns=1.1.1.1" ];
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
