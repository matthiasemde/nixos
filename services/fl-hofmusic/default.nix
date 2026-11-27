{ ... }:
{
  myVirtualization.containers.fl-hofmusic.app = {
    rawImageReference = "nginx:1.31.9-alpine@sha256:fb4658584bd9a916ffb6f6e365f97c25cfdb2923801f551ea08356e695f14ff7";
    nixSha256 = "sha256-i+TzTP3yfHHgiMM1gsKq65gl4Yk6c4ksRmKeXNh5/Ds=";
    networks = [ "traefik" ];
    volumes = [
      "${./config/nginx.conf}:/etc/nginx/nginx.conf:ro"
      "/data/services/fl-hofmusic/website:/usr/share/nginx/html:ro"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.services.fl-hofmusic.loadbalancer.server.port" = "80";
      "traefik.http.routers.fl-hofmusic-public.entrypoints" = "websecure";
      "traefik.http.routers.fl-hofmusic-public.rule" = "Host(`fuerstliche-hofmusic.de`)";
      "traefik.http.routers.fl-hofmusic-public.tls.certresolver" = "myresolver";
      "traefik.http.routers.fl-hofmusic-public.tls.domains[0].main" = "fuerstliche-hofmusic.de";
      "traefik.http.routers.fl-hofmusic-public.service" = "fl-hofmusic";

      "traefik.http.routers.fl-hofmusic-public-http.entrypoints" = "web";
      "traefik.http.routers.fl-hofmusic-public-http.rule" = "Host(`fuerstliche-hofmusic.de`)";
      "traefik.http.routers.fl-hofmusic-public-http.middlewares" = "redirect-to-https@docker";
      "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme" = "https";
    };
  };
}
