{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.audiobookshelf.app = {
    rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.38.0@sha256:60064c23f32fd9099fd39e82c5132c51701d1221135bbca04cd099b589e1edc3";
    nixSha256 = "sha256-yNWGvI0+W91r8wl63zK/ebdWFrwmR/3+KsUABmluksI=";
    environment = {
      TZ = "Europe/Berlin";
    };
    volumes = [
      "/data/services/audiobookshelf/config:/config"
      "/data/services/audiobookshelf/metadata:/metadata"
      "/data/nas/audiobookshelf/audiobooks:/audiobooks"
      "/data/nas/audiobookshelf/podcasts:/podcasts"
    ];
    networks = [
      "traefik"
      "music-assistant-backend"
    ];
    labels =
      (mkTraefikLabels {
        name = "audiobookshelf";
        port = "80";
      })
      // {
        "homepage.group" = "Media";
        "homepage.name" = "Audiobookshelf";
        "homepage.icon" = "audiobookshelf";
        "homepage.href" = "https://audiobookshelf.${domain}";
        "homepage.description" = "Audiobook and podcast server";
      };
  };
}
