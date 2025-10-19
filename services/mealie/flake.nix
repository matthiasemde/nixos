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
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          mealieRawImageReference = "ghcr.io/mealie-recipes/mealie:v3.3.2@sha256:84acc67e1e3fc8713df09b24bcdc81e9c8f68f46972708f6b1ebba89f1069128";
          mealieImageReference = parseDockerImageReference mealieRawImageReference;
          mealieImage = pkgs.dockerTools.pullImage {
            imageName = mealieImageReference.name;
            imageDigest = mealieImageReference.digest;
            finalImageTag = mealieImageReference.tag;
            sha256 = "sha256-4TZDeE7moTDYMlWIlYWxrKuJhr9ZCKzGTLTaLaNF2hQ=";
          };

          postgresRawImageReference = "postgres:15@sha256:22d83dee85fd73ffa34e5b19d192184bad1fbc6b960aca3df4d31ac464532dab";
          postgresImageReference = parseDockerImageReference postgresRawImageReference;
          postgresImage = pkgs.dockerTools.pullImage {
            imageName = postgresImageReference.name;
            imageDigest = postgresImageReference.digest;
            finalImageTag = postgresImageReference.tag;
            sha256 = "sha256-oG5Do29b4CSok3H6mSk/xYiHeyJd4XJShwdkgO3A6D0=";
          };
        in
        {
          mealie-app = {
            image = mealieImageReference.name + ":" + mealieImageReference.tag;
            imageFile = mealieImage;
            extraOptions = [ "--dns=1.1.1.1" ];
            environment = {
              # Base URL
              "BASE_URL" = "https://mealie.${domain}";

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
            image = postgresImageReference.name + ":" + postgresImageReference.tag;
            imageFile = postgresImage;
            volumes = [ "/data/services/mealie/database:/var/lib/postgresql/data" ];
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
