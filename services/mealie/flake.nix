{
  description = "Mealie container flake";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "mealie-backend";
    in
    {
      name = "mealie";
      dependencies = {
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
          mealie-app = {
            rawImageReference = "ghcr.io/mealie-recipes/mealie:v3.9.2@sha256:00dc74d7166a26524dd31a2d3e035df714b6c36cbc7be12181f6d31ff480de13";
            nixSha256 = "sha256-NUEdecB1s0cgFj4tXADfmZETPPNYWpcVrqgTSa2PMRo=";
            environment = {
              # Base URL
              "BASE_URL" = "https://mealie.${domain}";
              "DEFAULT_GROUP" = "Default";
              "DEFAULT_HOUSEHOLD" = "Default";
              # User/Group Settings
              "PUID" = "1000";
              "PGID" = "1000";
              "TZ" = "Europe/Berlin";

              # Database configuration
              "DB_ENGINE" = "postgres";
              "POSTGRES_USER" = "mealie";
              # "POSTGRES_PASSWORD" = "mealie"; # set via secret management;
              "POSTGRES_SERVER" = "mealie-database";
              "POSTGRES_PORT" = "5432";
              "POSTGRES_DB" = "mealie";

              # Security
              "ALLOW_SIGNUP" = "false";
              "ALLOW_PASSWORD_LOGIN" = "false";
              "AUTO_BACKUP_ENABLED" = "true";
              "MAX_WORKERS" = "1";
              "WEB_CONCURRENCY" = "1";

              # General Settings
              "LOG_LEVEL" = "warning";

              # SMTP Configuration
              "SMTP_HOST" = "mail.privateemail.com";
              "SMTP_PORT" = "465";
              "SMTP_FROM_NAME" = "Mealie";
              "SMTP_FROM_EMAIL" = "no-reply@emdecloud.de";
              "SMTP_AUTH_STRATEGY" = "SSL";
              # "SMTP_USER" = "username"; # set via secret management;
              # "SMTP_PASSWORD" = "password"; # set via secret management;

              # OIDC Configuration for Authentik
              "OIDC_AUTH_ENABLED" = "true";
              "OIDC_PROVIDER_NAME" = "authentik";
              "OIDC_CONFIGURATION_URL" =
                "https://auth.${domain}/application/o/mealie/.well-known/openid-configuration";
              "OIDC_CLIENT_ID" = "e5DDiJkn8eaMjYMNt85W3NaDshnu5s67lXy79ava";
              # "OIDC_CLIENT_SECRET" = "client-secret"; # set via secret management;
              "OIDC_SIGNUP_ENABLED" = "true";
              "OIDC_ADMIN_GROUP" = "admins";
              "OIDC_USER_CLAIM" = "preferred_username";
              "OIDC_AUTO_REDIRECT" = "true";
              "OIDC_REMEMBER_ME" = "true";
            };
            environmentFiles = getServiceEnvFiles "mealie";
            volumes = [
              "/data/services/mealie/app:/app/data"
            ];
            networks = [
              "traefik"
              backendNetwork
            ];
            labels =
              (mkTraefikLabels {
                name = "mealie";
                port = "9000";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Life Management";
                "homepage.name" = "Mealie";
                "homepage.icon" = "mealie";
                "homepage.href" = "https://mealie.${domain}";
                "homepage.description" = "Recipe management & meal planning";
              };
          };

          mealie-database = {
            rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
            nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
            volumes = [ "/data/services/mealie/database:/var/lib/postgresql/18/docker" ];
            networks = [ backendNetwork ];
            environment = {
              "POSTGRES_DB" = "mealie";
              "POSTGRES_USER" = "mealie";
              # "POSTGRES_PASSWORD" = "secure-password"; # set via secret management;
            };
            environmentFiles = getServiceEnvFiles "mealie";
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
