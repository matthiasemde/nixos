{ ... }:
{
  myVirtualization.containers.fl-hofmusic.app = {
    rawImageReference = "nginx:1.31.5-alpine@sha256:34f40471dea485273c5e2a04dd5e97a682332ceb4a9adecd67de450dcb2fb390";
    nixSha256 = "sha256-kNgaEBAOSIdjl/8E6uiPttX+WJDyVOz+T9HSc7++gnk=";
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
