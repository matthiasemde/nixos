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
      rawImageReference = "woodpeckerci/woodpecker-agent:v3.20.1@sha256:a7d7299a13add0b3936fa0ac9ed23507fe283a7fc7d9596c4289d7e8206541eb";
      nixSha256 = "sha256-DqS64idr1u+aJb7UYvmBklYQnUKuJjjVIRwVboLv6So=";
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
