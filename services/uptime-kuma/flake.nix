{
  description = "Uptime Kuma service flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "uptime-kuma";
      dependencies = {
        networks = {
          "monitoring" = "";
        };
      };
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

          uptimeKumaRawImageReference = "louislam/uptime-kuma:2.0.1@sha256:60e6fe0c481b452633cef1a47c1096633b36e6871c5cd97ec61039de1706e1f3";
          uptimeKumaImageReference = parseDockerImageReference uptimeKumaRawImageReference;
          uptimeKumaImage = pkgs.dockerTools.pullImage {
            imageName = uptimeKumaImageReference.name;
            imageDigest = uptimeKumaImageReference.digest;
            finalImageTag = uptimeKumaImageReference.tag;
            sha256 = "sha256-dYsslnHT5AqQ9YkRPRFvl+yv1RUYerhpVdLZDZYOIIA=";
          };
        in
        {
          uptime-kuma = {
            image = uptimeKumaImageReference.name + ":" + uptimeKumaImageReference.tag;
            imageFile = uptimeKumaImage;
            networks = [
              "traefik"
            ];
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
