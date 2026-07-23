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
    rawImageReference = "ollama/ollama:0.32.1@sha256:6345fbc18bd73a1e16404be681dbc6fd291a027cab43ed541abe78c4c81051b0";
    nixSha256 = "sha256-E7mhlE3UWGdU4m8QmlQs95IOXHY2LWXxDHX2xpJ9jLA=";
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
    rawImageReference = "openwebui/open-webui:0.10.2@sha256:9fcea9c6e32ab60b0498f3986c6cdf651ddbe61db48d2213a3d28048ddd673d4";
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
