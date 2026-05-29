{
  config,
  pkgs,
  getEnvFiles,
  ...
}:
let
  frpPkg = pkgs.frp;
  configDerivation = pkgs.runCommand "frp-config" { } ''
    mkdir -p $out/etc/frp
    cp ${./config/frpc.toml} $out/etc/frp/frpc.toml
  '';
  frpcImage = pkgs.dockerTools.buildImage {
    name = "frpc";
    tag = frpPkg.version;
    copyToRoot = [
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.iputils
      pkgs.curl
      pkgs.bind
      frpPkg
      configDerivation
    ];
    config = {
      Cmd = [
        "${frpPkg}/bin/frpc"
        "-c"
        "/etc/frp/frpc.toml"
      ];
    };
  };
in
{
  myVirtualization.networks."frp-ingress" = "--ipv6";

  myVirtualization.containers.frp = {
    image = "frpc:${frpPkg.version}";
    imageFile = frpcImage;
    networks = [
      "frp-ingress"
      "pterodactyl_nw"
    ];
    environmentFiles = getEnvFiles "frp" "server";
    labels = {
      "traefik.enable" = "false";
    };
  };
}
