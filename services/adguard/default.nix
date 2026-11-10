{
  config,
  lib,
  pkgs,
  parseDockerImageReference,
  ...
}:
let
  hostname = config.networking.hostName;
  networkName = "adguard-macvlan";
  lanIp = config.adguard.lanIp;

  adguardRawImageReference = "adguard/adguardhome:v0.107.80@sha256:e2e1b48c832f7705be915873f95de0d5114de573736441d7f2923a8a6293027c";
  adguardNixSha256 = "sha256-OrYxiC4vNepJtZjH9ZtuF5dXwArsKKu4eP0yb1/uIJk=";
  adguardImageReference = parseDockerImageReference adguardRawImageReference;
  adguardImage = pkgs.dockerTools.pullImage {
    imageName = adguardImageReference.name;
    imageDigest = adguardImageReference.digest;
    finalImageTag = adguardImageReference.tag;
    sha256 = adguardNixSha256;
  };

  adguardDerivedImage = pkgs.dockerTools.buildImage {
    name = "adguard-derived";
    tag = "v1.0.0";
    fromImage = adguardImage;
    copyToRoot = pkgs.runCommand "config" { } ''
      mkdir -p $out/opt/adguardhome/conf
      cp -r ${./config}/* $out/opt/adguardhome/conf
    '';
    config = {
      Entrypoint = [ "/opt/adguardhome/AdGuardHome" ];
      Cmd = [
        "--no-check-update"
        "-c"
        "/opt/adguardhome/conf/AdGuardHome.yaml"
        "-w"
        "/opt/adguardhome/work"
      ];
    };
  };
in
{
  options.adguard.lanIp = lib.mkOption {
    type = lib.types.str;
    description = "Static IPv4 address assigned to AdGuard on the shared LAN macvlan.";
  };

  config = {
    myVirtualization.containers.adguard.server = {
      image = "adguard-derived:v1.0.0";
      imageFile = adguardDerivedImage;
      networks = [
        networkName
        "home-assistant-backend"
      ];
      extraOptions = [ "--ip=${lanIp}" ];
      labels = {
        "traefik.enable" = "false";
        "homepage.group" = "Utilities";
        "homepage.name" = "AdGuard";
        "homepage.icon" = "adguard-home";
        "homepage.href" = "http://adguard.${hostname}.local";
        "homepage.description" = "DNS-level ad blocking";
      };
    };
  };
}
