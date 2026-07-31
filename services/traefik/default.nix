{ config, lib, mkTraefikLabels, getEnvFiles, getSecretFile, ... }:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.networks.traefik = "--ipv6";

  myVirtualization.containers.traefik.server = {
    rawImageReference = "traefik:v3.7.9@sha256:652929a140a32d7cafafb13c6cdfab5376cfeff800f51397b87b524501ed02a8";
    nixSha256 = "sha256-BHTUUc/J0cvkzdTGUkUxYa8r192WueZdh1cMwzJdLik=";
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
    rawImageReference = "nginx:1.31.3-alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752";
    nixSha256 = "sha256-q3wcRf2vAOya2ty38o0a7ARPVnDJ2sfOmdzdsrhpm2c=";
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
