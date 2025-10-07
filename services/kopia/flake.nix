{
  description = "Kopia Server container for de-duplicated backups";

  outputs =
    { self, nixpkgs }:
    {
      name = "kopia";
      containers =
        {
          hostname,
          getServiceEnvFiles,
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          kopiaRawImageReference = "kopia/kopia:0.21.1@sha256:c594f95b4c0888f51a89339f746db45e141d6b65567814f592955368e575da55";
          kopiaImageReference = parseDockerImageReference kopiaRawImageReference;
          kopiaImage = pkgs.dockerTools.pullImage {
            imageName = kopiaImageReference.name;
            imageDigest = kopiaImageReference.digest;
            finalImageTag = kopiaImageReference.tag;
            sha256 = "sha256-+onyN8iEw9HbZ+ZQ4hYGQyI1kELR96wd8SGMrIOrT1s=";
          };
        in
        {
          kopia = {
            image = kopiaImageReference.name + ":" + kopiaImageReference.tag;
            imageFile = kopiaImage;
            networks = [
              "traefik"
            ];
            ports = [ "51515:51515" ];
            extraOptions = [ "--dns=1.1.1.1" ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              # Mount local folders needed by kopia
              "/data/services/kopia/config/dir:/app/config"
              "/data/services/kopia/certs:/certs"
              # "/data/services/kopia/cache/dir:/app/cache"

              # "/data/services/kopia/logs/dir:/app/logs"
              # Mount local folders to snapshot
              "/data/services:/data:ro"
              # Mount repository location
              "/backup/kopia/repositories/main:/repository"
              # Mount path for browsing mounted snapshots
              "/tmp/kopia-browse:/tmp:shared"
            ];
            environment = {
              "USER" = "User";
            };
            environmentFiles = getServiceEnvFiles "kopia";

            # startup: run the server, binding to all interfaces
            cmd = [
              "server"
              "start"
              # "--tls-generate-cert" # needed only once on first startup
              "--tls-cert-file"
              "/certs/kopia-mahler.cert"
              "--tls-key-file"
              "/certs/kopia-mahler.key"
              "--address"
              "0.0.0.0:51515"
            ];

            labels = {
              "traefik.enable" = "true";
              "traefik.tcp.routers.kopia.rule" = "HostSNI(`kopia.emdecloud.de`)";
              "traefik.tcp.routers.kopia.entrypoints" = "websecure";
              "traefik.tcp.routers.kopia.tls.passthrough" = "true";
              "traefik.tcp.services.kopia.loadbalancer.server.port" = "51515";

              "homepage.group" = "Utilities";
              "homepage.name" = "Kopia Server";
              "homepage.icon" = "kopia";
              "homepage.href" = "https://mahler:51515";
            };
          };
        };
    };
}
