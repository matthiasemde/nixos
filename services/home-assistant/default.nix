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
    rawImageReference = "ghcr.io/home-assistant/home-assistant:2026.6@sha256:aed891b8f801072302815b4b0fab5adb714182967e9d2e2d4a2be558241c73ad";
    nixSha256 = "sha256-xW0G58GJUVHBOz5IulKG2lAuTFCUAfimRnZbizJw0OA=";
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
