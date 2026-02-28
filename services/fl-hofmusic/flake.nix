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
            rawImageReference = "nginx:1.29.4-alpine@sha256:1e462d5b3fe0bc6647a9fbba5f47924b771254763e8a51b638842890967e477e";
            nixSha256 = "sha256-qgeS1JFHApzVUad0UvVF1pPuvdvg0o2+Q3g8GXu1By8=";
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
