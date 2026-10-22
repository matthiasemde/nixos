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
  #   rawImageReference = "ollama/ollama:0.40.7@sha256:2e6cc92ffa43b4b1a2e70e315407e00ac97ec125afc71277d73c7efe01c4f31b";
  #   nixSha256 = "sha256-IGmzgYmAmfChGyJtjO2Lq4GGqjEMDCDA44w9jhcK9rI=";
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
    rawImageReference = "openwebui/open-webui:0.12.2@sha256:10e6a78ba2d172493460a9e8a92c496aaa7a64dc4d26d622a2e95e0c736081c9";
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
