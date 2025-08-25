{
  description = "Service flake exporting Homepage container config";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      config = pkgs.runCommand "config" { } ''
        mkdir -p $out/app/config
        cp -r ${./config}/* $out/app/config
      '';

      homepageBase = pkgs.dockerTools.pullImage {
        imageName = "ghcr.io/gethomepage/homepage";
        imageDigest = "sha256:4f923bf0e9391b3a8bc5527e539b022e92dcc8a3a13e6ab66122ea9ed030e196";
        sha256 = "sha256-ZvCdVqFQ8dKqunX94SCt8eXwBPcxAp3vpWvMJCsAxEw=";
      };

      # Build custom docker image with baked-in config
      homepageDerived = pkgs.dockerTools.buildImage {
        name = "homepage-derived";
        tag = "v1.0.0";
        fromImage = homepageBase;
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
      name = "homepage";
      containers =
        { hostname, ... }:
        let
          host = "home.${hostname}.local";
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
