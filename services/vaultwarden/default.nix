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
  myVirtualization.containers.vaultwarden = {
    rawImageReference = "vaultwarden/server:1.36.0@sha256:d626d04934cd1192ad8ced1adb975099fca78cec33ab467d2d3c923cde7f3b0c";
    nixSha256 = "sha256-jRqEghC3Ech4a770UfNPPC52lSqLRyO/Ezvy45xsw0A=";
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
