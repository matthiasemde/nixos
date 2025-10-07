{
  description = "Service flake exporting frp (fast reverse proxy) container config";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      frpPkg = pkgs.frp;
      configDerivation = pkgs.runCommand "frp-config" { } ''
        mkdir -p $out/etc/frp
        cp ${./config/frpc.toml} $out/etc/frp/frpc.toml
      '';
      frpcImage = pkgs.dockerTools.buildImage {
        name = "frpc";
        tag = frpPkg.version;
        copyToRoot = [
          pkgs.bashInteractive # bash with useful builtins
          pkgs.coreutils # ls, cat, cp, etc.
          pkgs.iputils # ping
          pkgs.curl # curl
          pkgs.bind # dig + nslookup
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
          "frp-ingress" = "";
        };
      };
      containers =
        { getServiceEnvFiles, ... }:
        {
          frp = {
            image = "frpc:${frpPkg.version}";
            imageFile = frpcImage;
            networks = [
              "frp-ingress"
              "pterodactyl_nw"
            ];
            extraOptions = [ "--dns=1.1.1.1" ];
            environmentFiles = getServiceEnvFiles "frp";
            labels = {
              # Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
