{
  description = "Service flake for Outline";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "outline-backend";
    in
    {
      name = "outline";
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
          outline-app = {
            rawImageReference = "outlinewiki/outline:1.5.0@sha256:f053574bb63b82846ec3cd7d89ab4b3019073b4dd25fda45f5cdcccc990a7401";
            nixSha256 = "sha256-xS7w8Kjb3VSxob5hSPF58Tf6BC2NIrSEOaVp1q4v/7A=";
            networks = [
              backendNetwork
              "traefik"
            ];
            volumes = [
              "/data/services/outline/app:/var/lib/outline/data"
            ];
            environment = {
              NODE_ENV = "production";
              URL = "https://outline.${domain}";
              PORT = "3000";
              FORCE_HTTPS = "false";

              # SECRET_KEY=`openssl rand -hex 32` # set via secret management;
              # UTILS_SECRET= `openssl rand -hex 32` # set via secret management;

              # The database URL for your production database, including username, password, and database name.
              # DATABASE_URL = "postgres://user:pass@postgres:5432/outline" # set via secret management;
              PGSSLMODE = "disable";

              # Redis
              REDIS_URL = "redis://outline-redis:6379";

              # OIDC config
              # OIDC_CLIENT_ID = ""; # set via secret management;
              # OIDC_CLIENT_SECRET = ""; # set via secret management;
              OIDC_AUTH_URI = "https://auth.${domain}/application/o/authorize/";
              OIDC_TOKEN_URI = "https://auth.${domain}/application/o/token/";
              OIDC_USERINFO_URI = "https://auth.${domain}/application/o/userinfo/";
              OIDC_LOGOUT_URI = "https://auth.${domain}/application/o/outline/end-session/";
              OIDC_USERNAME_CLAIM = "preferred_username";
              OIDC_DISPLAY_NAME = "authentik";
              OIDC_SCOPES = "openid profile email";

              # SMTP Config
              SMTP_HOST = "mail.privateemail.com";
              SMTP_PORT = "465";
              # SMTP_USERNAME = "username"; # set via secret management;
              # SMTP_PASSWORD = "password"; # set via secret management;
              SMTP_FROM_EMAIL = "no-reply@emdecloud.de";
              SMTP_NAME = "Outline";

              # Debugging
              ENABLE_UPDATES = "false";
              LOG_LEVEL = "warn";
            };
            environmentFiles = getServiceEnvFiles "outline";
            labels =
              mkTraefikLabels {
                name = "outline";
                port = "3000";
              }
              // {
                "homepage.group" = "Life Management";
                "homepage.name" = "Outline";
                "homepage.icon" = "outline";
                "homepage.href" = "https://outline.${domain}";
                "homepage.description" = "Personal Wiki";
              };
          };

          outline-database = {
            rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
            nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
            volumes = [ "/data/services/outline/database:/var/lib/postgresql/18/docker" ];
            networks = [ backendNetwork ];
            environment = {
              POSTGRES_DB = "outline";
              POSTGRES_USER = "outline";
              # POSTGRES_PASSWORD = "secure-password" # set via secret management;
            };
            environmentFiles = getServiceEnvFiles "outline";
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };

          outline-redis = {
            rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
            nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
