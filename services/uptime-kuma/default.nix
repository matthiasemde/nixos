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
    rawImageReference = "louislam/uptime-kuma:2.5.7@sha256:4b95dbe7ac5343b768f8e04e3035ccd59997872b1a35ab9b0f082d2cc279070e";
    nixSha256 = "sha256-ZELnPM5/N3B/y/Fu2yISkkij+gwOakMy4P9oWsN6+D0=";
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
