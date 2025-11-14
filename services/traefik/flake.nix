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
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          traefikRawImageReference = "traefik:v3.6.1@sha256:fd5932c796f7e2db9fd6bff485ef693d53797f0ee8ad03dc68aa424ea6f21958";
          traefikImageReference = parseDockerImageReference traefikRawImageReference;
          traefikImage = pkgs.dockerTools.pullImage {
            imageName = traefikImageReference.name;
            imageDigest = traefikImageReference.digest;
            finalImageTag = traefikImageReference.tag;
            sha256 = "sha256-B92gzeZ8ja8is6i2nlcdisbGAMuCOy8d/92eSGGF+14=";
          };

          nginxRawImageReference = "nginx:1.29.3-alpine@sha256:b23ea6c10814fccb32ac20485c74168ebefa1c3544a3dddfcb33494d24270df8";
          nginxImageReference = parseDockerImageReference nginxRawImageReference;
          nginxImage = pkgs.dockerTools.pullImage {
            imageName = nginxImageReference.name;
            imageDigest = nginxImageReference.digest;
            finalImageTag = nginxImageReference.tag;
            sha256 = "sha256-qrQIBp2EbKw3Aicu424rbu26v2T1LZgHVQ+hJKKZQxE=";
          };
        in
        {
          traefik = {
            image = traefikImageReference.name + ":" + traefikImageReference.tag;
            imageFile = traefikImage;
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
            image = nginxImageReference.name + ":" + nginxImageReference.tag;
            imageFile = nginxImage;
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
