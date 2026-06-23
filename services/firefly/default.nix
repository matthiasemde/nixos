{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  getSecretFile,
  ...
}:
let
  appName = "firefly-app";
  fintsName = "firefly-fints";
  cronName = "firefly-cron";
  backendNetwork = "firefly-backend";
in
{
  myVirtualization.networks.${backendNetwork} = "";
  myVirtualization.dependencies.files."/data/services/firefly/app/database/database.sqlite" = "666";

  myVirtualization.containers.${appName} = {
    rawImageReference = "fireflyiii/core:version-6.4.0@sha256:1938b4385ba33e647cc6c1de0234f858ac963229c0156e10f8d1f6b16de10efa";
    nixSha256 = "sha256-lbRGYi6OT3wVu5w2ylQQROxVj6S6SIW1IaV0oZHKjpk=";
    volumes = [
      "/data/services/firefly/app/upload:/var/www/html/storage/upload"
      "/data/services/firefly/app/database/database.sqlite:/var/www/html/storage/database/database.sqlite"
    ];
    networks = [
      "traefik"
      backendNetwork
    ];
    environment = {
      APP_ENV = "local";
      APP_DEBUG = "false";
      SITE_OWNER = config.myInfrastructure.adminEmail;
      DEFAULT_LANGUAGE = "en_US";
      DEFAULT_LOCALE = "de_DE";
      TZ = "Europe/Berlin";
      LOG_CHANNEL = "stderr";
      APP_LOG_LEVEL = "warning";
      AUDIT_LOG_LEVEL = "emergency";
      DB_CONNECTION = "sqlite";
      APP_URL = "https://firefly.${domain}";
      TRUSTED_PROXIES = "**";
    };
    environmentFiles = getEnvFiles "firefly" "app";
    labels =
      (mkTraefikLabels {
        name = "firefly";
        port = "8080";
      })
      // {
        "homepage.group" = "Life Management";
        "homepage.name" = "Firefly";
        "homepage.icon" = "firefly";
        "homepage.href" = "https://firefly.${domain}";
        "homepage.description" = "Finance managment";
      };
  };

  myVirtualization.containers.${fintsName} = {
    rawImageReference = "benkl/firefly-iii-fints-importer:2026-01-04@sha256:52601ec2429f4fe1f9b8898af274de77a899769c34f9d66e3b54f917117251de";
    nixSha256 = "sha256-sttTBaP4t8ug2ewdt0bb2hqlgNQEkwHTkVHRoir6RyQ=";
    volumes = [
      "${getSecretFile "firefly" "fints" "gls.json"}:/data/configurations/gls.json"
      "${
        getSecretFile "firefly" "fints" "gls-tagesgeldkonto.json"
      }:/data/configurations/gls-tagesgeldkonto.json"
    ];
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.${cronName} = {
    rawImageReference = "alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b";
    nixSha256 = "sha256-W4G3seFFuMUMcoPQrAcisPMIWwl4shGDb0tPJpzWd2Q=";
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
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };
}
