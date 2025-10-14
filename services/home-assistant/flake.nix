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
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          homeAssistantRawImageReference = "ghcr.io/home-assistant/home-assistant:2025.10@sha256:5ae78cf2e6d8b53439cac50ed184ff1336cfbbb878fce16f75589e048fcdcdd9";
          homeAssistantImageReference = parseDockerImageReference homeAssistantRawImageReference;
          homeAssistantImage = pkgs.dockerTools.pullImage {
            imageName = homeAssistantImageReference.name;
            imageDigest = homeAssistantImageReference.digest;
            finalImageTag = homeAssistantImageReference.tag;
            sha256 = "sha256-0qgXX8zxUa2eMs+8qGWGKWmPU7PrhuhFcfa8gFGntO0=";
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
