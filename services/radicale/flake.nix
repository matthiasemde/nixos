{
  description = "Radicale service using a custom Docker image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # A tiny derivation that places your config at /etc/radicale/config
      configDerivation = pkgs.runCommand "radicale-config" { } ''
        mkdir -p $out/etc/radicale
        cp ${./config/config} $out/etc/radicale/config
        cp ${./users} $out/etc/radicale/users
      '';

      radicaleImage = pkgs.dockerTools.buildImage {
        name = "radicale";
        tag = "v1.0.0";

        copyToRoot = [
          pkgs.dockerTools.binSh # provides /bin/sh
          pkgs.dockerTools.caCertificates
          pkgs.radicale
          configDerivation
        ];

        config = {
          Cmd = [ "/bin/radicale" ];

          ExposedPorts = {
            "5232/tcp" = { };
          };
        };
      };
    in
    {
      name = "radicale";
      containers =
        { hostname, getServiceEnvFiles, ... }:
        {
          radicale = {
            image = "radicale:v1.0.0";
            imageFile = radicaleImage;
            volumes = [
              "/data/services/radicale/collections:/var/lib/radicale/collections"
            ];
            networks = [
              "traefik"
            ];
            # environmentFiles = getServiceEnvFiles "radicale";
            labels = {
              # 🛡️ Traefik
              "traefik.enable" = "true";
              "traefik.http.routers.radicale.rule" = "HostRegexp(`radicale.*`)";
              "traefik.http.routers.radicale.entrypoints" = "websecure";
              "traefik.http.routers.radicale.tls.certresolver" = "myresolver";
              "traefik.http.routers.radicale.tls.domains[0].main" = "radicale.emdecloud.de";
              "traefik.http.services.radicale.loadbalancer.server.port" = "5232";
            };
          };
        };
    };
}
