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

  homepageRawImageReference = "ghcr.io/gethomepage/homepage:v2.3.0@sha256:f820276654539cdc2cf0169f28188d135919a7984fad76d83d8d5ff1383f3705";
  homepageNixSha256 = "sha256-BlXr7k97Hehh67lHwWcKrzgrcHvAuF7mwWBoxuzK1gI=";
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
