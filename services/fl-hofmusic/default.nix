{ ... }:
{
  myVirtualization.containers.fl-hofmusic = {
    rawImageReference = "nginx:1.31.1-alpine@sha256:8b1e78743a03dbb2c95171cc58639fef29abc8816598e27fb910ed2e621e589a";
    nixSha256 = "sha256-DpQKJKWP2RNkSQdoSRR9qJnMwOaKcCf9gr13tEFkh6g=";
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
