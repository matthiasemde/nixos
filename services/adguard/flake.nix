{
  description = "AdGuard Home container module";

  outputs =
    { self, nixpkgs }:
    let
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
        { hostname, parseDockerImageReference, ... }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          adguardRawImageReference = "adguard/adguardhome:v0.107.63@sha256:320ab49bd5f55091c7da7d1232ed3875f687769d6bb5e55eb891471528e2e18f";
          adguardImageReference = parseDockerImageReference adguardRawImageReference;
          adguardImage = pkgs.dockerTools.pullImage {
            imageName = adguardImageReference.name;
            imageDigest = adguardImageReference.digest;
            finalImageTag = adguardImageReference.tag;
            sha256 = "sha256-gRPI+RIxQtVErV5kK9nU34Pp29Ymm9CWTnsv133pwTE=";
          };

          # Build custom docker image with baked-in config
          adguardDerivedImage = pkgs.dockerTools.buildImage {
            name = "adguard-derived";
            tag = "v1.0.0";
            fromImage = adguardImage;
            copyToRoot = pkgs.runCommand "config" { } ''
              mkdir -p $out/opt/adguardhome/conf
              cp -r ${./config}/* $out/opt/adguardhome/conf
            '';
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
        in
        {
          adguard = {
            image = "adguard-derived:v1.0.0";
            imageFile = adguardDerivedImage;
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
