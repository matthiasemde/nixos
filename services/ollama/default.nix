{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  hostname = config.networking.hostName;
  backendNetwork = "ollama-backend";
in
{
  myVirtualization.networks.${backendNetwork} = "";

  # myVirtualization.containers.ollama.server = {
  #   rawImageReference = "ollama/ollama:0.40.16@sha256:910d0d8107b538fb0894e63163eb195de0cc7aefcbc666dc62d3b18f71124592";
  #   nixSha256 = "sha256-7hBm6LvzyNG0jH21KlG/vMd1fwXzsewW5DfNugysj3M=";
  #   networks = [
  #     "traefik"
  #     backendNetwork
  #   ];
  #   environment = {
  #     "OLLAMA_CONTEXT_LENGTH" = "8192";
  #   };
  #   volumes = [
  #     "/data/services/ollama/data:/root/.ollama"
  #   ];
  #   labels =
  #     mkTraefikLabels {
  #       name = "ollama";
  #       port = "11434";
  #       isPublic = false;
  #     }
  #     // {
  #       "homepage.group" = "AI";
  #       "homepage.name" = "Ollama";
  #       "homepage.icon" = "ollama";
  #       "homepage.href" = "http://ollama.${hostname}.local";
  #       "homepage.description" = "Lokal LLM hosting and management platform.";
  #     };
  # };

  myVirtualization.containers.ollama.open-webui = {
    rawImageReference = "openwebui/open-webui:0.13.4@sha256:d5168bfbc28609eff5bea1b438dd864cf64d185cf6582c02244865e18385b901";
    nixSha256 = "sha256-ahZMNn9zhR31L8ycZzf+B35MA0/oWjMvY7wWcRydvNA=";
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
      "OPENID_PROVIDER_URL" =
        "https://auth.${domain}/application/o/open-web-ui/.well-known/openid-configuration";
      "OPENID_PROVIDER_NAME" = "Authentik";
      "OPENID_REDIRECT_URI" = "https://open-webui.${domain}/oauth/oidc/callback";
      "OAUTH_ALLOWED_ROLES" = "open-webui-users";
      "OAUTH_ADMIN_ROLES" = "admins";
    };
    environmentFiles = getEnvFiles "ollama" "open-webui";
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
}
