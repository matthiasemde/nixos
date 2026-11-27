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

  myVirtualization.containers.outline.app = {
    rawImageReference = "outlinewiki/outline:1.13.0@sha256:4583bb244dbb4464d8a632c75044d3b2f9fe44382b6a4b84d97995f473b823e4";
    nixSha256 = "sha256-2Blh+TcUAPDivAappEPli05EUbxiX223WVGlfJWRGW0=";
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
      REDIS_URL = "redis://outline--redis:6379";
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

  myVirtualization.containers.outline.database = {
    rawImageReference = "postgres:19@sha256:4ea94de574c17f0372722806c949757050fbb1cd7648410fe45d6bba275cc00e";
    nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
    volumes = [ "/data/services/outline/database:/var/lib/postgresql/18/docker" ];
    networks = [ backendNetwork ];
    environment = {
      POSTGRES_DB = "outline";
      POSTGRES_USER = "outline";
    };
    environmentFiles = getEnvFiles "outline" "database";
    cmd = [
      "postgres"
      "-c"
      "log_checkpoints=off"
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.outline.redis = {
    rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
    nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
    networks = [ backendNetwork ];
    cmd = [
      "redis-server"
      "--loglevel"
      "warning"
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };
}
