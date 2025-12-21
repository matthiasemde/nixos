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
            rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.31.0@sha256:e23adb24848d99d19cd1e251aee4e1e12ed4f5effc8ccb21754b062b6a06cf66";
            nixSha256 = "sha256-Dba/9rXYtdGyJIeI9dKIlPrNRgcGD3MmaycEpktHBCU=";
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
