{ config, lib, mkTraefikLabels, getEnvFiles, getSecretFile, ... }:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.networks.traefik = "--ipv6";

  myVirtualization.containers.traefik.server = {
    rawImageReference = "traefik:v3.7.12@sha256:9c2a54d87f76f5c2f5f2682c68394af92fb12c0a2686798d6462a3f84bd78eaf";
    nixSha256 = "sha256-Be4cRdKoI9CNm89Jq+JL3lBQZhkky5dYrx29qptcaCY=";
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
    volumes =
      [
        "/var/run/docker.sock:/var/run/docker.sock"
        "${./config/traefik.toml}:/traefik.toml:ro"
        "${./config/middlewares.toml}:/etc/traefik/dynamic/middlewares.toml:ro"
        "/data/services/traefik/certs:/certs"
      ]
      ++ lib.optional config.myInfrastructure.useCrowdsec
        "${getSecretFile "traefik" "server" "crowdsec.toml"}:/etc/traefik/dynamic/crowdsec.toml:ro";
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

  myVirtualization.containers.traefik.error-pages = {
    rawImageReference = "nginx:1.31.5-alpine@sha256:34f40471dea485273c5e2a04dd5e97a682332ceb4a9adecd67de450dcb2fb390";
    nixSha256 = "sha256-kNgaEBAOSIdjl/8E6uiPttX+WJDyVOz+T9HSc7++gnk=";
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
