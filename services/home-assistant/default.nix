{
  config,
  lib,
  domain,
  mkTraefikLabels,
  ...
}:
let
  haBackendNetwork = "home-assistant-backend";
  maBackendNetwork = "music-assistant-backend";
  lanMacvlanNetwork = "adguard-macvlan";
  musicAssistantLanIp = config.music-assistant.lanIp;
in
{
  options.home-assistant.zigbeeDongleId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_xxxx-if00";
    description = "Serial ID of the Zigbee dongle (name under /dev/serial/by-id/). If set, it is passed into the container at /dev/zigbee.";
  };

  options.music-assistant.lanIp = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Static IPv4 address for Music Assistant on the shared LAN macvlan.";
  };

  config = {
    myVirtualization.networks.${haBackendNetwork} = "";
    myVirtualization.networks.${maBackendNetwork} = "";

    myVirtualization.containers.home-assistant.app = {
      rawImageReference = "ghcr.io/home-assistant/home-assistant:2026.10@sha256:1b64d38f38d922bf9d59336451fd6453e1d614f934456af4ee3d2a51061be3a4";
      nixSha256 = "sha256-a2aEHgsTRdUlocC96z2IyY1EA20VGnUjqRX1TiQMv2g=";
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/data/services/home-assistant:/config"
      ];
      devices = lib.optional (
        config.home-assistant.zigbeeDongleId != null
      ) "/dev/serial/by-id/${config.home-assistant.zigbeeDongleId}:/dev/zigbee";
      networks = [
        "traefik"
        haBackendNetwork
        maBackendNetwork
      ];
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

    myVirtualization.containers.music-assistant.app = {
      rawImageReference = "ghcr.io/music-assistant/server:2.10.7@sha256:ac3263065888579ac69abe5c71ee33e3df1e39d4d42e5bc529dd8f81ea2c67c5";
      nixSha256 = "sha256-9mZL9M9myWtk5ztMMHwQ4IaeFjvGdR3kOB9hZRP9PBo=";
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/data/services/music-assistant/data:/data"
      ];
      networks = lib.optional (musicAssistantLanIp != null) lanMacvlanNetwork ++ [
        "traefik"
        haBackendNetwork
        maBackendNetwork
      ];
      extraOptions = lib.optional (musicAssistantLanIp != null) "--ip=${musicAssistantLanIp}";
      environment = {
        # Provide logging level as environment variable.
        # default=info, possible=(critical, error, warning, info, debug)
        LOG_LEVEL = "info";
      };
      labels =
        (mkTraefikLabels {
          name = "music-assistant";
          port = "8095";
          isPublic = false;
        })
        // {
          "homepage.group" = "Home Automation";
          "homepage.name" = "Music Assistant";
          "homepage.icon" = "music-assistant";
          "homepage.href" = "https://music-assistant.${domain}";
          "homepage.description" = "Music control in your home";
        };
    };

    myVirtualization.containers.whisper.server = {
      rawImageReference = "rhasspy/wyoming-whisper:3.8.1@sha256:99999ececb7b5d1d176689a81cc78f281d5fdd2a3b29a24b51b85154ab704acd";
      nixSha256 = "sha256-HZjOXzy/OmL8wUc9u0N8sPdJOVm0ueQ1MENr2zb6GRY=";
      volumes = [
        "/data/services/whisper/data:/data"
      ];
      networks = [
         haBackendNetwork
      ];
      cmd = [
        "--model"
        "small-int8"
        "--language"
        "de"
      ];
    };

    myVirtualization.containers.piper.server = {
      rawImageReference = "rhasspy/wyoming-piper:2.5.2@sha256:7d39aafac409c2b6b09d999ed04d84c311d632e558b35baa60fad6aac722af7a";
      nixSha256 = "sha256-qgP3wq5whUPHHjEb39oM94kjCZEmNF9cd/rKAvX2Bcs=";
      volumes = [
        "/data/services/piper/data:/data"
      ];
      networks = [
        haBackendNetwork
      ];
      cmd = [
        "--voice"
        "de_DE-thorsten-high"
      ];
    };
  };
}
