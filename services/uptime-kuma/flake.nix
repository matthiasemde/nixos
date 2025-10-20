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

          uptimeKumaRawImageReference = "louislam/uptime-kuma:2.0.0@sha256:e63226107e874e5a2e168268e0ab9a5e6438a0ca82c61c834c5e03816b07b8d8";
          uptimeKumaImageReference = parseDockerImageReference uptimeKumaRawImageReference;
          uptimeKumaImage = pkgs.dockerTools.pullImage {
            imageName = uptimeKumaImageReference.name;
            imageDigest = uptimeKumaImageReference.digest;
            finalImageTag = uptimeKumaImageReference.tag;
            sha256 = "sha256-VtBXr2LadekIi15bSABIf6bNrdYgi/gwNRdndTjAU3M=";
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
