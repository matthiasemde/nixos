{
  config,
  pkgs,
  mkTraefikLabels,
  parseDockerImageReference,
  ...
}:
let
  inherit parseDockerImageReference mkTraefikLabels;

  homepageConfig = pkgs.runCommand "config" { } ''
    mkdir -p $out/app/config
    cp -r ${./config}/* $out/app/config
  '';

  homepageRawImageReference = "ghcr.io/gethomepage/homepage:v1.13.0@sha256:690ac1f79e33000c176c2a28229ed00b49b44781e8a63f280a8ece22c161f099";
  homepageNixSha256 = "sha256-0xmZWGL7poxstnnZqYg0BTWWr2bi2C2v27VQVfaOTOA=";
  homepageImageReference = parseDockerImageReference homepageRawImageReference;
  homepageImage = pkgs.dockerTools.pullImage {
    imageName = homepageImageReference.name;
    imageDigest = homepageImageReference.digest;
    finalImageTag = homepageImageReference.tag;
    sha256 = homepageNixSha256;
  };

  homepageDerived = pkgs.dockerTools.buildImage {
    name = "homepage-derived";
    tag = "v1.0.0";
    fromImage = homepageImage;
    copyToRoot = homepageConfig;
    config = {
      WorkingDir = "/app";
      Entrypoint = [ "docker-entrypoint.sh" ];
      Cmd = [
        "node"
        "server.js"
      ];
    };
  };
in
{
  myVirtualization.containers.homepage = {
    image = "homepage-derived:v1.0.0";
    imageFile = homepageDerived;
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
      "/data:/data"
    ];
    networks = [ "traefik" ];
    environment = {
      HOMEPAGE_ALLOWED_HOSTS = "*";
    };
    labels = mkTraefikLabels {
      name = "homepage";
      port = "3000";
      useForwardAuth = true;
    };
  };
}
