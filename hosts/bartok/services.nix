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
        "${getSecretFile "grafana" "alloy" "ca.crt"}:/run/secrets/alloy/ca.crt:ro"
        "${getSecretFile "grafana" "alloy" "client.crt"}:/run/secrets/alloy/client.crt:ro"
        "${getSecretFile "grafana" "alloy" "client.key"}:/run/secrets/alloy/client.key:ro"
      ];
    };
  };
}
