{
  description = "Service flake for Ollama";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "ollama-backend";
    in
    {
      name = "ollama";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        {
          domain,
          hostname,
          mkTraefikLabels,
          getServiceEnvFiles,
          ...
        }:
        {
          ollama = {
            rawImageReference = "ollama/ollama:0.22.1@sha256:3ca37ec2b9cb6341b62554074205c616778fe98abcf9e4fc50361b79a07407ae";
            nixSha256 = "sha256-mnPSMbciKtejO8WxHOLBKyPRemP4JUlPLKMB9uBnO/g=";
            networks = [
              "traefik"
              backendNetwork
            ];
            volumes = [
              "/data/services/ollama/data:/root/.ollama"
            ];
            labels =
              mkTraefikLabels {
                name = "ollama";
                port = "11434";
                isPublic = false;
              }
              // {
                "homepage.group" = "AI";
                "homepage.name" = "Ollama";
                "homepage.icon" = "ollama";
                "homepage.href" = "http://ollama.${hostname}.local";
                "homepage.description" = "Lokal LLM hosting and management platform.";
              };
          };

          open-webui = {
            rawImageReference = "openwebui/open-webui:0.9.2@sha256:a7e4796ae894d1e2a0c1824860ade472f35c507608a01c3581377b5c19b0ed49";
            nixSha256 = "sha256-r7i5l5XEm5Y2FdpkHmDXgoxkk4FFVVZZ2X+Me7n0pX4=";
            networks = [
              "traefik"
              backendNetwork
            ];
            environment = {
              "WEBUI_URL" = "https://open-webui.${domain}";
              "OAUTH_MERGE_ACCOUNTS_BY_EMAIL" = "true";
              "ENABLE_OAUTH_SIGNUP" = "true";
              "DEFAULT_USER_ROLE" = "user";
              "ENABLE_LOGIN_FORM" = "false";
              "ENABLE_PASSWORD_AUTH" = "false";
              "OPENID_PROVIDER_URL" = "https://auth.${domain}/application/o/open-web-ui/.well-known/openid-configuration";
              "OPENID_PROVIDER_NAME" = "Authentik";
              "OPENID_REDIRECT_URI" = "https://open-webui.${domain}/oauth/oidc/callback";
              "OAUTH_ALLOWED_ROLES" = "open-webui-users";
              "OAUTH_ADMIN_ROLES" = "admins";
            };
            environmentFiles = getServiceEnvFiles "ollama";
            volumes = [
              "/data/services/open-webui/data:/app/backend/data"
            ];
            labels =
              mkTraefikLabels {
                name = "open-webui";
                port = "8080";
              }
              // {
                "homepage.group" = "AI";
                "homepage.name" = "Open WebUI";
                "homepage.icon" = "open-webui";
                "homepage.href" = "https://open-webui.${domain}";
                "homepage.description" = "Web-based interface for managing and interacting with local LLMs.";
              };
          };
        };
    };
}
