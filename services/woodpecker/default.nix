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

    myVirtualization.containers.woodpecker-server = {
      rawImageReference = "woodpeckerci/woodpecker-server:v3.14.1@sha256:a45d030a33b06eb77467df8c202f1bbbc0d0f972560b9872c08f11fbe60ffb5f";
      nixSha256 = "sha256-XtoFmuJ7vwAOT/KAKyKJKXdn2dqBdO93akXC6UKdmr0=";
      environment = {
        "WOODPECKER_HOST" = "https://ci.${domain}";
        "WOODPECKER_OPEN" = "false";
        "WOODPECKER_ADMIN" = config.woodpecker.adminUser;
        "WOODPECKER_GITHUB" = "true";
        "WOODPECKER_LOG_LEVEL" = "info";
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

    myVirtualization.containers.woodpecker-agent = {
      rawImageReference = "woodpeckerci/woodpecker-agent:v3.15.0@sha256:aecf04600c2f19c7ea79202177fadda8b8331d105ed981f0a8fd4725cf1df9e7";
      nixSha256 = "sha256-EGouRHruzBZD95uCJRiGTQoR8Jowq/y1KkM56GVjUwg=";
      environment = {
        "WOODPECKER_SERVER" = "woodpecker-server:9000";
        "WOODPECKER_BACKEND" = "docker";
        "WOODPECKER_MAX_WORKFLOWS" = "2";
        "WOODPECKER_LOG_LEVEL" = "info";
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
