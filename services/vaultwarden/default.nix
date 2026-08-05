{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
in
{
  myVirtualization.containers.vaultwarden.app = {
    rawImageReference = "vaultwarden/server:1.37.1@sha256:ebdfe70701c60ac0c28c697e787cea767d7972940b786037b29fe0d507f821e8";
    nixSha256 = "sha256-RWrMlyKUmjQ3mWmoLLOaYvHlnMr9ZpAi/JYPoepABEA=";
    environment = {
      "DOMAIN" = "https://vaultwarden.${domain}";
      "SIGNUPS_ALLOWED" = "false";
      "ORG_CREATION_USERS" = config.myInfrastructure.adminEmail;
      "SMTP_HOST" = config.myInfrastructure.smtp.host;
      "SMTP_FROM" = config.myInfrastructure.smtp.fromAddress;
      "SMTP_FROM_NAME" = "Vaultwarden";
      "SMTP_TIMEOUT" = "15";
      "SMTP_SECURITY" = "force_tls";
      "SMTP_PORT" = toString config.myInfrastructure.smtp.port;
    };
    environmentFiles = getEnvFiles "vaultwarden" "app";
    volumes = [
      "/data/services/vaultwarden/app:/data"
    ];
    networks = [ "traefik" ];
    labels =
      (mkTraefikLabels {
        name = "vaultwarden";
        port = "80";
      })
      // {
        "traefik.http.routers.vaultwarden-public.middlewares" = "block-admin";
        "traefik.http.middlewares.block-admin.redirectregex.regex" = "^(https?://[^/]+)/admin.*";
        "traefik.http.middlewares.block-admin.redirectregex.replacement" = "$\{1\}/";
        "traefik.http.middlewares.block-admin.redirectregex.permanent" = "true";

        "homepage.group" = "Life Management";
        "homepage.name" = "Vaultwarden";
        "homepage.icon" = "vaultwarden";
        "homepage.href" = "https://vaultwarden.${domain}";
        "homepage.description" = "Password vault";
      };
  };
}
