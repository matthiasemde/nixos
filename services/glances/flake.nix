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

          glancesRawImageReference = "nicolargo/glances:4.4.0@sha256:f7439475dc86cf23446035002871f6a643c88b729cb39717e2c97926ecae8da1";
          glancesImageReference = parseDockerImageReference glancesRawImageReference;
          glancesImage = pkgs.dockerTools.pullImage {
            imageName = glancesImageReference.name;
            imageDigest = glancesImageReference.digest;
            finalImageTag = glancesImageReference.tag;
            sha256 = "sha256-ACodrWvEJ9dfcyygCqw0NCr49IJt82v9nbomxBT5Eyo=";
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
