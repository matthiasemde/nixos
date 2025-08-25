{
  description = "Service flake exporting Home Assistant container config";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, ... }:
    {
      name = "home-assistant";
      dependencies = {
        files = {
          "/data/services/home-assistant/home-assistant.db" = "644";
          "/etc/logs/home-assistant.log" = "644";
        };
      };
      containers =
        { ... }:
        {
          home-assistant = {
            image = "ghcr.io/home-assistant/home-assistant:2025.7";
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
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.ha.rule" = "HostRegexp(`home-assistant.*`)";
              "traefik.http.routers.ha.entrypoints" = "websecure";
              "traefik.http.routers.ha.tls.certresolver" = "myresolver";
              "traefik.http.routers.ha.tls.domains[0].main" = "home-assistant.emdecloud.de";
              "traefik.http.services.ha.loadbalancer.server.port" = "8123";

              # 🏠 Homepage integration
              "homepage.group" = "Home Automation";
              "homepage.name" = "Home Assistant";
              "homepage.icon" = "home-assistant";
              "homepage.href" = "https://home-assistant.emdecloud.de";
              "homepage.description" = "Smart home control";
            };
          };
        };
    };
}
