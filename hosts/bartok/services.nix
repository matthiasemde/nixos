{ lib, ... }:
{
  imports = [
    ../../services/frp
    ../../services/minio
    ../../services/traefik
    ../../services/uptime-kuma
  ];

  config = {
    frp.configPath = ./frpc.toml;
  };
}
