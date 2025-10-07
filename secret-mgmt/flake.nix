{
  description = "Generic secret-management flake for NixOS + OCI containers";

  inputs.agenix.url = "github:ryantm/agenix";

  outputs =
    {
      self,
      nixpkgs,
      agenix,
    }:
    let
      lib = nixpkgs.lib;

      # -------- Secret Storage ---------

      # scanDir: list .age files in a directory
      scanDir =
        dir:
        if builtins.pathExists dir then
          lib.filter (fname: lib.hasSuffix ".age" fname) (builtins.attrNames (builtins.readDir dir))
        else
          [ ];

      # makeSecretEntry: build an agenix secret entry for a given file
      makeSecretEntry =
        dir: fname:
        let
          baseName = lib.removeSuffix ".age" fname;
          baseDir = baseNameOf (dirOf (toString dir));
        in
        {
          name = "${baseDir}-${baseName}";
          value = {
            file = "${dir}/${fname}";
          };
        };

      # collectDirSecrets: collect entries for one directory
      collectDirSecrets =
        dir:
        let
          files = scanDir dir;
          entries = lib.map (fname: makeSecretEntry dir fname) files;
        in
        entries;

      # collectSecrets: scan multiple dirs and merge into attrset
      collectSecrets =
        dirs:
        let
          allEntries = lib.concatMap (dir: collectDirSecrets dir) dirs;
        in
        lib.listToAttrs allEntries;

      # -------- Secret Retrieval ---------

      #getServiceSecrets: return all files under /run/agenix for a service
      getServiceSecrets =
        serviceName:
        let
          ageFiles = scanDir ../services/${serviceName}/secrets;
          secretNames = lib.map (fname: lib.removeSuffix ".age" fname) ageFiles;
        in
        lib.map (fname: "/run/agenix/${serviceName}-${fname}") secretNames;

      getServiceEnvFiles =
        serviceName:
        let
          ageFiles = scanDir ../services/${serviceName}/secrets;
          secretNames = lib.map (fname: lib.removeSuffix ".age" fname) ageFiles;
          environmentSecrets = lib.filter (fname: lib.hasSuffix ".env" fname) secretNames;
        in
        lib.map (fname: "/run/agenix/${serviceName}-${fname}") environmentSecrets;
    in
    {
      # NixOS module wiring up collectSecrets
      nixosModules.default =
        {
          config,
          pkgs,
          lib,
          hostname,
          services ? [ ],
          ...
        }:
        let
          dirs = lib.foldl' (acc: service: acc ++ [ ../services/${service.name}/secrets ]) [
            ../hosts/${hostname}/secrets
          ] services;
          secrets = collectSecrets dirs;
        in
        {
          config = {
            age.secrets = secrets;
          };
        };

      # Export helper function
      lib = {
        getServiceEnvFiles = getServiceEnvFiles;
        getServiceSecrets = getServiceSecrets;
      };
    };
}
