{
  config,
  lib,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  getSecretFile,
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
      rawImageReference = "ghcr.io/home-assistant/home-assistant:2026.11.0.dev202610240224@sha256:134c8907536a4f304609e99bba00ead729e343d7b4159037ec01e9c28802d098";
      nixSha256 = "sha256-OoXJ4zxiA0fb9WlyfXmzomMXoZP50ymnU41o54KdQeQ=";
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/data/nas/home/Matthias/Documents/projects/home-assistant-configuration:/config"
        "/data/services/database/home-assistant_v2.db:/config/home-assistant_v2.db"
        "/data/services/home-assistant/config/backups:/config/backups"
        "/data/services/home-assistant/config/image:/config/image"
        "/data/services/home-assistant/config/tts:/config/tts"
        "/data/services/home-assistant/config/zigbee.db:/config/zigbee.db"
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
        HA_DISABLE_LOG_FILE = "1";
        # DB_URL = "mysql://home-assistant:\${DB_PASSWORD}@home-assistant--database/home-assistant?charset=utf8mb4";
      };
      environmentFiles = getEnvFiles "home-assistant" "app";
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

    myVirtualization.containers.home-assistant.database = {
      rawImageReference = "mariadb:12.3.3@sha256:99c125f103f5d081ebbc9ffe064e63daf7f688ac33a5f7f29af2d7260a96debf";
      nixSha256 = "sha256-cDkRVOATNV+aCGHukGmGo2LkvcDvYOObrtYVdhkvhJc=";
      volumes = [
        "/data/services/home-assistant/database:/var/lib/mysql:z"
      ];
      networks = [ haBackendNetwork ];
      environment = {
        MARIADB_DATABASE = "home-assistant";
        MARIADB_USER = "home-assistant";
        MARIADB_RANDOM_ROOT_PASSWORD = "yes";
        MARIADB_ROOT_HOST = "localhost";
      };
      environmentFiles = getEnvFiles "home-assistant" "database";
      labels = {
        "traefik.enable" = "false";
      };
    };

    myVirtualization.containers.music-assistant.app = {
      rawImageReference = "ghcr.io/music-assistant/server:2.10.9@sha256:b4f5b466ff2967d775da270a02de75372c1fec128f383886dfb4a8c7e607a642";
      nixSha256 = "sha256-wBDj0mKUuoDf5Ed/5fxpjWZq33kgKpFy4YuWfiyUujE=";
      volumes = [
        "/etc/localtime:/etc/localtime:ro"
        "/data/services/music-assistant/data:/data"
      ];
      ports = [ "8095:8095" ];
      networks = lib.optional (musicAssistantLanIp != null) lanMacvlanNetwork ++ [
        "traefik"
        haBackendNetwork
        maBackendNetwork
      ];
      extraOptions = lib.optional (musicAssistantLanIp != null) "--ip=${musicAssistantLanIp}";
      environment = {
        # Provide logging level as environment variable.
        # default=info, possible=(critical, error, warning, info, debug)
        LOG_LEVEL = "warning";
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
      environment = {
        WYO_WHISPER_MODEL = "small-int8";
        WYO_WHISPER_LANGUAGE = "de";
        WYO_WHISPER_HASS_API = "http://home-assistant--app:8123/api";
      };
      environmentFiles = getEnvFiles "whisper" "server";
      networks = [
        haBackendNetwork
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

    myVirtualization.containers.mosquitto.server = {
      rawImageReference = "eclipse-mosquitto:2.0.22@sha256:cba7cd79d4e48b2e668b599c100bc5bb612a2c85aada76ab5a27987ecc81e3d7";
      nixSha256 = "sha256-gWaKQmySXNJtq+mn7l/A96k5EzHD0qGOHPrnEBCyMoA=";
      volumes = [
        "${./mosquitto.conf}:/mosquitto/config/mosquitto.conf"
        "${getSecretFile "mosquitto" "server" "passwd"}:/mosquitto/config/passwd"
        "/data/services/mosquitto/data:/mosquitto/data"
      ];
      networks = [
        "traefik"
        haBackendNetwork
      ];
      # ports = [ "1883:1883" ];
      labels = {
        "traefik.enable" = "true";
        "traefik.tcp.routers.mosquitto-local.entrypoints" = "mqtt";
        "traefik.tcp.routers.mosquitto-local.rule" = "HostSNI(`*`)";
        "traefik.tcp.routers.mosquitto-local.service" = "mosquitto";
        "traefik.tcp.services.mosquitto.loadbalancer.server.port" = "1883";
      };
    };
  };
}
