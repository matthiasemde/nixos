{
  description = "Woodpecker CI service";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "woodpecker-backend";
    in
    {
      name = "woodpecker";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
        };
      };
      containers =
        {
          domain,
          hostname,
          mkTraefikLabels,
          getServiceEnvFiles,
          ...
        }:
        {
          woodpecker-server = {
            rawImageReference = "woodpeckerci/woodpecker-server:v3.14.1@sha256:a45d030a33b06eb77467df8c202f1bbbc0d0f972560b9872c08f11fbe60ffb5f";
            nixSha256 = "sha256-XtoFmuJ7vwAOT/KAKyKJKXdn2dqBdO93akXC6UKdmr0=";
            environment = {
              "WOODPECKER_HOST" = "https://ci.${domain}";
              "WOODPECKER_OPEN" = "false";
              "WOODPECKER_ADMIN" = "matthiasemde";
              "WOODPECKER_GITHUB" = "true";
              "WOODPECKER_LOG_LEVEL" = "info";
              "WOODPECKER_DATABASE_DRIVER" = "sqlite3";
              "WOODPECKER_DATABASE_DATASOURCE" = "/var/lib/woodpecker/woodpecker.sqlite";
            };
            environmentFiles = getServiceEnvFiles "woodpecker";
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

          woodpecker-agent = {
            rawImageReference = "woodpeckerci/woodpecker-agent:v3.14.0@sha256:f9d97011a988a6b7b09f5333147cdea051e488f3391ba862d0b26f07bc9d879a";
            nixSha256 = "sha256-IY789dcMFKL3M+fmpmpwTQjLqmAsWogZOotdvtRz6vQ=";
            environment = {
              "WOODPECKER_SERVER" = "woodpecker-server:9000";
              "WOODPECKER_BACKEND" = "docker";
              "WOODPECKER_MAX_WORKFLOWS" = "2";
              "WOODPECKER_LOG_LEVEL" = "info";
            };
            environmentFiles = getServiceEnvFiles "woodpecker";
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };
        };
    };
}
