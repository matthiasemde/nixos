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
            rawImageReference = "woodpeckerci/woodpecker-server:v3.12.0@sha256:54a6bb827066f2cdebe5665c5b921b585369b6d8006f350d63ac2b9ed1ce86c6";
            nixSha256 = "sha256-y6iv9fSpf024xCvWQOUgiqDc/l3YB6h9Oa7Im1Nujj8=";
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
            rawImageReference = "woodpeckerci/woodpecker-agent:v3.12.0@sha256:098ac6cdd4644d9ffce50d9a19c864c1c91eb3c4a07f0924af113d702e3adbe9";
            nixSha256 = "sha256-op/uQN6a7sNDZMBeZKHX3bmmYifpJuIpKpaHSP9EVjI=";
            environment = {
              "WOODPECKER_SERVER" = "woodpecker-server:9000";
              "WOODPECKER_BACKEND" = "docker";
              "WOODPECKER_MAX_WORKFLOWS" = "2";
              "WOODPECKER_LOG_LEVEL" = "info";
            };
            environmentFiles = getServiceEnvFiles "woodpecker";
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/nix:/nix:ro"
              "/home/matthias/infra:/home/matthias/infra"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };
        };
    };
}
