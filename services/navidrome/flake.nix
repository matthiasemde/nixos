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
          getServiceEnvFiles,
          ...
        }:
        {
          navidrome = {
            rawImageReference = "deluan/navidrome:0.61.1@sha256:1e1660054a856cc09f227d6929252e45a519fdb16004b464dd637f7294ca3ec1";
            nixSha256 = "sha256-qOUfD5hv1An6ncnrriL2Bxtx2sTAiNtyCdcmKsncDGQ=";
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
