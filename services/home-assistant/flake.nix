{
  description = "Service flake exporting Home Assistant container config";

  outputs =
    { self, nixpkgs }:
    {
      name = "home-assistant";
      dependencies = {
        files = {
          "/data/services/home-assistant/home-assistant.db" = "644";
          "/etc/logs/home-assistant.log" = "644";
        };
      };
      containers =
        {
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          home-assistant = {
            rawImageReference = "ghcr.io/home-assistant/home-assistant:2026.4@sha256:8848691147f01a6eee7753de2ade21b04d6168fcd2e2a7089f6f84e3b7b86960";
            nixSha256 = "sha256-537Ebdcsmif2IVJLEuxQw5T8Sb6nWfquaQdbZ67xhnw=";
            volumes = [
              "/etc/logs/home-assistant.log:/config/home-assistant.log"
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
                # 🏠 Homepage integration
                "homepage.group" = "Home Automation";
                "homepage.name" = "Home Assistant";
                "homepage.icon" = "home-assistant";
                "homepage.href" = "https://home-assistant.${domain}";
                "homepage.description" = "Smart home control";
              };
          };
        };
    };
}
