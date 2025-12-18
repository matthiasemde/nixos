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
            rawImageReference = "vaultwarden/server:1.34.3@sha256:84fd8a47f58d79a1ad824c27be0a9492750c0fa5216b35c749863093bfa3c3d7";
            nixSha256 = "sha256-vaSs3Ry6TXIYdjmxa5SGxbas8YZJJe87d35456/Dh2A=";
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
