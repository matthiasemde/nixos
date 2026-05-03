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
            rawImageReference = "louislam/uptime-kuma:2.3.2@sha256:9aeb4e51d038047f414309c77a1af553281ca535723cb88907d907269d0a908e";
            nixSha256 = "sha256-181eBHUiu58Z8WUX74ULsLM7xHG7R4EQg1m3ANe685I=";
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
