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
            rawImageReference = "danielszabo99/microbin:2.1.4@sha256:6660e5ccad0d764fa3c0032464ffb8f4b4f28c92a2eb9e39202b94cdc5b68909";
            nixSha256 = "sha256-osXe26F3zmC2j1AiGjYsyJEbI4VY50H6AXmLQKaeXIo=";
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
