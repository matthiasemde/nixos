{
  config,
  lib,
  domain,
  mkTraefikLabels,
  ...
}:
let
  backendNetwork = "music-assistant-backend";
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
    myVirtualization.networks.${backendNetwork} = "";

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
        backendNetwork
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
      rawImageReference = "ghcr.io/music-assistant/server:2.10.6@sha256:f56bc2e4466a17081c9cab6a75a35135b512dc50d2fc77a3d4f4d4312ef28949";
      nixSha256 = "sha256-9mZL9M9myWtk5ztMMHwQ4IaeFjvGdR3kOB9hZRP9PBo=";
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/data/services/music-assistant/data:/data"
      ];
      networks = lib.optional (musicAssistantLanIp != null) lanMacvlanNetwork ++ [
        "traefik"
        backendNetwork
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
  };
}
