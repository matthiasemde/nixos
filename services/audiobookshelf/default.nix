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
    rawImageReference = "ghcr.io/advplyr/audiobookshelf:2.35.1@sha256:1eef6716183c52abafe5405e7d6be8390248ecd59c7488c44af871757ac8fc4d";
    nixSha256 = "sha256-nLIbMa2mZpUx7XZJvoN4tCa5v/L0vzPRYu12FFre1Kk=";
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
