{
  config,
  lib,
  pkgs,
  getEnvFiles,
  ...
}:
{
  options.frp.configPath = lib.mkOption {
    type = lib.types.path;
    description = "Path to the FRP configuration file.";
  };

  config = {
    myVirtualization.networks."frp-ingress" = "--ipv6";

    myVirtualization.containers.frp.server = {
      rawImageReference = "snowdreamtech/frpc:0.69.1@sha256:1cf9ae280fa61412351e2e554a7729b692634b1e4d24ff15c93248e9c4cd4259";
      nixSha256 = "sha256-9XNB/BFd15ZZGMQ1Bkc03zefiubGiMJv17m4On80+As=";
      networks = [
        "frp-ingress"
        "pterodactyl_nw"
      ];
      volumes = [
        "${config.frp.configPath}:/etc/frp/frpc.toml"
      ];
      environmentFiles = getEnvFiles "frp" "server";
      cmd = [
        "frpc"
        "-c"
        "/etc/frp/frpc.toml"
      ];
    };
  };
}
