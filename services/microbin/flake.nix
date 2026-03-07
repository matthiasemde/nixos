{
  description = "Service flake for MicroBin";

  outputs =
    { self, nixpkgs }:
    {
      name = "microbin";
      containers =
        {
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          microbin = {
            rawImageReference = "danielszabo99/microbin:2.1.2@sha256:4e08d1d127e5804f5e43a63c0c9555497d506ee94abb570214134b73a4810f62";
            nixSha256 = "sha256-23787kAeEAXa7ZDD3XW+e+76nXPvgF41QfD5+qeHhsg=";
            networks = [ "traefik" ];
            volumes = [
              "/data/services/microbin/data:/app/microbin_data"
            ];
            environment = {
              MICROBIN_PUBLIC_PATH = "https://microbin.${domain}";
              MICROBIN_DISABLE_UPDATE_CHECKING = "true";
            };
            labels =
              mkTraefikLabels {
                name = "microbin";
                port = "8080";
              }
              // {
                "homepage.group" = "Utilities";
                "homepage.name" = "MicroBin";
                "homepage.icon" = "microbin";
                "homepage.href" = "https://microbin.${domain}";
                "homepage.description" = "File-sharing and URL shortening";
              };
          };
        };
    };
}
