{
  description = "Uptime Kuma service flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "uptime-kuma";
      containers =
        {
          hostname,
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          uptime-kuma = {
            rawImageReference = "louislam/uptime-kuma:2.1.0@sha256:da418b1f5655c12d2d62aa3d189117bfad5d83c2ab99bb3e82b2eaaf5246bbc1";
            nixSha256 = "sha256-CZIUqqb+X13y8pjQYYQGaSZiv9PSDID9NOkIkebHltU=";
            networks = [
              "traefik"
            ];
            extraOptions = [ "--dns=1.1.1.1" ];
            volumes = [
              "/data/services/uptime-kuma:/app/data"
            ];
            environment = {
              UPTIME_KUMA_PORT = "3001";
            };
            labels =
              (mkTraefikLabels {
                name = "status";
                port = "3001";
              })
              // {
                "homepage.group" = "Monitoring";
                "homepage.name" = "Uptime Kuma";
                "homepage.icon" = "uptime-kuma";
                "homepage.href" = "https://status.${domain}";
                "homepage.description" = "Uptime monitoring and status page";
              };
          };
        };
    };
}
