{
  description = "Generic secret-management flake for NixOS + OCI containers";

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      # -------- Secret Discovery ---------

      # scanDir: list all files in a directory (naming markers for SOPS secrets)
      scanDir = dir: if builtins.pathExists dir then builtins.attrNames (builtins.readDir dir) else [ ];

      # makeSecretEntry: build a sops-nix entry from a secret marker filename.
      # The SOPS YAML key (and Nix attr name) uses the filename as-is (underscores).
      # The runtime path restores underscores to dots so the decrypted file gets
      # a proper extension (e.g. marker "authentik-database.env" ->/run/mysecrets/authentik-database.env).
      makeSecretEntry = fname: {
        name = lib.replaceStrings [ "." ] [ "_" ] fname;
        value = {
          path = "/run/mysecrets/${fname}";
        };
      };

      collectHostSecrets = dir: lib.map makeSecretEntry (scanDir dir);

      collectServiceSecrets = dir: lib.map makeSecretEntry (scanDir dir);

      # -------- Secret Retrieval Helpers ---------

      # getEnvFiles: return resolved /run/secrets paths for env secrets belonging
      # to a specific container or the service-wide "common" env.
      # Naming convention in sops config: <serviceName>/<containerName>/.env
      #                                   <serviceName>/common/.env
      getEnvFiles =
        secrets: serviceName: containerName:
        let
          matching = lib.filterAttrs (
            name: _: builtins.match "^${serviceName}/(common|${containerName})$" name != null
          ) secrets;
        in
        map (name: secrets.${name}.path) (lib.attrNames matching);

      # getSecretFile: return the resolved /run/secrets path for a single named secret
      # belonging to a specific service and container.
      # Naming convention in sops config: <serviceName>/<containerName>/<secretName>
      getSecretFile =
        secrets: serviceName: containerName: secretName:
        secrets."${serviceName}/${containerName}/${secretName}".path;

    in
    {
      # NixOS module: wires up sops.secrets from all discovered secret markers.
      # Host secrets (hosts/<hostname>/secrets/*) and service secrets
      # (services/<svc>/secrets/*) are registered using the filename as the SOPS key
      # (with dots replaced by underscores).
      nixosModules.default =
        {
          pkgs,
          config,
          lib,
          hostname,
          services ? [ ],
          ...
        }:
        let
          hostEntries = collectHostSecrets ../hosts/${hostname}/secrets;
          serviceEntries = lib.concatMap (
            service: collectServiceSecrets ../services/${service.name}/secrets
          ) services;
          secrets = lib.listToAttrs (hostEntries ++ serviceEntries);

          envFile = ../hosts/${hostname}/secrets/env.yaml;
          secretsData = builtins.fromJSON (
            builtins.readFile (
              pkgs.runCommand "yaml-to-json" { } ''
                ${pkgs.yq-go}/bin/yq -o=json ${envFile} > $out
              ''
            )
          );
          flattenSecrets =
            prefix: attrs:
            builtins.foldl' (
              acc: key:
              if key == "sops" then
                acc
              else
                let
                  value = attrs.${key};

                  path = if prefix == "" then key else "${prefix}/${key}";
                in
                acc
                // (
                  if builtins.isAttrs value then
                    flattenSecrets path value
                  else
                    {
                      "${path}" = {
                        key = "${path}";
                        path = "/run/mysecrets/${path}/.env";
                      };
                    }
                )
            ) { } (builtins.attrNames attrs);

          secretsDir = ../hosts/${hostname}/secrets;

          # recursively walk a directory and collect all files
          collectSecretFiles =
            dir:
            let
              entries = builtins.readDir dir;

              names = builtins.attrNames entries;
            in
            builtins.concatLists (
              builtins.map (
                name:
                let
                  path = dir + "/${name}";
                  type = entries.${name};
                in
                if type == "directory" then
                  collectSecretFiles path
                else if type == "regular" then
                  [ path ]
                else
                  [ ]
              ) names
            );

          # determine sops format from extension
          detectFormat =
            path:
            let
              p = toString path;
            in
            if builtins.match ".*\\.ya?ml$" p != null then
              "yaml"
            else if builtins.match ".*\\.json$" p != null then
              "json"
            else
              "binary";

          # convert:
          #   /abs/path/secrets/foo/bar/file.yaml
          # into:
          #   foo/bar/file.yaml
          #
          secretNameFromPath =
            path: builtins.replaceStrings [ "${toString secretsDir}/" ] [ "" ] (toString path);

          secretFiles = collectSecretFiles secretsDir;
        in
        {
          config = {
            sops.defaultSopsFile = envFile;
            sops.age.keyFile = "/nix/persist/var/lib/sops-nix/key.txt";
            sops.secrets =
              flattenSecrets "" secretsData
              // builtins.listToAttrs (
                builtins.map (path: {
                  name = secretNameFromPath path;

                  value = {
                    sopsFile = path;
                    format = detectFormat path;
                    key = "";
                  };
                }) secretFiles
              );
          };
        };

      lib = {
        inherit
          getEnvFiles
          getSecretFile
          ;
      };
    };
}
