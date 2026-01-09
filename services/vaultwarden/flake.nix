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
          getServiceEnvFiles,
          ...
        }:
        {
          vaultwarden = {
            rawImageReference = "vaultwarden/server:1.35.2@sha256:d89a6d21e361254670c24a4272b4b5f245e402c284f2f55de2c379fdbcfa1fa5";
            nixSha256 = "sha256-1VcmWZPf0zlUnxwHraGJb8SfKkl+CI5sJXTgj1/uRoo=";
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
            environmentFiles = getServiceEnvFiles "vaultwarden";
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
