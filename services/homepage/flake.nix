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

          homepageRawImageReference = "ghcr.io/gethomepage/homepage:v1.10.1@sha256:0b596092c0b55fe4c65379a428a3fe90bd192f10d1b07d189a34fe5fabe7eedb";
          homepageNixSha256 = "sha256-f2vJ6WPGf9Gk4XDjH5tMdvWvHhT2D2HZKWanUJQloRE=";
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
