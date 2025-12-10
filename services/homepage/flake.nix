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

          homepageRawImageReference = "ghcr.io/gethomepage/homepage:v1.8.0@sha256:7dc099d5c6ec7fc945d858218565925b01ff8a60bcbfda990fc680a8b5cd0b6e";
          homepageImageReference = parseDockerImageReference homepageRawImageReference;
          homepageImage = pkgs.dockerTools.pullImage {
            imageName = homepageImageReference.name;
            imageDigest = homepageImageReference.digest;
            finalImageTag = homepageImageReference.tag;
            sha256 = "sha256-S1c4oN+VH5GNrl44TchRRe6VhETUuvFp36XjJV8JbDs=";
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
            labels =
              (mkTraefikLabels {
                name = "homepage";
                port = "3000";
              })
              // {
                "traefik.http.routers.homepage-public.middlewares" = "auth";
                "traefik.http.middlewares.auth.basicauth.realm" = "Interner Bereich";
                "traefik.http.middlewares.auth.basicauth.users" = "thema:$apr1$/ntvZmAv$0Pc8l1GVJjJsLugI61Co21";
              };
          };
        };
    };
}
