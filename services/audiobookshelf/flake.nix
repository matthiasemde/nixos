{
  description = "Audiobookshelf audiobook and podcast server container flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "audiobookshelf";
      containers =
        {
          domain,
          mkTraefikLabels,
          getServiceEnvFiles,
          ...
        }:
        {
          audiobookshelf = {
            rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.32.1@sha256:a52dc5db694a5bf041ce38f285dd6c6a660a4b1b21e37ad6b6746433263b2ae5";
            nixSha256 = "sha256-XYlkt0gH+Pxl2+sJQS0w6WcqnH8RuF6Ifq/Yb8Nuqdw=";
            environment = {
              TZ = "Europe/Berlin";
            };
            # environmentFiles = getServiceEnvFiles "audiobookshelf";
            volumes = [
              "/data/services/audiobookshelf/config:/config"
              "/data/services/audiobookshelf/metadata:/metadata"
              "/data/nas/audiobookshelf/audiobooks:/audiobooks"
              "/data/nas/audiobookshelf/podcasts:/podcasts"
            ];
            networks = [ "traefik" ];
            labels =
              (mkTraefikLabels {
                name = "audiobookshelf";
                port = "80";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Media";
                "homepage.name" = "Audiobookshelf";
                "homepage.icon" = "audiobookshelf";
                "homepage.href" = "https://audiobookshelf.${domain}";
                "homepage.description" = "Audiobook and podcast server";
              };
          };
        };
    };
}
