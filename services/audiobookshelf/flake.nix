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
            rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.34.0@sha256:4143292c530f6ac6700afd13360c04f477e4f1a81c1c97c4224b1c7e4330c5c4";
            nixSha256 = "sha256-GHUZcN9o31StqHeXOGJfJ3JX3+RpTtCQaomO5tB+1d4=";
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
