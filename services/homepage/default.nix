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

  homepageRawImageReference = "ghcr.io/gethomepage/homepage:v1.13.2@sha256:a0b71c8e757298d02560186bab9fbe3fc2d375c523a62cc1019177b37e48aa28";
  homepageNixSha256 = "sha256-hMoNS9Lwcg4irFkIfD1MhFo2iAjrCJNk9W2P0/FW6jU=";
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
