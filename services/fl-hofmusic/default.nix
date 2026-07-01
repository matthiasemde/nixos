{ ... }:
{
  myVirtualization.containers.fl-hofmusic.app = {
    rawImageReference = "nginx:1.31.2-alpine@sha256:54f2a904c251d5a34adf545a72d32515a15e08418dae0266e23be2e18c66fefa";
    nixSha256 = "sha256-1smG0epcEvN6OA/gQF3mxDMmKh8W33LQITKa37WjAP4=";
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
