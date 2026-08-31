{
  config,
  lib,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  backendNetwork = "woodpecker-backend";
in
{
  options.woodpecker.adminUser = lib.mkOption {
    type = lib.types.str;
    description = "Woodpecker CI admin username.";
  };

  config = {
    myVirtualization.networks.${backendNetwork} = "";

    myVirtualization.containers.woodpecker.server = {
      rawImageReference = "woodpeckerci/woodpecker-server:v3.18.0@sha256:5192aee400df23671de8ddffb906670e93d07ae8967c7f9e50efefca3a2deea5";
      nixSha256 = "sha256-8XK/7HNA7ToxelliBvirSTq4iT3+nGhpZbB65tBQMhQ=";
      environment = {
        "WOODPECKER_HOST" = "https://ci.${domain}";
        "WOODPECKER_OPEN" = "false";
        "WOODPECKER_ADMIN" = config.woodpecker.adminUser;
        "WOODPECKER_GITHUB" = "true";
        "WOODPECKER_LOG_LEVEL" = "warn";
        "WOODPECKER_DATABASE_DRIVER" = "sqlite3";
        "WOODPECKER_DATABASE_DATASOURCE" = "/var/lib/woodpecker/woodpecker.sqlite";
      };
      environmentFiles = getEnvFiles "woodpecker" "server";
      volumes = [
        "/data/services/woodpecker/server:/var/lib/woodpecker"
      ];
      networks = [
        "traefik"
        backendNetwork
      ];
      labels =
        (mkTraefikLabels {
          name = "woodpecker";
          specialSubdomain = "ci";
          port = "8000";
        })
        // {
          "homepage.group" = "Utilities";
          "homepage.name" = "Woodpecker CI";
          "homepage.icon" = "woodpecker-ci";
          "homepage.href" = "https://ci.${domain}";
          "homepage.description" = "CI/CD Pipeline";
        };
    };

    myVirtualization.containers.woodpecker.agent = {
      rawImageReference = "woodpeckerci/woodpecker-agent:v3.18.0@sha256:b10103626eb87a9421e5d00eba7608c3af045f13f7dd760d0420ce9a03d15905";
      nixSha256 = "sha256-Bvhnb4JH89Xg9HLv7WcXjKudaxFndWHd18moHG1BZS4=";
      environment = {
        "WOODPECKER_SERVER" = "woodpecker--server:9000";
        "WOODPECKER_BACKEND" = "docker";
        "WOODPECKER_MAX_WORKFLOWS" = "2";
        "WOODPECKER_LOG_LEVEL" = "warn";
      };
      environmentFiles = getEnvFiles "woodpecker" "agent";
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
      ];
      networks = [ backendNetwork ];
      labels = {
        "traefik.enable" = "false";
      };
    };
  };
}
