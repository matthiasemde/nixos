{ lib, getSecretFile, ... }:
{
  imports = [
    ../../services/authentik
    ../../services/frp
    ../../services/grafana
    ../../services/minio
    ../../services/traefik
    ../../services/uptime-kuma
  ];

  config = {
    myInfrastructure.useCrowdsec = false;

    authentik = {
      enableStack = false;
    };

    frp.configPath = ./frpc.toml;

    grafana = {
      enableGrafana = false;
      enablePrometheus = false;
      enableLoki = false;
      alloyConfigFile = ./alloy/config.alloy;
      alloyExtraVolumes = [
        "${getSecretFile "grafana" "alloy" "ca.crt"}:/etc/alloy/ca.crt:ro"
        "${getSecretFile "grafana" "alloy" "client.crt"}:/etc/alloy/client.crt:ro"
        "${getSecretFile "grafana" "alloy" "client.key"}:/etc/alloy/client.key:ro"
      ];
    };
  };
}
