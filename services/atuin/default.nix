{
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "atuin-backend";
in
{
  myVirtualization.networks.${backendNetwork} = "";

  # Shell history sync server. Requires ATUIN_DB_URI (postgres connection
  # string, including credentials) to be provided via the "server" secret.
  myVirtualization.containers.atuin.server = {
    rawImageReference = "ghcr.io/atuinsh/atuin:18.23.0@sha256:c6e11541ed25770ecfc51fe05bbb8ef07f85dea6565ddd91422aa95917ef86fa";
    nixSha256 = "sha256-Pg10juDGFsP3n8JwMAho6lAZmD2qIrdpu15Y1dgOI+g=";
    environment = {
      "ATUIN_HOST" = "0.0.0.0";
      "ATUIN_PORT" = "8888";
      "ATUIN_OPEN_REGISTRATION" = "false";
      # "ATUIN_DB_URI" = "postgres://${ATUIN_DB_USERNAME}:${ATUIN_DB_PASSWORD}@db/${ATUIN_DB_NAME}" # provided by secret-mgmt
    };
    environmentFiles = getEnvFiles "atuin" "server";
    networks = [
      "traefik"
      backendNetwork
    ];
    cmd = [
      "start"
    ];
    labels =
      (mkTraefikLabels {
        name = "atuin";
        port = "8888";
      })
      // {
        "homepage.group" = "Utilities";
        "homepage.name" = "Atuin";
        "homepage.icon" = "atuin";
        "homepage.href" = "https://atuin.${domain}";
        "homepage.description" = "Encrypted shell history sync";
      };
  };

  # Postgres database backing the sync server. Requires POSTGRES_PASSWORD to
  # be provided via the "database" secret.
  myVirtualization.containers.atuin.database = {
    rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
    nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
    environment = {
      "POSTGRES_USER" = "atuin";
      "POSTGRES_DB" = "atuin";
      "TZ" = "Europe/Berlin";
      "PGTZ" = "Europe/Berlin";
    };
    environmentFiles = getEnvFiles "atuin" "database";
    volumes = [
      "/data/services/atuin/database:/var/lib/postgresql/18/docker"
    ];
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  # Self-hosted Atuin AI backend, proxying chat-completions to the local
  # Ollama instance (services/ollama). See config/ai-server-config.toml.
  myVirtualization.containers.atuin."ai-server" = {
    rawImageReference = "ghcr.io/atuinsh/atuin-ai-server:latest@sha256:3d11028588ebfddb0685169e35cbc7121d3577b6eee3831e845fbe5c28e48d92";
    nixSha256 = "sha256-Hn2hXWUNn84M5Bwriia528tgd5Dw+QyvPCvUxXsyhTU=";
    environment = {
      # "AUTH_TOKEN" = "my-secure-token" # set via secret-mgmt
    };
    environmentFiles = getEnvFiles "atuin" "ai-server";
    volumes = [
      "${./config/ai-server-config.toml}:/etc/atuin-ai/config.toml:ro"
    ];
    networks = [
      "traefik"
      "ollama-backend"
      backendNetwork
    ];
    labels =
      (mkTraefikLabels {
        name = "atuin-ai";
        port = "8080";
      })
      // {
        "homepage.group" = "AI";
        "homepage.name" = "Atuin AI";
        "homepage.icon" = "atuin";
        "homepage.href" = "https://atuin-ai.${domain}";
        "homepage.description" = "AI backend for Atuin shell history search";
      };
  };
}
