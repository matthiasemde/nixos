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

  homepageRawImageReference = "ghcr.io/gethomepage/homepage:v2.0.0@sha256:638dacf5c844e908dc06c1fd57a2b5694f8efd91f91f152829ea0c2f547458f2";
  homepageNixSha256 = "sha256-AR3wbPKFRzEY9cg3rFgQeNzZyCBsjsZ/l0xzZdMrMDs=";
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
