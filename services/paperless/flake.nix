{
  description = "Paperless-NGX container flake";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "paperless-backend";
    in
    {
      name = "paperless";
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
          paperless-app = {
            rawImageReference = "ghcr.io/paperless-ngx/paperless-ngx:2.20.7@sha256:7b937cb2fa2885ab0ecfceb8c7e8827e2312472d9d897a270097ba7f5522dcdc";
            nixSha256 = "sha256-Br9ny9xy9DS7NzNLScvu5apDG1IvQObbxSS+o3SQ4Gk=";
            environment = {
              "PAPERLESS_URL" = "https://paperless.${domain}";
              "PAPERLESS_ACCOUNT_ALLOW_SIGNUPS" = "false";
              "PAPERLESS_REDIS" = "redis://paperless-redis:6379";

              # SMTP
              "PAPERLESS_EMAIL_HOST" = "mail.privateemail.com";
              "PAPERLESS_EMAIL_PORT" = "465";
              "PAPERLESS_EMAIL_HOST_USER" = "no-reply@emdecloud.de";
              # "PAPERLESS_EMAIL_HOST_PASSWORD" = "password"; # set via secret management;
              "PAPERLESS_EMAIL_USE_SSL" = "true";

              # Configuration
              "PAPERLESS_CONSUMER_RECURSIVE" = "true";
              "PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS" = "true";

              # SSO Configuration
              "PAPERLESS_ENABLE_ALLAUTH" = "true";
              "PAPERLESS_APPS" = "allauth.socialaccount.providers.openid_connect";
              "PAPERLESS_SOCIALACCOUNT_PROVIDERS" = ''
                {
                  "openid_connect": {
                    "APPS": [
                      {
                        "provider_id": "authentik",
                        "name": "authentik",
                        "client_id": "MbfRgCUPQJ5HUybc2X8mB52cYFvyCVNt2hXgHOCV",
                        "settings": {
                          "server_url": "https://auth.emdecloud.de/application/o/paperless/.well-known/openid-configuration",
                          "claims": {"username": "email"}
                        }
                      }
                    ],
                    "OAUTH_PKCE_ENABLED": "True"
                  }
                }
              '';
              "PAPERLESS_AUTO_LOGIN" = "true";
              "PAPERLESS_AUTO_CREATE" = "true";
              "PAPERLESS_LOGOUT_REDIRECT_URL" = "https://auth.emdecloud.de/application/o/paperless/end-session/";
              "PAPERLESS_DISABLE_REGULAR_LOGIN" = "true";
              "PAPERLESS_REDIRECT_LOGIN_TO_SSO" = "true";
            };
            environmentFiles = getServiceEnvFiles "paperless";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/data/services/paperless/app/data:/usr/src/paperless/data"
              "/data/services/paperless/app/media:/usr/src/paperless/media"
              "/data/services/paperless/app/export:/usr/src/paperless/export"
              "/data/nas/paperless-consumer:/usr/src/paperless/consume"
            ];
            networks = [
              "traefik"
              backendNetwork
            ];
            labels =
              (mkTraefikLabels {
                name = "paperless";
                port = "8000";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Life Management";
                "homepage.name" = "Paperless";
                "homepage.icon" = "paperless";
                "homepage.href" = "https://paperless.${domain}";
                "homepage.description" = "Digitize documents";
              };
          };

          paperless-redis = {
            rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
            nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
            volumes = [
              "/data/services/paperless/redis:/data"
            ];
            networks = [ backendNetwork ];
            labels = {
              # 🛡️ Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
