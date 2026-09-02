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

  myVirtualization.containers.ollama.server = {
    rawImageReference = "ollama/ollama:0.33.0@sha256:08ddf4b4dbfdc4fc1f5b0fe535915998581085402e307b57bb308db68460e372";
    nixSha256 = "sha256-IvFJVUKBpoTudiXg4R6zSUdqchW0ij4MDaIg/UeI/xE=";
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

  myVirtualization.containers.ollama.open-webui = {
    rawImageReference = "openwebui/open-webui:0.11.0@sha256:72c0ba641ba75e7aa52655cb242570906ececd09b1140fb736483038a22b3228";
    nixSha256 = "sha256-7cj05vrQlkH8TMmrGnu/xcGFYowssUxZMmTZsGLw6bY=";
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
