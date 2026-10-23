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
    rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.37.2@sha256:b897c33f05972fb1bf484f7487bc878fa91ec8691335c1db6e2929c3a7658efa";
    nixSha256 = "sha256-wthqc70p2Ewzd5XyO00hwYFGrwW5rZHDxlQRA5Ie5Vs=";
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
