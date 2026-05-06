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
            rawImageReference = "ghcr.io/home-assistant/home-assistant:2026.5@sha256:8edcb16cff8158e87a3a2b48b3bcca05c30dcea0212eb6a2fe940b6d52ed216a";
            nixSha256 = "sha256-vDeHmDqwjLyZwjGWd99iAb8UuuQs6wogt/BF91vwMh4=";
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
