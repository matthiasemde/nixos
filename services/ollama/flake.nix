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
            rawImageReference = "ollama/ollama:0.23.2@sha256:d00473cb58f0082c07cd6ed0d326a8a86f443ab69c51f8fc2b1a41687d45c661";
            nixSha256 = "sha256-AnKIEcxdd0EPUW8lC3+w84iIizM0UYXDMAA4+m0apik=";
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
            rawImageReference = "openwebui/open-webui:0.9.4@sha256:172e1fe0e89af2a07f42f2b1d943f30c8ddd7b9c2e182f3678b4790cdb83abea";
            nixSha256 = "sha256-fRVV89D+3A65JgtAn59//CDRgcGToLXqlQerEB/fhj4=";
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
