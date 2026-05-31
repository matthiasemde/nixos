{ lib, ... }:
{
  imports = [
    ../../services/frp
    ../../services/kopia
    ../../services/minio
    ../../services/traefik
    ../../services/uptime-kuma
  ];

  config = {
    frp.configPath = ./frpc.toml;
    kopia = {
      repositoryPath = "/s3/kopia/repositories/remote";
      backupPaths = [ ];
    };
  };
}
