{ config, getEnvFiles, ... }:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.networks.traefik = "--ipv6";

  myVirtualization.containers.traefik = {
    rawImageReference = "traefik:v3.7.3@sha256:25cd7b175a493ea66a40329e23a649b59eda38b7e2a570493bf63fc4d74fd1c1";
    nixSha256 = "sha256-8zs51qeLsOiArncEb1UCvGo9uWstaF/K0vWHkGXtrIQ=";
    ports = [
      "80:80"
      "443:443"
      "8080:8080"
    ];
    networks = [
      "traefik"
      "frp-ingress"
    ];
    environmentFiles = getEnvFiles "traefik" "server";
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

  myVirtualization.containers.error-pages = {
    rawImageReference = "nginx:1.31.1-alpine@sha256:8b1e78743a03dbb2c95171cc58639fef29abc8816598e27fb910ed2e621e589a";
    nixSha256 = "sha256-1smG0epcEvN6OA/gQF3mxDMmKh8W33LQITKa37WjAP4=";
    networks = [ "traefik" ];
    volumes = [
      "${./config/error.html}:/usr/share/nginx/html/error.html:ro"
      "${./config/nginx.conf}:/etc/nginx/nginx.conf:ro"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.catchall.rule" = "PathPrefix(`/`)";
      "traefik.http.routers.catchall.priority" = "1";
      "traefik.http.routers.catchall.entrypoints" = "web";
      "traefik.http.services.catchall-service.loadbalancer.server.port" = "80";
      "traefik.http.routers.catchall.middlewares" = "error-mw";
      "traefik.http.middlewares.error-mw.errors.status" = "404";
      "traefik.http.middlewares.error-mw.errors.service" = "catchall-service";
      "traefik.http.middlewares.error-mw.errors.query" = "/error.html";
    };
  };
}
