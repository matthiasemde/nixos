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

          uptimeKumaRawImageReference = "louislam/uptime-kuma:1.23.16@sha256:b4c3a4d186b4612b3a7bbb39c56a634626276615c21871c837a86e4a43d8e047";
          uptimeKumaImageReference = parseDockerImageReference uptimeKumaRawImageReference;
          uptimeKumaImage = pkgs.dockerTools.pullImage {
            imageName = uptimeKumaImageReference.name;
            imageDigest = uptimeKumaImageReference.digest;
            finalImageTag = uptimeKumaImageReference.tag;
            sha256 = "sha256-iRN4zpu20EZMK9q2ojsPmG5MCOyum7+Sb6kJVn5wO48=";
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
