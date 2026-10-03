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
    rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.37.1@sha256:581d68b2a6fc7ebf58d81c878a9f387cbbc0d88ac9d37b298b9cee10168af85b";
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
    networks = [ "traefik" ];
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
