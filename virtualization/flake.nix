{
  description = "Generic virtualization flake: a reusable NixOS module";

  outputs =
    { self, nixpkgs }:
    {
      nixosModules.default =
        {
          config,
          pkgs,
          lib,
          hostname,
          services,
          getServiceEnvFiles,
          ...
        }:
        let
          # Parses a docker image string like:
          # "ghcr.io/gethomepage/homepage:v1.3.2@sha256:4f923b..."
          # into { name, tag, digest }
          parseDockerImageReference =
            imageStr:
            let
              # split by "@"
              partsAt = lib.splitString "@" imageStr;
              beforeAt = builtins.elemAt partsAt 0;
              digest = builtins.elemAt partsAt 1;

              # split by ":"
              partsColon = lib.splitString ":" beforeAt;
              name = builtins.elemAt partsColon 0;
              tag = builtins.elemAt partsColon 1;
            in
            {
              name = name;
              tag = tag;
              digest = digest;
            };

          mergedContainers = lib.foldl' (
            acc: service:
            let
              maybeContainers =
                if lib.hasAttr "containers" service && builtins.isFunction service.containers then
                  service.containers { inherit hostname getServiceEnvFiles parseDockerImageReference; }
                else
                  { };
            in
            acc // maybeContainers
          ) { } services;

          mergedDependencies = lib.foldl' (
            acc: service:
            let
              deps = service.dependencies or { };
            in
            {
              files = (acc.files or { }) // (deps.files or { });
              networks = (acc.networks or { }) // (deps.networks or { });
            }
          ) { } services;

          # Build a list of file-creation attributes
          fileScripts = lib.mapAttrsToList (file: permissions: {
            name = "create-${lib.escapeShellArg file}-file";
            value = ''
              # Ensure the parent directory exists
              mkdir -p ${dirOf file}
              touch ${file}
              chmod ${permissions} ${file}
            '';
          }) mergedDependencies.files;

          # Build a list of Docker-network-creation attributes
          networkScripts = lib.mapAttrsToList (networkName: opts: {
            name = "create-${networkName}-network";
            value = ''
              # Create Docker network if not exists
              ${pkgs.docker}/bin/docker network inspect ${networkName} >/dev/null 2>&1 || \
              ${pkgs.docker}/bin/docker network create ${opts} ${networkName}
            '';
          }) mergedDependencies.networks;
        in
        {
          # Register activation scripts for file and networks
          system.activationScripts = lib.listToAttrs (fileScripts ++ networkScripts);

          # Declare all containers under oci-containers
          virtualisation.oci-containers = {
            backend = "docker";
            containers = mergedContainers;
          };
        };
    };
}
