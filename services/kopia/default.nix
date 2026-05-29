{
  config,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  hostname = config.networking.hostName;
in
{
  myVirtualization.containers.kopia = {
    rawImageReference = "kopia/kopia:0.23.0@sha256:bd6a449c263465c388339c0637dcd25562e99dcdde286c9d51ade81e138bbf2c";
    nixSha256 = "sha256-JLg3efs2CwM7yU3N2g+4uPJfk16JRCYsXu5VQ+xBOY0=";
    networks = [
      "traefik"
      "monitoring"
    ];
    ports = [ "51515:51515" ];
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/data/services/kopia/server/config/dir:/app/config"
      "/data/services/kopia/server/certs:/certs"
      "/data/services:/data/services:ro"
      "/data/nas:/data/nas:ro"
      "/backup/kopia/repositories/main:/repository"
      "/tmp/kopia-browse:/tmp:shared"
    ];
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
      "--kopiaui-notifications"
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
}
