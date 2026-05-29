{
  pkgs,
  config,
  lib,
  ...
}:
let
  hostname = config.networking.hostName;

  getEnvFiles =
    serviceName: containerName:
    let
      matching = lib.filterAttrs (
        name: _: builtins.match "^${serviceName}/(common|${containerName})$" name != null
      ) config.sops.secrets;
    in
    map (name: config.sops.secrets.${name}.path) (lib.attrNames matching);

  getSecretFile =
    serviceName: containerName: secretName:
    config.sops.secrets."${serviceName}/${containerName}/${secretName}".path;

  scanDir = dir: if builtins.pathExists dir then builtins.attrNames (builtins.readDir dir) else [ ];

  makeSecretEntry = fname: {
    name = lib.replaceStrings [ "." ] [ "_" ] fname;
    value = {
      path = "/run/mysecrets/${fname}";
    };
  };

  collectHostSecrets = dir: lib.map makeSecretEntry (scanDir dir);
  collectServiceSecrets = dir: lib.map makeSecretEntry (scanDir dir);

  # Scan all service directories automatically instead of requiring an explicit list.
  serviceNames =
    if builtins.pathExists ../services then builtins.attrNames (builtins.readDir ../services) else [ ];

  hostEntries = collectHostSecrets ../hosts/${hostname}/secrets;
  serviceEntries = lib.concatLists (
    map (name: collectServiceSecrets ../services/${name}/secrets) serviceNames
  );
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

  secretNameFromPath =
    path: builtins.replaceStrings [ "${toString secretsDir}/" ] [ "" ] (toString path);

  secretFiles = if builtins.pathExists secretsDir then collectSecretFiles secretsDir else [ ];
in
{
  config = {
    _module.args = { inherit getEnvFiles getSecretFile; };

    sops.defaultSopsFile = if builtins.pathExists envFile then envFile else "";
    sops.age.keyFile = "/nix/persist/var/lib/sops-nix/key.txt";
    sops.secrets =
      (if builtins.pathExists envFile then flattenSecrets "" secretsData else { })
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
}
