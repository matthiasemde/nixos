{
  description = "Navidrome music server container flake";

  outputs =
    { self, nixpkgs }:
    {
      name = "navidrome";
      containers =
        {
          domain,
          mkTraefikLabels,
          getContainerEnvFiles,
          ...
        }:
        {
          navidrome = {
            rawImageReference = "deluan/navidrome:0.61.2@sha256:9fa40b3d8dec43ceb2213d1fa551da3dcfef6ac6d19c2e534efb92527c2bafd2";
            nixSha256 = "sha256-qlKfW5LuDQ1Wdmpt8P/cnN2AnPivuhFq6r4IXQfazGQ=";
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
            environmentFiles = getContainerEnvFiles "navidrome";
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
