{
  description = "Service flake exporting Traefik container config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      name = "traefik";
      networks = {
        traefik = "";
      };
      containers =
        { hostname, getServiceEnvFiles, ... }:
        {
          traefik = {
            image = "traefik:v3.4.3";
            ports = [
              "80:80"
              "443:443"
              "8080:8080"
            ];
            extraOptions = [ "--dns=1.1.1.1" ];
            networks = [
              "traefik"
              "frp-ingress"
            ];
            environmentFiles = getServiceEnvFiles "traefik";
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "${./config/traefik.toml}:/traefik.toml:ro"
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
            image = "nginx:alpine";
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
