{
  config,
  lib,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  hostname = config.networking.hostName;

  backupVolumes = map (path: "${path}:${path}:ro") config.kopia.backupPaths;
in
{
  options.kopia = {
    repositoryPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to the Kopia repository on the host.";
    };
    backupPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of paths on the host to be backed up by Kopia.";
    };
  };

  config = {
    myVirtualization.containers.kopia.server = {
      rawImageReference = "kopia/kopia:0.23.1@sha256:89fd95ee2942880ca00eae964266958a394421ddbdf69bca62e38afc55f5900e";
      nixSha256 = "sha256-QNp3FVxElewSLUJGszYHAWwWLoZM/L/u2MvvUR0Y+lg=";
      networks = [
        "traefik"
        "monitoring"
      ];
      ports = [ "51515:51515" ];
      ##########################
      ### The SYS_ADMIN capabilities are only required for
      ### mounting backups into the local file system.
      # capabilities = {
      #   SYS_ADMIN = true;
      # };
      # devices = [ "/dev/fuse:/dev/fuse" ];
      ##########################
      volumes = [
        "/etc/localtime:/etc/localtime:ro"

        # Mount local folders needed by kopia
        "/data/services/kopia/server/config/dir:/app/config"
        "/data/services/kopia/server/certs:/certs"

        # Mount repository location
        "${config.kopia.repositoryPath}:/repository"

        # Mount path for browsing mounted snapshots
        "/tmp/kopia-browse:/tmp:shared"

        # Mount script for remote backups
        "${./do-remote-backup.sh}:/app/do-remote-backup.sh:ro"
      ]
      ++ backupVolumes;
      environment = {
        "USER" = "User";
      };
      environmentFiles = getEnvFiles "kopia" "server";
      cmd = [
        "server"
        "start"
        # "--tls-generate-cert" # needed only once on first startup
        "--tls-cert-file"
        "/certs/kopia-${hostname}.cert"
        "--tls-key-file"
        "/certs/kopia-${hostname}.key"
        "--address"
        "0.0.0.0:51515"
        "--metrics-listen-addr"
        "0.0.0.0:9091"
      ];
      labels =
        (mkTraefikLabels {
          name = "kopia";
          port = "51515";
          passthrough = true;
        })
        // {
          "homepage.group" = "Utilities";
          "homepage.name" = "Kopia Server";
          "homepage.icon" = "kopia";
          "homepage.href" = "https://kopia.${hostname}.local";
          "homepage.description" = "Deduplicating backup service";
          "alloy.metrics.enabled" = "true";
          "alloy.metrics.port" = "9091";
        };
    };
  };
}
