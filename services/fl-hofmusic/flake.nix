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
            rawImageReference = "nginx:1.29.5-alpine@sha256:1d13701a5f9f3fb01aaa88cef2344d65b6b5bf6b7d9fa4cf0dca557a8d7702ba";
            nixSha256 = "sha256-p+94y2vOQYXatNh9ldg4KrW4e50juQqYPpiV8fa2ALg=";
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
