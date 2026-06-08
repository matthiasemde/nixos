{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "outline-backend";
in
{
  myVirtualization.networks.${backendNetwork} = "";

  myVirtualization.containers.outline-app = {
    rawImageReference = "outlinewiki/outline:1.8.0@sha256:bbaac3434e972b860aa2aeea87a465f277dfdcb23ffdcf4ee65f3fb2ca988745";
    nixSha256 = "sha256-nwWimhD5wEgYeZDhx2dWsj28iAPaFDYT/nwkeZFWgS4=";
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
      PGSSLMODE = "disable";
      REDIS_URL = "redis://outline-redis:6379";
      OIDC_AUTH_URI = "https://auth.${domain}/application/o/authorize/";
      OIDC_TOKEN_URI = "https://auth.${domain}/application/o/token/";
      OIDC_USERINFO_URI = "https://auth.${domain}/application/o/userinfo/";
      OIDC_LOGOUT_URI = "https://auth.${domain}/application/o/outline/end-session/";
      OIDC_USERNAME_CLAIM = "preferred_username";
      OIDC_DISPLAY_NAME = "authentik";
      OIDC_SCOPES = "openid profile email";
      SMTP_HOST = config.myInfrastructure.smtp.host;
      SMTP_PORT = toString config.myInfrastructure.smtp.port;
      SMTP_FROM_EMAIL = config.myInfrastructure.smtp.fromAddress;
      SMTP_NAME = "Outline";
      ENABLE_UPDATES = "false";
      LOG_LEVEL = "warn";
    };
    environmentFiles = getEnvFiles "outline" "app";
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

  myVirtualization.containers.outline-database = {
    rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
    nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
    volumes = [ "/data/services/outline/database:/var/lib/postgresql/18/docker" ];
    networks = [ backendNetwork ];
    environment = {
      POSTGRES_DB = "outline";
      POSTGRES_USER = "outline";
    };
    environmentFiles = getEnvFiles "outline" "database";
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.outline-redis = {
    rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
    nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };
}
