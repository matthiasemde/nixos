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
          domain,
          services,
          getServiceEnvFiles,
          ...
        }:
        let
          mkTraefikLabels =
            {
              name,
              port,
              passthrough ? false,
              isPublic ? true,
              allowedPaths ? null,
            }:
            let
              localRule = "Host(`${name}.${hostname}.local`)";

              # Build path rules from allowedPaths array
              pathRules =
                if allowedPaths != null then
                  let
                    pathConditions = map (path: "PathPrefix(`${path}`)") allowedPaths;
                    pathString = lib.concatStringsSep " || " pathConditions;
                  in
                  " && (${pathString})"
                else
                  "";

              publicRule = "Host(`${name}.${domain}`)${pathRules}";
              publicTcpRule = "HostSNI(`${name}.${domain}`)";

              local = {
                # 🛡️ Enable traffic
                "traefik.enable" = "true";
                "traefik.http.services.${name}.loadbalancer.server.port" = port;

                # --- Local HTTP router ---
                "traefik.http.routers.${name}-local.entrypoints" = "web";
                "traefik.http.routers.${name}-local.rule" = localRule;
                "traefik.http.routers.${name}-local.service" = name;
              };

              public =
                if !isPublic then
                  { }
                else if passthrough then
                  {
                    # --- Public HTTPS/TCP router ---
                    "traefik.tcp.routers.${name}-public.entrypoints" = "websecure";
                    "traefik.tcp.routers.${name}-public.rule" = publicTcpRule;
                    "traefik.tcp.routers.${name}-public.tls.passthrough" = "true";
                    "traefik.tcp.routers.${name}-public.service" = name;
                  }
                else
                  {
                    # --- Public HTTPS router ---
                    "traefik.http.routers.${name}-public.entrypoints" = "websecure";
                    "traefik.http.routers.${name}-public.rule" = publicRule;
                    "traefik.http.routers.${name}-public.tls.certresolver" = "myresolver";
                    "traefik.http.routers.${name}-public.tls.domains[0].main" = "${name}.${domain}";
                    "traefik.http.routers.${name}-public.service" = name;

                    "traefik.http.routers.${name}-public-http.rule" = publicRule;
                    "traefik.http.routers.${name}-public-http.middlewares" = "redirect-to-https@docker";
                    "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme" = "https";
                  };
            in
            local // public;

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
                  service.containers {
                    inherit
                      hostname
                      domain
                      mkTraefikLabels
                      getServiceEnvFiles
                      parseDockerImageReference
                      ;
                  }
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
            # Switching to the dummy image can be useful in order to shut down
            # all services, while keeping the docker daemon activated
            # containers = {
            #   dummy.image = "hello-world";
            # };
          };
        };
    };
}
