{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.uptime-kuma.app = {
    rawImageReference = "louislam/uptime-kuma:2.5.1@sha256:ecd5b8c8b49fe9436c735de9c72b161fcc2b6d8710599393d369a2f6e0167d02";
    nixSha256 = "sha256-JgvDJO+80iNYPUps2tlia5nu0cngC1jT23zOPtAI6Gc=";
    networks = [ "traefik" ];
    extraOptions = [ "--dns=1.1.1.1" ];
    volumes = [
      "/data/services/uptime-kuma:/app/data"
    ];
    environment = {
      UPTIME_KUMA_PORT = "3001";
    };
    labels =
      (mkTraefikLabels {
        name = "status";
        port = "3001";
      })
      // {
        "homepage.group" = "Monitoring";
        "homepage.name" = "Uptime Kuma";
        "homepage.icon" = "uptime-kuma";
        "homepage.href" = "https://status.${domain}";
        "homepage.description" = "Uptime monitoring and status page";
      };
  };
}
