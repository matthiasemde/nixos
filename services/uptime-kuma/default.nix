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
    rawImageReference = "louislam/uptime-kuma:2.4.0@sha256:91e963bfda569ba115206e843febb446f473ab525add4e08b2b9e3beffa16985";
    nixSha256 = "sha256-DTehQtc6Z68wnvLEoX2cej4WEwuqWR9RQ9uMs4T2x7U=";
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
