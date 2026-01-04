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
            rawImageReference = "vaultwarden/server:1.35.1@sha256:1d43c6754a030861f960fd4dab47e1b33fc19f05bd5f8f597ab7236465a6f14b";
            nixSha256 = "sha256-0bc1s1luQPFiwYH3THVFg91zJD6V8Ew/x+ciUSBZFzQ=";
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
