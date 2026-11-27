{ config, lib, mkTraefikLabels, getEnvFiles, getSecretFile, ... }:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.networks.traefik = "--ipv6";

  myVirtualization.containers.traefik.server = {
    rawImageReference = "traefik:v3.7.19@sha256:a6c0194dda77bcb804824580f36fa7edc56e315b1acfe933366c8b52844a78a4";
    nixSha256 = "sha256-NZ8SPH/dnwgy069Ydny2xlBViJYW0z4902lg0WfaDDc=";
    ports = [
      "80:80" # web
      "443:443" # websecure
      "1883:1883" # mqtt
      "8080:8080" # traefik ui
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
    rawImageReference = "nginx:1.31.9-alpine@sha256:fb4658584bd9a916ffb6f6e365f97c25cfdb2923801f551ea08356e695f14ff7";
    nixSha256 = "sha256-i+TzTP3yfHHgiMM1gsKq65gl4Yk6c4ksRmKeXNh5/Ds=";
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
