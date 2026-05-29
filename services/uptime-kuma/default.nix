{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.uptime-kuma = {
    rawImageReference = "louislam/uptime-kuma:2.3.2@sha256:9aeb4e51d038047f414309c77a1af553281ca535723cb88907d907269d0a908e";
    nixSha256 = "sha256-WBLgiCnE9GW91+Js8WcgA7iwP9BlC7bejI8Ca6cHuU0=";
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
