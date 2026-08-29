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
    rawImageReference = "louislam/uptime-kuma:2.5.3@sha256:3e24e96c89efff0e3a4b0698cbdd36c15ad3022371db57166e5588853002ee5c";
    nixSha256 = "sha256-fqdw0ZOCRDpf/N/PohldELm0Ssgs5KVtBKE930N0h2U=";
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
