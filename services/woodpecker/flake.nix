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
            rawImageReference = "woodpeckerci/woodpecker-server:v3.13.0@sha256:428eb0965754e25e67b8b086648438858b4fa64487b1cd3cc8e4101b396e459a";
            nixSha256 = "sha256-bO1jqvRwn8os7MgSU8V/eKGi/6oQt1Tb8KIfn8t+NZ0=";
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
                "homepage.group" = "Development";
                "homepage.name" = "Woodpecker CI";
                "homepage.icon" = "woodpecker-ci";
                "homepage.href" = "https://ci.${domain}";
                "homepage.description" = "CI/CD Pipeline";
              };
          };

          woodpecker-agent = {
            rawImageReference = "woodpeckerci/woodpecker-agent:v3.13.0@sha256:a983b1016217ad94cdab48d732ec97b5b1f72718725d651183d7ec885f7caf35";
            nixSha256 = "sha256-UA0RgSOBkmDf3+C4raevKvMILTk57m1oAkaKo2Rttiw=";
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
