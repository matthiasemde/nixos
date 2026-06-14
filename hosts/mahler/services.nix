{ lib, getSecretFile, ... }:
{
  imports = [
    ../../services/adguard
    ../../services/audiobookshelf
    ../../services/authentik
    ../../services/firefly
    ../../services/fl-hofmusic
    ../../services/frp
    ../../services/grafana
    ../../services/home-assistant
    ../../services/homepage
    ../../services/immich
    ../../services/kopia
    ../../services/lovebox
    ../../services/mealie
    ../../services/microbin
    ../../services/navidrome
    ../../services/nas
    ../../services/nextcloud
    # ../../services/ollama
    ../../services/outline
    ../../services/paperless
    # ../../services/pterodactyl
    ../../services/radicale
    # ../../services/silverbullet
    ../../services/synapse
    ../../services/traefik
    ../../services/uptime-kuma
    ../../services/vaultwarden
    ../../services/web-projects
    # ../../services/woodpecker
  ];

  options.myInfrastructure = {
    smtp = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "SMTP server hostname.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 465;
        description = "SMTP server port.";
      };
      fromAddress = lib.mkOption {
        type = lib.types.str;
        description = "Default sender address for outgoing mail.";
      };
    };
    adminEmail = lib.mkOption {
      type = lib.types.str;
      description = "Administrator email address.";
    };
  };

  config = {
    myInfrastructure.smtp = {
      host = "mail.privateemail.com";
      port = 465;
      fromAddress = "no-reply@emdecloud.de";
    };
    myInfrastructure.adminEmail = "matthias@emdemail.de";

    adguard.macvlan = {
      parentInterface = "enp6s0";
      subnet = "192.168.178.0/24";
      gateway = "192.168.178.1";
      ipRange = "192.168.178.240/28";
      ipv6Subnet = "fdfb:7759:b7ce::/64";
      ipv6Gateway = "fdfb:7759:b7ce::2e91:abff:fea2:270e";
      staticIp = "192.168.178.240";
    };

    # woodpecker.adminUser = "matthiasemde";

    frp.configPath = ./frpc.toml;
    mealie.oidcClientId = "e5DDiJkn8eaMjYMNt85W3NaDshnu5s67lXy79ava";
    grafana.oidcClientId = "E0ryu0936Q62OLtR4W1DHdPjz87RtJp3Jn2pWb27";
    grafana = {
      enableAlloyGateway = true;
      alloyConfigFile = ./alloy/config.alloy;
      alloyExtraVolumes = [
        "${getSecretFile "grafana" "alloy" "ca.crt"}:/etc/alloy/ca.crt:ro"
        "${getSecretFile "grafana" "alloy" "server.crt"}:/etc/alloy/server.crt:ro"
        "${getSecretFile "grafana" "alloy" "server.key"}:/etc/alloy/server.key:ro"
      ];

    };
    kopia = {
      repositoryPath = "/backup/kopia/repositories/main";
      backupPaths = [
        "/data/services"
        "/data/nas"
      ];
    };
    paperless.oidcClientId = "MbfRgCUPQJ5HUybc2X8mB52cYFvyCVNt2hXgHOCV";
  };
}
