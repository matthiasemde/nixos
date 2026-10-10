{
  config,
  lib,
  domain,
  mkTraefikLabels,
  ...
}:
{
  options.home-assistant.zigbeeDongleId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_xxxx-if00";
    description = "Serial ID of the Zigbee dongle (name under /dev/serial/by-id/). If set, it is passed into the container at /dev/zigbee.";
  };

  config = {
    myVirtualization.dependencies.files."/data/services/home-assistant/home-assistant.db" = "644";

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
  };
}
