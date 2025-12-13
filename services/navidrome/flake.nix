{
  description = "Navidrome music server container flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "navidrome";
      dependencies = {
        systemServices = {
          music-sync = builtins.readFile ./music-sync.sh;
        };
      };
      containers =
        {
          domain,
          mkTraefikLabels,
          getServiceEnvFiles,
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          navidromeRawImageReference = "deluan/navidrome:0.58.0@sha256:7bad89fbf2a0a311989b932090cd0d87fc239b03b5d16b1cbad975a79b275271";
          navidromeImageReference = parseDockerImageReference navidromeRawImageReference;
          navidromeImage = pkgs.dockerTools.pullImage {
            imageName = navidromeImageReference.name;
            imageDigest = navidromeImageReference.digest;
            finalImageTag = navidromeImageReference.tag;
            sha256 = "sha256-gqHFoDTkXsy6glM8kizYdd/OTKnNWrKSXYG7o93JR34=";
          };
        in
        {
          navidrome = {
            image = navidromeImageReference.name + ":" + navidromeImageReference.tag;
            imageFile = navidromeImage;
            environment = {
              ND_SCANSCHEDULE = "1h";
              ND_LOGLEVEL = "info";
              ND_SESSIONTIMEOUT = "24h";
              ND_BASEURL = "";
              ND_REVERSEPROXYWHITELIST = "0.0.0.0/0, ::/0";
              ND_REVERSEPROXYUSERHEADER = "X-authentik-username";
              ND_ENABLEEXTERNALSERVICES = "false";
              ND_ENABLEUSEREDITING = "false";
              ND_ENABLEINSIGHTSCOLLECTOR = "false";
            };
            environmentFiles = getServiceEnvFiles "navidrome";
            volumes = [
              "/data/services/navidrome/data:/data"
              "/data/nas/navidrome/shared-library:/music/shared:ro"
              "/data/nas/files/Musik:/music/local:ro"
              "/data/nas/home/Theresa/Musik:/music/theresa:ro"
              "/data/nas/home/Matthias/Music:/music/matthias:ro"
            ];
            networks = [ "traefik" ];
            labels =
              (mkTraefikLabels {
                name = "navidrome";
                port = "4533";
                useForwardAuth = true;
              })
              // {
                "traefik.http.routers.navidrome-rest.entrypoints" = "websecure";
                "traefik.http.routers.navidrome-rest.rule" = "Host(`navidrome.${domain}`) && PathPrefix(`/rest/`)";
                "traefik.http.routers.navidrome-rest.tls.certresolver" = "myresolver";
                "traefik.http.routers.navidrome-rest.tls.domains[0].main" = "navidrome.${domain}";
                "traefik.http.routers.navidrome-rest.service" = "navidrome";

                # 🏠 Homepage integration
                "homepage.group" = "Media";
                "homepage.name" = "Navidrome";
                "homepage.icon" = "navidrome";
                "homepage.href" = "https://navidrome.${domain}";
                "homepage.description" = "Music streaming server";
              };
          };
        };
    };
}
