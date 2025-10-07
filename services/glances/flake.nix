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

          glancesRawImageReference = "nicolargo/glances:4.3.1@sha256:e31fafa1c18da2279fdedcc360c0a397e76c1414bb933342aa42df57068e7e56";
          glancesImageReference = parseDockerImageReference glancesRawImageReference;
          glancesImage = pkgs.dockerTools.pullImage {
            imageName = glancesImageReference.name;
            imageDigest = glancesImageReference.digest;
            finalImageTag = glancesImageReference.tag;
            sha256 = "sha256-g9ox6L5md0wKhwolMilbJ7Ss5VgGd6JgLs0kNBEl9NU=";
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
