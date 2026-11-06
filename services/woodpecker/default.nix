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
      rawImageReference = "woodpeckerci/woodpecker-server:v3.20.1@sha256:0f31560e29d67ec4a06d6eeee4bac38d2a2697a6a741b8a0db3998180f3a3517";
      nixSha256 = "sha256-oZCMX2se+/KKnUM/aPRmWppikS/ijJcqUIf1ta0X+r4=";
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
      rawImageReference = "woodpeckerci/woodpecker-agent:v3.20.0@sha256:2713a2356a9af877d802d6a944529f27e649b4e397977a1e1a7449415e725ff6";
      nixSha256 = "sha256-tqAWCq5RifCCL5GODknJd62x/ogZrMhpRlA6dq3x7Io=";
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
