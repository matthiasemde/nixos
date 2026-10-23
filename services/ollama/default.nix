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
  #   rawImageReference = "ollama/ollama:0.40.8@sha256:2b8eecdb85aa6ea67c381c8ecffec04b2658496cf2821a8f88b0485bdff198e8";
  #   nixSha256 = "sha256-CqhZckn1KvMd9r1lIU6ENY+p54QAkrkIozDUSgIiuNQ=";
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
    rawImageReference = "openwebui/open-webui:0.12.3@sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def";
    nixSha256 = "sha256-86qYPvRJbXiACaMhgjcKfUhvyO+qSFF5JsvG3aZ9oJU=";
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
