{
  description = "Service flake exporting Web Projects static server container config";

  outputs =
    { self, nixpkgs }:
    {
      name = "fl-hofmusic";
      containers =
        {
          parseDockerImageReference,
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          fl-hofmusic = {
            rawImageReference = "nginx:1.30.0-alpine@sha256:f60d139a69209d4340f6621fc6a50c9843702214231522a3390432f8db0ed870";
            nixSha256 = "sha256-p/wXlo+5I07qOfGEvlSceEJBuQumGODGWUF8cQJVmjE=";
            networks = [
              "traefik"
            ];
            volumes = [
              "${./config/nginx.conf}:/etc/nginx/nginx.conf:ro"
              "/data/services/fl-hofmusic/website:/usr/share/nginx/html:ro"
            ];
            labels = {
              # 🛡️ Enable traffic
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
        };
    };
}
