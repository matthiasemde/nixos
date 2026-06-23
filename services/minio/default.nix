{
  domain,
  mkTraefikLabels,
  getEnvFiles,
  getSecretFile,
  ...
}:
{
  myVirtualization.containers.minio.server = {
    rawImageReference = "quay.io/minio/aistor/minio:RELEASE.2026-05-28T20-50-32Z@sha256:f43826478f78ce99e6def967e67a185b2958c8d5a3ef1b65fe89eed25e602348";
    nixSha256 = "sha256-ovgwlzTJVv24JSbTLDqjpO96mxD5TszfpmRVdGncNeQ=";
    environmentFiles = getEnvFiles "minio" "server-env";
    environment = {
      # "MINIO_ROOT_USER" =
      # "MINIO_ROOT_PASSWORD" =
    };
    volumes = [
      "/s3/data:/data"
      "${getSecretFile "minio" "server" "license"}:/minio.license:ro"
    ];
    networks = [ "traefik" ];
    cmd = [
      "minio"
      "server"
      "/data"
      "--license"
      "/minio.license"
    ];
    labels =
      (mkTraefikLabels {
        name = "minio";
        port = "9000";
      })
      // (mkTraefikLabels {
        name = "minio-console";
        port = "9001";
      });
  };
}
