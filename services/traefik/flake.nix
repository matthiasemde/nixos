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
            rawImageReference = "traefik:v3.6.7@sha256:2c5e029ee3638d3788b4ca7c8ef454baa8f924b91b190b3fd2742bee721ebeea";
            nixSha256 = "sha256-6yTT3I8MdwU6618LsHCO0Esu9GFQXWhiKNliZclRdfc=";
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
            rawImageReference = "nginx:1.29.5-alpine@sha256:05fcc6f6c80dc65c0f241f250677aad26e0962d118abaa65a513796862ff915d";
            nixSha256 = "sha256-p+94y2vOQYXatNh9ldg4KrW4e50juQqYPpiV8fa2ALg=";
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
