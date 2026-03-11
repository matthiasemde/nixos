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
            rawImageReference = "nginx:1.29.6-alpine@sha256:9a4a85e7006ced27ca077d759ffed671b8a094856703b0af15e2c28902800b1d";
            nixSha256 = "sha256-721iRIX2RQ9cID4tHPoLsoeTaDDbjVtR8StdfQuk+A4=";
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
