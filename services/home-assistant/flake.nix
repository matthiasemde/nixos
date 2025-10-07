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
        { parseDockerImageReference, ... }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          homeAssistantRawImageReference = "ghcr.io/home-assistant/home-assistant:2025.7@sha256:e5bf3905955081dc4aae3b3980870c43ce6d8ffb880b5447addb3b3ba00f7bc0";
          homeAssistantImageReference = parseDockerImageReference homeAssistantRawImageReference;
          homeAssistantImage = pkgs.dockerTools.pullImage {
            imageName = homeAssistantImageReference.name;
            imageDigest = homeAssistantImageReference.digest;
            finalImageTag = homeAssistantImageReference.tag;
            sha256 = "sha256-wDWbAGOx6TkH10ZoOnTnzSAbTfr8UW4hOjNTgTOokps=";
          };
        in
        {
          home-assistant = {
            image = homeAssistantImageReference.name + ":" + homeAssistantImageReference.tag;
            imageFile = homeAssistantImage;
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
