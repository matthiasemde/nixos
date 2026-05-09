{
  description = "Vaultwarden container flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "vaultwarden";
      containers =
        {
          domain,
          mkTraefikLabels,
          getContainerEnvFiles,
          ...
        }:
        {
          vaultwarden = {
            rawImageReference = "vaultwarden/server:1.36.0@sha256:d626d04934cd1192ad8ced1adb975099fca78cec33ab467d2d3c923cde7f3b0c";
            nixSha256 = "sha256-jRqEghC3Ech4a770UfNPPC52lSqLRyO/Ezvy45xsw0A=";
            environment = {
              # Server hostname
              "DOMAIN" = "https://vaultwarden.${domain}";
              "SIGNUPS_ALLOWED" = "false";
              # "ADMIN_TOKEN" = "xxxxxxxxxxxx" # set via secret management;
              "ORG_CREATION_USERS" = "matthias@emdemail.de";

              ## Mail settings
              "SMTP_HOST" = "mail.privateemail.com";
              "SMTP_FROM" = "no-reply@emdecloud.de";
              "SMTP_FROM_NAME" = "Vaultwarden";
              # "SMTP_USERNAME" = "username"; # set via secret management;
              # "SMTP_PASSWORD" = "password"; # set via secret management;
              "SMTP_TIMEOUT" = "15";
              "SMTP_SECURITY" = "force_tls";
              "SMTP_PORT" = "465";
            };
            environmentFiles = getContainerEnvFiles "vaultwarden";
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

                # 🏠 Homepage integration
                "homepage.group" = "Life Management";
                "homepage.name" = "Vaultwarden";
                "homepage.icon" = "vaultwarden";
                "homepage.href" = "https://vaultwarden.${domain}";
                "homepage.description" = "Password vault";
              };
          };
        };
    };
}
