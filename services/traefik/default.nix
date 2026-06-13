{ config, mkTraefikLabels, getEnvFiles, ... }:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.networks.traefik = "--ipv6";

  myVirtualization.containers.traefik = {
    rawImageReference = "traefik:v3.7.4@sha256:fcdef599e6259359833dd2e1d49f9e964f66825d69bd3dd468f51102ce013d03";
    nixSha256 = "sha256-Jiy2Hqf5Lbm4RYE4+WdAG194hBQYcHakLalvc55iq6o=";
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
    labels =
      mkTraefikLabels {
        name = "traefik";
        port = "8080";
        useInfraForwardAuth = true;
      }
      // {
        "homepage.group" = "Utilities";
        "homepage.name" = "Traefik";
        "homepage.icon" = "traefik";
        "homepage.href" = "http://traefik.${hostname}.local";
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
