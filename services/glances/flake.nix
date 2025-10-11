{
  description = "Glances service flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "glances";
      dependencies = {
        networks = {
          "glances" = "";
        };
      };
      containers =
        { parseDockerImageReference, ... }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          glancesRawImageReference = "nicolargo/glances:4.3.3@sha256:fae2cee5c9497b46a72e52261b2e825fe6c0e5de2f295829411e3d5ccf24ee5c";
          glancesImageReference = parseDockerImageReference glancesRawImageReference;
          glancesImage = pkgs.dockerTools.pullImage {
            imageName = glancesImageReference.name;
            imageDigest = glancesImageReference.digest;
            finalImageTag = glancesImageReference.tag;
            sha256 = "sha256-EN7P6BVjAEtZBIuasAJ2GsuQ+7Ci9gTW+/CpUfok3Qo=";
          };
        in
        {
          glances = {
            image = glancesImageReference.name + ":" + glancesImageReference.tag;
            imageFile = glancesImage;
            networks = [ "glances" ];
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/etc/os-release:/etc/os-release:ro"
            ];
            environment = {
              GLANCES_OPT = "-w";
            };
            labels = {
              # Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
