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
            rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.33.2@sha256:a44ed89b3e845faa1f7d353f2cc89b2fcd8011737dd14075fa963cf9468da3a5";
            nixSha256 = "sha256-vqjTXtWv3nLVUPxjkSZSCzgCQgZl8dKCwRa+S4Tfyw4=";
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
