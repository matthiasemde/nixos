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

  homepageRawImageReference = "ghcr.io/gethomepage/homepage:v2.2.0@sha256:753eeb0cc22ab7baad39ed47cbd1aae14e193dd1b264e965f193a9ea1d1e1bdd";
  homepageNixSha256 = "sha256-uLuUJGprXPBrYq7W3SW/ODCOYtOmmpc1Cq5QHvxZLBg=";
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
  myVirtualization.containers.homepage.app = {
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
