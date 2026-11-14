{ config, lib, mkTraefikLabels, getEnvFiles, getSecretFile, ... }:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.networks.traefik = "--ipv6";

  myVirtualization.containers.traefik.server = {
    rawImageReference = "traefik:v3.7.17@sha256:f4bb143d1135a579b630ed491e17ec50f6f7c9c6a30585ff3d385471d2a86f5a";
    nixSha256 = "sha256-RWtBJubRvdnkpTLoO9sKS6daiHSy8qmiTSRsr8rp588=";
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
    rawImageReference = "nginx:1.31.8-alpine@sha256:785835ea65db4bba6f021acc0f3be91b0fef76a53fe41f8588c6698d2aed0606";
    nixSha256 = "sha256-mi02S6idRdhsMe16qCb01RYBWp/qKaYKYtdCc6PaSQQ=";
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
