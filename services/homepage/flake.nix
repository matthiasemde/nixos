{
  description = "Service flake exporting Homepage container config";

  outputs =
    { self, nixpkgs }:
    {
      name = "homepage";
      containers =
        { hostname, parseDockerImageReference, ... }:
        let
          host = "home.${hostname}.local";
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};

          config = pkgs.runCommand "config" { } ''
            mkdir -p $out/app/config
            cp -r ${./config}/* $out/app/config
          '';

          homepageRawImageReference = "ghcr.io/gethomepage/homepage:v1.3.2@sha256:4f923bf0e9391b3a8bc5527e539b022e92dcc8a3a13e6ab66122ea9ed030e196";
          homepageImageReference = parseDockerImageReference homepageRawImageReference;
          homepageImage = pkgs.dockerTools.pullImage {
            imageName = homepageImageReference.name;
            imageDigest = homepageImageReference.digest;
            finalImageTag = homepageImageReference.tag;
            sha256 = "sha256-otu9RKOTch05PfZVGD4IuA66C6FVusnBRjiZ7S2H4cE=";
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
              "glances"
            ];
            environment = {
              HOMEPAGE_ALLOWED_HOSTS = "*";
            };
            labels = {
              # Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.home.rule" = "HostRegexp(`homepage.*`)";
              "traefik.http.routers.home.entrypoints" = "websecure";
              "traefik.http.routers.home.tls.certresolver" = "myresolver";
              "traefik.http.routers.home.tls.domains[0].main" = "homepage.emdecloud.de";
              "traefik.http.routers.home.middlewares" = "auth";
              "traefik.http.services.home.loadbalancer.server.port" = "3000";
              "traefik.http.middlewares.auth.basicauth.realm" = "Interner Bereich";
              "traefik.http.middlewares.auth.basicauth.users" = "thema:$apr1$/ntvZmAv$0Pc8l1GVJjJsLugI61Co21";
            };
          };
        };
    };
}
