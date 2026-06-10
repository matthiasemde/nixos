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

  myVirtualization.containers.ollama = {
    rawImageReference = "ollama/ollama:0.30.2@sha256:99262b6b2898e1d40907883e316f31e350e0ee6316ccae6127ac5a9feeacade2";
    nixSha256 = "sha256-COALBRd1m7MvVkjye/fBg06HWJGYAUoIgmClZV7mVvE=";
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

  myVirtualization.containers.open-webui = {
    rawImageReference = "openwebui/open-webui:0.9.5@sha256:e045bde3b004cc7f8c319412345eb56c87ea6ac57031534a31ca37ad5424beb3";
    nixSha256 = "sha256-DUwBhf6GCINUmgpt1LolYVsdSad5zbafYHXuYYDOIqw=";
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
