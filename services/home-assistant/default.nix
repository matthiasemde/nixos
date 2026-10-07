{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.dependencies.files."/data/services/home-assistant/home-assistant.db" = "644";

  myVirtualization.containers.home-assistant.app = {
    rawImageReference = "ghcr.io/home-assistant/home-assistant:2026.10@sha256:1b64d38f38d922bf9d59336451fd6453e1d614f934456af4ee3d2a51061be3a4";
    nixSha256 = "sha256-a2aEHgsTRdUlocC96z2IyY1EA20VGnUjqRX1TiQMv2g=";
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/data/services/home-assistant/home-assistant.db:/config/home-assistant.db"
      "/data/services/home-assistant/.storage:/config/.storage"
      "/data/services/home-assistant/.cloud:/config/.cloud"
      "${./config/configuration.yaml}:/config/configuration.yaml:ro"
      "${./config/automations.yaml}:/config/automations.yaml:ro"
      "${./config/scripts.yaml}:/config/scripts.yaml:ro"
      "${./config/scenes.yaml}:/config/scenes.yaml:ro"
    ];
    networks = [ "traefik" ];
    environment = {
      TZ = "Europe/Berlin";
    };
    labels =
      (mkTraefikLabels {
        name = "home-assistant";
        port = "8123";
      })
      // {
        "homepage.group" = "Home Automation";
        "homepage.name" = "Home Assistant";
        "homepage.icon" = "home-assistant";
        "homepage.href" = "https://home-assistant.${domain}";
        "homepage.description" = "Smart home control";
      };
  };
}
