{
  config,
  lib,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "mealie-backend";
in
{
  options.mealie.oidcClientId = lib.mkOption {
    type = lib.types.str;
    description = "Mealie OIDC client ID registered in Authentik.";
  };

  config = {
    myVirtualization.networks.${backendNetwork} = "";

    myVirtualization.containers.mealie.app = {
      rawImageReference = "ghcr.io/mealie-recipes/mealie:v3.31.0@sha256:e0c056e730122abd92e611af811c29bbad94c6018572180369cd9f3797e49a05";
      nixSha256 = "sha256-rt7hhkdU4eJ5WGP+j5PY6Ylv/P00n7xaaBDjukCYFto=";
      environment = {
        "BASE_URL" = "https://mealie.${domain}";
        "DEFAULT_GROUP" = "Default";
        "DEFAULT_HOUSEHOLD" = "Default";
        "PUID" = "1000";
        "PGID" = "1000";
        "TZ" = "Europe/Berlin";
        "DB_ENGINE" = "postgres";
        "POSTGRES_USER" = "mealie";
        "POSTGRES_SERVER" = "mealie--database";
        "POSTGRES_PORT" = "5432";
        "POSTGRES_DB" = "mealie";
        "ALLOW_SIGNUP" = "false";
        "ALLOW_PASSWORD_LOGIN" = "false";
        "AUTO_BACKUP_ENABLED" = "true";
        "MAX_WORKERS" = "1";
        "WEB_CONCURRENCY" = "1";
        "LOG_LEVEL" = "warning";
        "SMTP_HOST" = config.myInfrastructure.smtp.host;
        "SMTP_PORT" = toString config.myInfrastructure.smtp.port;
        "SMTP_FROM_NAME" = "Mealie";
        "SMTP_FROM_EMAIL" = config.myInfrastructure.smtp.fromAddress;
        "SMTP_AUTH_STRATEGY" = "SSL";
        "OIDC_AUTH_ENABLED" = "true";
        "OIDC_PROVIDER_NAME" = "authentik";
        "OIDC_CONFIGURATION_URL" =
          "https://auth.${domain}/application/o/mealie/.well-known/openid-configuration";
        "OIDC_CLIENT_ID" = "e5DDiJkn8eaMjYMNt85W3NaDshnu5s67lXy79ava";
        "OIDC_SIGNUP_ENABLED" = "true";
        "OIDC_ADMIN_GROUP" = "admins";
        "OIDC_USER_CLAIM" = "preferred_username";
        "OIDC_AUTO_REDIRECT" = "true";
        "OIDC_REMEMBER_ME" = "true";
        "OPENAI_BASE_URL" = "http://ollama--server:11434/v1";
        "OPENAI_API_KEY" = "ollama";
        "OPENAI_MODEL" = "gemma4:latest";
      };
      environmentFiles = getEnvFiles "mealie" "app";
      volumes = [
        "/data/services/mealie/app:/app/data"
      ];
      networks = [
        "traefik"
        "ollama-backend"
        backendNetwork
      ];
      labels =
        (mkTraefikLabels {
          name = "mealie";
          port = "9000";
        })
        // {
          "homepage.group" = "Life Management";
          "homepage.name" = "Mealie";
          "homepage.icon" = "mealie";
          "homepage.href" = "https://mealie.${domain}";
          "homepage.description" = "Recipe management & meal planning";
        };
    };

    myVirtualization.containers.mealie.database = {
      rawImageReference = "postgres:19@sha256:4ea94de574c17f0372722806c949757050fbb1cd7648410fe45d6bba275cc00e";
      nixSha256 = "sha256-ZpiK6v+/LXJh7TEdbMNZzGj4FEj9re/sUTISj/eVI4Q=";
      volumes = [ "/data/services/mealie/database:/var/lib/postgresql/18/docker" ];
      networks = [ backendNetwork ];
      environment = {
        "POSTGRES_DB" = "mealie";
        "POSTGRES_USER" = "mealie";
      };
      environmentFiles = getEnvFiles "mealie" "mealie";
      cmd = [
        "postgres"
        "-c"
        "log_checkpoints=off"
      ];
      labels = {
        "traefik.enable" = "false";
      };
    };
  };
}
