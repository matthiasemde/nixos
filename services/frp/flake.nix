{
  description = "Service flake exporting frp (fast reverse proxy) container config";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      frpPkg = pkgs.frp;

      mkFrpcImage =
        configPath:
        let
          configDerivation = pkgs.runCommand "frp-config" { } ''
            mkdir -p $out/etc/frp
            cp ${configPath} $out/etc/frp/frpc.toml
          '';
        in
        pkgs.dockerTools.buildImage {
          name = "frpc";
          tag = frpPkg.version;
          copyToRoot = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.iputils
            pkgs.curl
            pkgs.bind
            frpPkg
            configDerivation
          ];
          config = {
            Cmd = [
              "${frpPkg}/bin/frpc"
              "-c"
              "/etc/frp/frpc.toml"
            ];
          };
        };
    in
    {
      name = "frp";
      dependencies = {
        networks = {
          "frp-ingress" = "--ipv6";
        };
      };
      containers =
        {
          getContainerEnvFiles,
          serviceArgs ? { },
          ...
        }:
        let
          configPath = (serviceArgs.frp or { }).configPath or ./config/frpc.toml;
          frpcImage = mkFrpcImage configPath;
        in
        {
          frp = {
            image = "frpc:${frpPkg.version}";
            imageFile = frpcImage;
            networks = [
              "frp-ingress"
              "pterodactyl_nw"
            ];
            environmentFiles = getContainerEnvFiles "server";
            labels = {
              # Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
