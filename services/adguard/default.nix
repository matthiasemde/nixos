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

  adguardRawImageReference = "adguard/adguardhome:v1.0.0@sha256:f00a586f0d1caa74f149340bfb225014960310488ffa838406b89256900a96c2";
  adguardNixSha256 = "sha256-TRUmniIkMMtx5Rn4WyEP+kyUKluHMHuixfaatRd+heM=";
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
