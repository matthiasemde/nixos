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
    rawImageReference = "ghcr.io/atuinsh/atuin:18.25.1@sha256:4f9e1047ce62fd44372a6c4ef83f0d9426579127d7e6633d8d2cf56576b4d656";
    nixSha256 = "sha256-zFbFCQb1TR6vsbh6SABg+Cc5hLxTgvNgv8rLEVYo+j0=";
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
    rawImageReference = "postgres:19@sha256:4ea94de574c17f0372722806c949757050fbb1cd7648410fe45d6bba275cc00e";
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
