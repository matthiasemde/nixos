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
            rawImageReference = "louislam/uptime-kuma:2.2.0@sha256:85d68948704fcadc7438f45c9f2666ef2239b5b84073479e1c5bc4d4d8b6d17c";
            nixSha256 = "sha256-hzLZQDMHbTE7yEq5xSC/RlihO6wrs+W47nj6TU2C0dw=";
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
