{
  description = "Service flake exporting Homepage container config";

  outputs =
    { self, nixpkgs }:
    {
      name = "homepage";
      containers =
        {
          hostname,
          parseDockerImageReference,
          domain,
          mkTraefikLabels,
          ...
        }:
        let
          host = "home.${hostname}.local";
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};

          config = pkgs.runCommand "config" { } ''
            mkdir -p $out/app/config
            cp -r ${./config}/* $out/app/config
          '';

          homepageRawImageReference = "ghcr.io/gethomepage/homepage:v1.12.1@sha256:9627769818fbfb14147d3e633e57cef9c27c0c5f07585f5a1d6c3d3425b3b33c";
          homepageNixSha256 = "sha256-DOYfZjoKvmsWkQSFGFroI63uAK9s6HQv0lO5UogmZ0Q=";
          homepageImageReference = parseDockerImageReference homepageRawImageReference;
          homepageImage = pkgs.dockerTools.pullImage {
            imageName = homepageImageReference.name;
            imageDigest = homepageImageReference.digest;
            finalImageTag = homepageImageReference.tag;
            sha256 = homepageNixSha256;
          };

          # Build custom docker image with baked-in config
          homepageDerived = pkgs.dockerTools.buildImage {
            name = "homepage-derived";
            tag = "v1.0.0";
            fromImage = homepageImage;
            copyToRoot = config;
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
          homepage = {
            image = "homepage-derived:v1.0.0";
            imageFile = homepageDerived;
            volumes = [
              "/etc/logs/homepage:/app/config/logs"
              "/var/run/docker.sock:/var/run/docker.sock"
              "/data:/data"
            ];
            networks = [
              "traefik"
            ];
            environment = {
              HOMEPAGE_ALLOWED_HOSTS = "*";
            };
            labels = mkTraefikLabels {
              name = "homepage";
              port = "3000";
              useForwardAuth = true;
            };
          };
        };
    };
}
