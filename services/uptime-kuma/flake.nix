{
  description = "Uptime Kuma service flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "uptime-kuma";
      containers =
        {
          hostname,
          domain,
          parseDockerImageReference,
          mkTraefikLabels,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          uptimeKumaRawImageReference = "louislam/uptime-kuma:2.0.2@sha256:4c364ef96aaddac7ec4c85f5e5f31c3394d35f631381ccbbf93f18fd26ac7cba";
          uptimeKumaImageReference = parseDockerImageReference uptimeKumaRawImageReference;
          uptimeKumaImage = pkgs.dockerTools.pullImage {
            imageName = uptimeKumaImageReference.name;
            imageDigest = uptimeKumaImageReference.digest;
            finalImageTag = uptimeKumaImageReference.tag;
            sha256 = "sha256-Q9mJ8U5AZ/TTtY9SfP9Ro7ogcfSXsUDaKQ6+Vp8J9A8=";
          };
        in
        {
          uptime-kuma = {
            image = uptimeKumaImageReference.name + ":" + uptimeKumaImageReference.tag;
            imageFile = uptimeKumaImage;
            networks = [
              "traefik"
            ];
            extraOptions = [ "--dns=1.1.1.1" ];
            volumes = [
              "/data/services/uptime-kuma:/app/data"
            ];
            environment = {
              UPTIME_KUMA_PORT = "3001";
            };
            labels =
              (mkTraefikLabels {
                name = "status";
                port = "3001";
              })
              // {
                "homepage.group" = "Monitoring";
                "homepage.name" = "Uptime Kuma";
                "homepage.icon" = "uptime-kuma";
                "homepage.href" = "https://status.${domain}";
                "homepage.description" = "Uptime monitoring and status page";
              };
          };
        };
    };
}
