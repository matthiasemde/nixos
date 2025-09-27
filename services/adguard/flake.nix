{
  description = "AdGuard Home container module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      config = pkgs.runCommand "config" { } ''
        mkdir -p $out/opt/adguardhome/conf
        cp -r ${./config}/* $out/opt/adguardhome/conf
      '';

      adguardBase = pkgs.dockerTools.pullImage {
        imageName = "adguard/adguardhome";
        imageDigest = "sha256:320ab49bd5f55091c7da7d1232ed3875f687769d6bb5e55eb891471528e2e18f";
        sha256 = "sha256-St9EOxoipyQZYMX027BSxMbXOFJbZJ5kgiAaVjfZyy4=";
      };

      # Build custom docker image with baked-in config
      adguardDerived = pkgs.dockerTools.buildImage {
        name = "adguard-derived";
        tag = "v1.0.0";
        fromImage = adguardBase;
        copyToRoot = config;
        config = {
          Entrypoint = [ "/opt/adguardhome/AdGuardHome" ];
          Cmd = [
            "--no-check-update"
            "-c"
            "/opt/adguardhome/conf/AdGuardHome.yaml"
            "-w"
            "/opt/adguardhome/work"
          ];
        };
      };
      networkName = "adguard-macvlan";
    in
    {
      name = "adguard";
      dependencies = {
        networks = {
          ${networkName} = ''
            -d macvlan \
            --subnet=192.168.178.0/24 \
            --gateway=192.168.178.1 \
            --ip-range=192.168.178.240/28 \
            --ipv6 \
            --subnet=fdfb:7759:b7ce::/64 \
            --gateway=fdfb:7759:b7ce::2e91:abff:fea2:270e \
            -o parent=enp106s0f3u2 \
          '';
        };
      };
      containers =
        { hostname, ... }:
        {
          adguard = {
            image = "adguard-derived:v1.0.0";
            imageFile = adguardDerived;
            networks = [ "${networkName}" ];
            extraOptions = [ "--ip=192.168.178.240" ];
            labels = {
              # Traefik (disabled)
              "traefik.enable" = "false";

              # Homepage
              "homepage.group" = "Utilities";
              "homepage.name" = "AdGuard";
              "homepage.icon" = "adguard-home";
              "homepage.href" = "http://adguard.${hostname}.local";
              "homepage.description" = "DNS-level ad blocking";
            };
          };
        };
    };
}
