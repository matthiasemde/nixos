{
  description = "Service flake exporting Traefik container config";

  outputs =
    { self, nixpkgs }:
    {
      name = "traefik";
      networks = {
        traefik = "--ipv6";
      };
      containers =
        {
          hostname,
          getServiceEnvFiles,
          ...
        }:
        {
          traefik = {
            rawImageReference = "traefik:v3.6.6@sha256:82d3d16dde0474a51fef00b28de143d48b67f7a27453224d5e7b5aaefff26a97";
            nixSha256 = "sha256-tNtGRH+XS2Yjd7yPCgTO4QSQeoQp0w8AgrkIe73SgRA=";
            ports = [
              "80:80"
              "443:443"
              "8080:8080"
            ];
            networks = [
              "traefik"
              "frp-ingress"
            ];
            environmentFiles = getServiceEnvFiles "traefik";
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "${./config/traefik.toml}:/traefik.toml:ro"
              "${./config/middlewares.toml}:/etc/traefik/middlewares.toml:ro"
              "/data/services/traefik/certs:/certs"
            ];
            cmd = [
              "--configFile=traefik.toml"
            ];
            labels = {
              "homepage.group" = "Utilities";
              "homepage.name" = "Traefik";
              "homepage.icon" = "traefik";
              "homepage.href" = "http://${hostname}:8080";
              "homepage.description" = "Reverse proxy dashboard";
            };
          };

          error-pages = {
            rawImageReference = "nginx:1.29.4-alpine@sha256:1e462d5b3fe0bc6647a9fbba5f47924b771254763e8a51b638842890967e477e";
            nixSha256 = "sha256-qgeS1JFHApzVUad0UvVF1pPuvdvg0o2+Q3g8GXu1By8=";
            networks = [
              "traefik"
            ];
            volumes = [
              "${./config/error.html}:/usr/share/nginx/html/error.html:ro"
              "${./config/nginx.conf}:/etc/nginx/nginx.conf:ro"
            ];
            labels = {
              "traefik.enable" = "true";

              # # Catch-all router (lowest priority)
              "traefik.http.routers.catchall.rule" = "PathPrefix(`/`)";
              "traefik.http.routers.catchall.priority" = "1";
              "traefik.http.routers.catchall.entrypoints" = "web";

              # Define the service used by the catchall router
              "traefik.http.services.catchall-service.loadbalancer.server.port" = "80";

              # Optional: Add a middleware to customize response (static page)
              "traefik.http.routers.catchall.middlewares" = "error-mw";
              "traefik.http.middlewares.error-mw.errors.status" = "404";
              "traefik.http.middlewares.error-mw.errors.service" = "catchall-service";
              "traefik.http.middlewares.error-mw.errors.query" = "/error.html";
            };
          };
        };
    };
}
