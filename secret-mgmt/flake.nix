{
  description = "Generic secret-management flake for NixOS + OCI containers";

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      # -------- Secret Discovery ---------

      # scanDir: list .age files in a directory (naming markers for SOPS secrets)
      scanDir =
        dir:
        if builtins.pathExists dir then
          lib.filter (fname: lib.hasSuffix ".age" fname) (builtins.attrNames (builtins.readDir dir))
        else
          [ ];

      # sanitizeKey: replace dots with underscores for a valid SOPS YAML key
      sanitizeKey = name: lib.replaceStrings [ "." ] [ "_" ] name;

      # makeHostSecretEntry: build a sops-nix entry for a host-level .age marker.
      # Host secret files are named WITHOUT a hostname prefix (e.g. WEBHOOK_SECRET.env.age).
      # The YAML key and runtime path both get the hostname prepended.
      makeHostSecretEntry =
        hostname: fname:
        let
          baseName = lib.removeSuffix ".age" fname;
          secretName = "${hostname}-${baseName}";
        in
        {
          name = sanitizeKey secretName;
          value = {
            path = "/run/secrets/${secretName}";
          };
        };

      # makeServiceSecretEntry: build a sops-nix entry for a service-level .age marker.
      # Service secret files ALREADY encode service+container in their name:
      #   <service>-<container|common>-<name>.<ext>.age
      # The YAML key and runtime path are derived directly from the filename.
      makeServiceSecretEntry =
        fname:
        let
          baseName = lib.removeSuffix ".age" fname;
        in
        {
          name = sanitizeKey baseName;
          value = {
            path = "/run/secrets/${baseName}";
          };
        };

      collectHostSecrets =
        hostname: dir: lib.map (fname: makeHostSecretEntry hostname fname) (scanDir dir);

      collectServiceSecrets = dir: lib.map (fname: makeServiceSecretEntry fname) (scanDir dir);

      # -------- Secret Retrieval Helpers ---------

      # getContainerEnvFiles: return /run/secrets paths for .env secrets belonging to
      # a specific container (and the service-wide "common" secrets).
      # Naming convention for .age marker files:
      #   <serviceName>-<containerName>-<name>.env.age   (container-specific)
      #   <serviceName>-common-<name>.env.age            (shared across containers)
      getContainerEnvFiles =
        serviceName: containerName:
        let
          dir = ../services/${serviceName}/secrets;
          allFiles = scanDir dir;
          containerPrefix = "${serviceName}-${containerName}-";
          commonPrefix = "${serviceName}-common-";
          relevant = lib.filter (
            fname: (lib.hasPrefix containerPrefix fname) || (lib.hasPrefix commonPrefix fname)
          ) allFiles;
          envFiles = lib.filter (fname: lib.hasSuffix ".env.age" fname) relevant;
        in
        lib.map (fname: "/run/secrets/${lib.removeSuffix ".age" fname}") envFiles;

      # getContainerFiles: return Docker volume mount strings for non-env file secrets
      # belonging to a specific container (and the service-wide "common" secrets).
      # Each secret at /run/secrets/<name> on the host is mounted at the same path
      # inside the container, producing strings like "/run/secrets/<name>:/run/secrets/<name>:ro".
      # Naming convention for .age marker files:
      #   <serviceName>-<containerName>-<name>.<ext>.age   (non-.env, container-specific)
      #   <serviceName>-common-<name>.<ext>.age            (non-.env, shared across containers)
      getContainerFilePaths =
        serviceName: containerName:
        let
          dir = ../services/${serviceName}/secrets;
          allFiles = scanDir dir;
          containerPrefix = "${serviceName}-${containerName}-";
          commonPrefix = "${serviceName}-common-";
          relevant = lib.filter (
            fname: (lib.hasPrefix containerPrefix fname) || (lib.hasPrefix commonPrefix fname)
          ) allFiles;
          nonEnvFiles = lib.filter (fname: !(lib.hasSuffix ".env.age" fname)) relevant;
        in
        lib.map (fname: "/run/secrets/${lib.removeSuffix ".age" fname}") nonEnvFiles;

      getContainerFiles =
        serviceName: containerName:
        map (p: "${p}:${p}:ro") (getContainerFilePaths serviceName containerName);

      # getContainerSecrets: return /run/secrets paths for ALL secrets (env + files)
      # belonging to a specific container and the service-wide "common" secrets.
      # Returns paths (not volume strings) for use in NixOS modules (e.g. samba password).
      getContainerSecrets =
        serviceName: containerName:
        (getContainerEnvFiles serviceName containerName)
        ++ (getContainerFilePaths serviceName containerName);
    in
    {
      # NixOS module: wires up sops.secrets from all discovered .age markers.
      # Host secrets (hosts/<hostname>/secrets/*.age) are registered with the hostname
      # prepended. Service secrets (services/<svc>/secrets/*.age) use the filename as-is,
      # since the naming convention already encodes <service>-<container>-<name>.
      nixosModules.default =
        {
          config,
          lib,
          hostname,
          services ? [ ],
          ...
        }:
        let
          hostEntries = collectHostSecrets hostname ../hosts/${hostname}/secrets;
          serviceEntries = lib.concatMap (
            service: collectServiceSecrets ../services/${service.name}/secrets
          ) services;
          secrets = lib.listToAttrs (hostEntries ++ serviceEntries);
        in
        {
          config = {
            sops.defaultSopsFile = ../hosts/${hostname}/secrets.yaml;
            sops.age.keyFile = "/nix/persist/var/lib/sops-nix/key.txt";
            sops.secrets = secrets;
          };
        };

      lib = {
        inherit getContainerEnvFiles getContainerFiles getContainerSecrets;
      };
    };
}
