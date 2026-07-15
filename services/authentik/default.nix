{
  config,
  lib,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "authentik-backend";
  cfg = config.authentik;

  env = {
    "AUTHENTIK_EMAIL__HOST" = config.myInfrastructure.smtp.host;
    "AUTHENTIK_EMAIL__PORT" = toString config.myInfrastructure.smtp.port;
    "AUTHENTIK_EMAIL__USE_TLS" = "false";
    "AUTHENTIK_EMAIL__USE_SSL" = "true";
    "AUTHENTIK_EMAIL__TIMEOUT" = "30";
    "AUTHENTIK_EMAIL__FROM" = config.myInfrastructure.smtp.fromAddress;
  };
in
{
  options.authentik = {
    enableStack = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the full Authentik stack (database, Redis, server, worker).";
    };
    enableOutpost = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the Authentik proxy outpost.";
    };
  };

  config = {
    myVirtualization.networks.${backendNetwork} = lib.mkIf cfg.enableStack "";

    myVirtualization.containers.authentik.database = lib.mkIf cfg.enableStack {
      rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
      nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
      environment = env // {
        "POSTGRES_USER" = "authentik";
        "POSTGRES_DB" = "authentik";
      };
      environmentFiles = getEnvFiles "authentik" "database";
      volumes = [
        "/data/services/authentik/database:/var/lib/postgresql/18/docker"
      ];
      networks = [ backendNetwork ];
      cmd = [
        "postgres"
        "-c"
        "log_checkpoints=off"
      ];
      labels = {
        "traefik.enable" = "false";
      };
    };

    myVirtualization.containers.authentik.redis = lib.mkIf cfg.enableStack {
      rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
      nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
      cmd = [
        "redis-server"
        "--loglevel"
        "warning"
      ];
      networks = [ backendNetwork ];
      labels = {
        "traefik.enable" = "false";
      };
    };

    myVirtualization.containers.authentik.server = lib.mkIf cfg.enableStack {
      rawImageReference = "ghcr.io/goauthentik/server:2026.5.4@sha256:a8e80071e5938cca7c8d03461a56740041f274d721100974e042b6d265001f50";
      nixSha256 = "sha256-l3+lqsxQtqaJdKFxZCyWPALyWp8fttDa9HbdqdaXVCk=";
      cmd = [ "server" ];
      environment = env // {
        "AUTHENTIK_POSTGRESQL__HOST" = "authentik--database";
        "AUTHENTIK_POSTGRESQL__NAME" = "authentik";
        "AUTHENTIK_POSTGRESQL__USER" = "authentik";
        "AUTHENTIK_REDIS__HOST" = "authentik--redis";
        "AUTHENTIK_LOG_LEVEL" = "warning";
      };
      environmentFiles = getEnvFiles "authentik" "server";
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

    myVirtualization.containers.authentik.worker = lib.mkIf cfg.enableStack {
      rawImageReference = "ghcr.io/goauthentik/server:2026.5.4@sha256:a8e80071e5938cca7c8d03461a56740041f274d721100974e042b6d265001f50";
      nixSha256 = "sha256-l3+lqsxQtqaJdKFxZCyWPALyWp8fttDa9HbdqdaXVCk=";
      cmd = [ "worker" ];
      environment = env // {
        "AUTHENTIK_POSTGRESQL__HOST" = "authentik--database";
        "AUTHENTIK_POSTGRESQL__NAME" = "authentik";
        "AUTHENTIK_POSTGRESQL__USER" = "authentik";
        "AUTHENTIK_REDIS__HOST" = "authentik--redis";
        "AUTHENTIK_LOG_LEVEL" = "warning";
      };
      environmentFiles = getEnvFiles "authentik" "worker";
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

    myVirtualization.containers.authentik.outpost-infra = lib.mkIf cfg.enableOutpost {
      rawImageReference = "ghcr.io/goauthentik/proxy:2026.5.5@sha256:6bb49066864e71b36a55cf91e5e75390625a808cc9fe365851e14b0978694d2e";
      nixSha256 = "sha256-adX7BwCIc51ZjENNFO3t7UEWwDyVHP43n/hk7O4zKNA=";
      environment = {
        "AUTHENTIK_HOST" = "https://auth.emdecloud.de";
        "AUTHENTIK_INSECURE" = "true";
        # "AUTHENTIK_TOKEN" = "my-token"; # set via secret-mgmt
        # "AUTHENTIK_LOG_LEVEL" = "warning"; # does not work - log level has to be set in the authentik outpost settings (warning not warn)
      };
      environmentFiles = getEnvFiles "authentik" "outpost-infra";
      networks = [ "traefik" ];
      labels = mkTraefikLabels {
        name = "authentik-outpost-infra";
        port = "9000";
        allowedPaths = [ "/outpost.goauthentik.io/" ];
      };
    };
  };
}
