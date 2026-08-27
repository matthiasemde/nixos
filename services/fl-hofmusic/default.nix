{ ... }:
{
  myVirtualization.containers.fl-hofmusic.app = {
    rawImageReference = "nginx:1.31.4-alpine@sha256:db35bfc6b2951e7f8a72db5db120288c127ffaeeb4a6d4b95a26fead017d5913";
    nixSha256 = "sha256-ojx6je2LYk9IouKgxEo7XKV/hfT6ZZX1grlGdpn8W6s=";
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
