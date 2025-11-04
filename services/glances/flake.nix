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

          glancesRawImageReference = "nicolargo/glances:4.4.1@sha256:61ebee509671ff6cda921b057dda9783c53e3e31673a89d988ef2d53572196ab";
          glancesImageReference = parseDockerImageReference glancesRawImageReference;
          glancesImage = pkgs.dockerTools.pullImage {
            imageName = glancesImageReference.name;
            imageDigest = glancesImageReference.digest;
            finalImageTag = glancesImageReference.tag;
            sha256 = "sha256-ruiwNueEVy5615J8HZdEqfZMrbI67XB97QXBo10NMWw=";
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
