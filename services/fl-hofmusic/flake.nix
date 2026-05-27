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
            rawImageReference = "nginx:1.31.0-alpine@sha256:2f07d83bf561b506400dc183b1b2003803e39efbd22451f848adaba14d28c7c7";
            nixSha256 = "sha256-DpQKJKWP2RNkSQdoSRR9qJnMwOaKcCf9gr13tEFkh6g=";
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
