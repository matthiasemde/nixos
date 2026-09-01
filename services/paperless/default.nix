{
  config,
  lib,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "paperless-backend";
in
{
  options.paperless.oidcClientId = lib.mkOption {
    type = lib.types.str;
    description = "Paperless-ngx OIDC client ID registered in Authentik.";
  };

  config = {
    myVirtualization.networks.${backendNetwork} = "";

    myVirtualization.containers.paperless.app = {
      rawImageReference = "ghcr.io/paperless-ngx/paperless-ngx:3.1.2@sha256:5ab4f4f9bb099a36bec3e092906ea3e611323c5f18dc5cc38c76a1d540bdca9c";
      nixSha256 = "sha256-c8MWCXjunx5v6P9s/zm1tIIXX62apR2PI7dqdvcOX7k=";
      environment = {
        "PAPERLESS_URL" = "https://paperless.${domain}";
        "PAPERLESS_ACCOUNT_ALLOW_SIGNUPS" = "false";
        "PAPERLESS_REDIS" = "redis://paperless--redis:6379";
        "PAPERLESS_EMAIL_HOST" = config.myInfrastructure.smtp.host;
        "PAPERLESS_EMAIL_PORT" = toString config.myInfrastructure.smtp.port;
        "PAPERLESS_EMAIL_HOST_USER" = config.myInfrastructure.smtp.fromAddress;
        "PAPERLESS_EMAIL_USE_SSL" = "true";
        "PAPERLESS_CONSUMER_RECURSIVE" = "true";
        "PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS" = "true";
        "PAPERLESS_ENABLE_ALLAUTH" = "true";
        "PAPERLESS_APPS" = "allauth.socialaccount.providers.openid_connect";
        "PAPERLESS_SOCIALACCOUNT_PROVIDERS" = ''
          {
            "openid_connect": {
              "APPS": [
                {
                  "provider_id": "authentik",
                  "name": "authentik",
                  "client_id": "${config.paperless.oidcClientId}",
                  "settings": {
                    "server_url": "https://auth.${domain}/application/o/paperless/.well-known/openid-configuration",
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
        "PAPERLESS_LOGOUT_REDIRECT_URL" = "https://auth.${domain}/application/o/paperless/end-session/";
        "PAPERLESS_DISABLE_REGULAR_LOGIN" = "true";
        "PAPERLESS_REDIRECT_LOGIN_TO_SSO" = "true";
      };
      environmentFiles = getEnvFiles "paperless" "app";
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
          "homepage.group" = "Life Management";
          "homepage.name" = "Paperless";
          "homepage.icon" = "paperless";
          "homepage.href" = "https://paperless.${domain}";
          "homepage.description" = "Digitize documents";
        };
    };

    myVirtualization.containers.paperless.redis = {
      rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
      nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
      networks = [ backendNetwork ];
      cmd = [
        "--save"
        ""
        "--loglevel"
        "warning"
      ];
      labels = {
        "traefik.enable" = "false";
      };
    };
  };
}
