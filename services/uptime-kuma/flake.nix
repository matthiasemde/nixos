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
            rawImageReference = "louislam/uptime-kuma:2.3.0@sha256:a8e5e69ce185d5425fcbf2ab14ddf808df5651fb2747a46a17cecf8ed5fd1af2";
            nixSha256 = "sha256-TmA9VxZfozNejboQfNQUxeJjAXwa7jOAPRjnDu1PjIY=";
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
