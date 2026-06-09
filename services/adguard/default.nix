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
  cfg = config.adguard.macvlan;

  adguardRawImageReference = "adguard/adguardhome:v0.107.77@sha256:e6f2b8bcda06064ab055b44933a4f0e983c35558b9cdb8d2e7ab1efcee36d890";
  adguardNixSha256 = "sha256-lUgqJ7ja6EuLJBWrK7XydT/CbtffAVNr1Xw2pjFFe30=";
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
  options.adguard.macvlan = {
    parentInterface = lib.mkOption {
      type = lib.types.str;
      description = "Host network interface to attach the macvlan to.";
    };
    subnet = lib.mkOption {
      type = lib.types.str;
      description = "IPv4 subnet CIDR for the macvlan network.";
    };
    gateway = lib.mkOption {
      type = lib.types.str;
      description = "IPv4 gateway for the macvlan network.";
    };
    ipRange = lib.mkOption {
      type = lib.types.str;
      description = "IPv4 range CIDR allocated to containers on this network.";
    };
    ipv6Subnet = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 subnet CIDR for the macvlan network.";
    };
    ipv6Gateway = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 gateway for the macvlan network.";
    };
    staticIp = lib.mkOption {
      type = lib.types.str;
      description = "Static IPv4 address assigned to the AdGuard container.";
    };
  };

  config = {
    myVirtualization.networks.${networkName} = ''
      -d macvlan \
      --subnet=${cfg.subnet} \
      --gateway=${cfg.gateway} \
      --ip-range=${cfg.ipRange} \
      --ipv6 \
      --subnet=${cfg.ipv6Subnet} \
      --gateway=${cfg.ipv6Gateway} \
      -o parent=${cfg.parentInterface} \
    '';

    myVirtualization.containers.adguard = {
      image = "adguard-derived:v1.0.0";
      imageFile = adguardDerivedImage;
      networks = [ networkName ];
      extraOptions = [ "--ip=${cfg.staticIp}" ];
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
