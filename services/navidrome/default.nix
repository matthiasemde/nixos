{
  config,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
in
{
  myVirtualization.containers.navidrome.app = {
    rawImageReference = "deluan/navidrome:0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52";
    nixSha256 = "sha256-cvjgnX4hHIm0syuUTMr5iI0IpDg2tNCnpfbLAFTJjRc=";
    environment = {
      ND_SCANSCHEDULE = "1h";
      ND_LOGLEVEL = "warn";
      ND_SESSIONTIMEOUT = "24h";
      ND_BASEURL = "";
      ND_EXTAUTH_TRUSTEDSOURCES = "0.0.0.0/0, ::/0";
      ND_EXTAUTH_USERHEADER = "X-authentik-username";
      ND_ENABLEEXTERNALSERVICES = "false";
      ND_ENABLEUSEREDITING = "false";
      ND_ENABLEINSIGHTSCOLLECTOR = "false";
    };
    environmentFiles = getEnvFiles "navidrome" "navidrome";
    volumes = [
      "/data/services/navidrome/data:/data"
      "/data/nas/navidrome/shared-library:/music/shared:ro"
      "/data/nas/files/Musik:/music/local:ro"
      "/data/nas/home/Theresa/Musik:/music/theresa:ro"
      "/data/nas/home/Matthias/Music:/music/matthias:ro"
    ];
    networks = [ "traefik" ];
    labels =
      (mkTraefikLabels {
        name = "navidrome";
        port = "4533";
        useForwardAuth = true;
      })
      // {
        "traefik.http.routers.navidrome-rest.entrypoints" = "websecure";
        "traefik.http.routers.navidrome-rest.rule" = "Host(`navidrome.${domain}`) && PathPrefix(`/rest/`)";
        "traefik.http.routers.navidrome-rest.tls.certresolver" = "myresolver";
        "traefik.http.routers.navidrome-rest.tls.domains[0].main" = "navidrome.${domain}";
        "traefik.http.routers.navidrome-rest.service" = "navidrome";

        "homepage.group" = "Media";
        "homepage.name" = "Navidrome";
        "homepage.icon" = "navidrome";
        "homepage.href" = "https://navidrome.${domain}";
        "homepage.description" = "Music streaming server";
      };
  };
}
