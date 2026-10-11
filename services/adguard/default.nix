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

  adguardRawImageReference = "adguard/adguardhome:v0.107.79@sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0";
  adguardNixSha256 = "sha256-oejSWUMQTIUzcmUhaBjhhOPXzB/L6JogCpUFd+Zo5bs=";
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
      networks = [ networkName ];
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
