{
  description = "Matrix Synapse service";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "synapse-backend";
      authBackendNetwork = "matrix-auth-backend";
      matrixRtcNetwork = "matrix-rtc-backend";
    in
    {
      name = "synapse";
      dependencies = {
        networks = {
          ${backendNetwork} = "";
          ${authBackendNetwork} = "";
          ${matrixRtcNetwork} = "";
        };
      };
      containers =
        {
          hostname,
          domain,
          mkTraefikLabels,
          getServiceEnvFiles,
          parseDockerImageReference,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          matrixAuthRawImageReference = "ghcr.io/element-hq/matrix-authentication-service:1.14.0@sha256:35721fc3181887568cb051f0a6ccb05cacb5b8b56cfbc1214db05df7f288e5f4";
          matrixAuthNixSha256 = "sha256-+n8wVyhjAj8EpGIHpEF5Di7w5cFAyALBxaCCh0TUF0k=";
          matrixAuthImageReference = parseDockerImageReference matrixAuthRawImageReference;
          matrixAuthImage = pkgs.dockerTools.pullImage {
            imageName = matrixAuthImageReference.name;
            imageDigest = matrixAuthImageReference.digest;
            finalImageTag = matrixAuthImageReference.tag;
            sha256 = matrixAuthNixSha256;
          };

          # Build custom docker image with shell + python + jinja
          matrixAuthImageDerived =
            let
              # Build a Python interpreter with Jinja2 included
              pythonEnv = pkgs.python3.withPackages (ps: [
                ps.jinja2
              ]);
            in
            pkgs.dockerTools.buildImage {
              name = "matix-auth-derived";
              tag = matrixAuthImageReference.tag;
              fromImage = matrixAuthImage;
              copyToRoot = pkgs.buildEnv {
                name = "image-root";
                paths = [
                  pkgs.bash
                  pkgs.coreutils
                  pythonEnv
                ];
              };

              config = {
                Cmd = [ "/bin/bash" ];
              };
            };

          # LiveKit SFU for Element Call MatrixRTC
          livekitRawImageReference = "livekit/livekit-server:v1.10.0@sha256:6ff9c33d21ae1b92b7f5a86bc55890a3e5b8ebe7b8a847349c5ee326e90ac965";
          livekitNixSha256 = "sha256-M9dKsFVWVRlyqIolvVEb79NFvm1N1xxFu3I7YFYaC+s=";
          livekitImageReference = parseDockerImageReference livekitRawImageReference;
          livekitImage = pkgs.dockerTools.pullImage {
            imageName = livekitImageReference.name;
            imageDigest = livekitImageReference.digest;
            finalImageTag = livekitImageReference.tag;
            sha256 = livekitNixSha256;
          };

          livekitImageDerived = pkgs.dockerTools.buildImage {
            name = "livekit-derived";
            tag = livekitImageReference.tag;
            fromImage = livekitImage;
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [
                pkgs.bash
                pkgs.coreutils
                pkgs.curlMinimal
              ];
            };

            config = {
              Cmd = [ "/bin/bash" ];
            };
          };
        in
        {
          # Matrix Authentication Service Database
          matrix-auth-database = {
            rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
            nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
            environment = {
              "POSTGRES_USER" = "mas_user";
              # "POSTGRES_PASSWORD" = "password"; # set via secret-mgmt
              "POSTGRES_DB" = "mas";
            };
            environmentFiles = getServiceEnvFiles "synapse";
            volumes = [
              "/data/services/synapse/matrix-auth-database:/var/lib/postgresql/18/docker"
            ];
            networks = [ authBackendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };

          # Matrix Authentication Service
          matrix-auth-app = {
            image = "matix-auth-derived" + ":" + matrixAuthImageReference.tag;
            imageFile = matrixAuthImageDerived;
            environmentFiles = getServiceEnvFiles "synapse";
            volumes = [
              "${./config/matrix-auth-config.yaml.j2}:/data/config.yaml.j2:ro"
              "${./render-config.py}:/render-config.py:ro"
              "${./matrix-auth-entrypoint.sh}:/entrypoint.sh:ro"
              "/run/agenix/synapse-matrix-auth-secrets.yaml:/data/secrets.yaml:ro"
            ];
            entrypoint = "/entrypoint.sh";
            networks = [
              "traefik"
              authBackendNetwork
            ];
            labels = mkTraefikLabels {
              name = "matrix-auth";
              port = "8080";
            };
          };

          synapse-database = {
            rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
            nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
            environment = {
              "POSTGRES_USER" = "synapse";
              # "POSTGRES_PASSWORD" = "password"; # set via secret-mgmt
              "POSTGRES_DB" = "synapse";
              "POSTGRES_INITDB_ARGS" = "--encoding=UTF8 --locale=C";
            };
            environmentFiles = getServiceEnvFiles "synapse";
            volumes = [
              "/data/services/synapse/database:/var/lib/postgresql/18/docker"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };

          synapse-redis = {
            rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
            nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
            cmd = [
              "--save"
              "60"
              "1"
              "--loglevel"
              "warning"
            ];
            volumes = [
              "/data/services/synapse/redis:/data"
            ];
            networks = [ backendNetwork ];
            labels = {
              "traefik.enable" = "false";
            };
          };

          synapse-app = {
            rawImageReference = "matrixdotorg/synapse:v1.149.1@sha256:dcab93b1183b296b3bc50767813e4a2337a7cb4a9b89a5e6af5fe9b69a43618c";
            nixSha256 = "sha256-v7e/C8p3nMZA0VewovkCWFUx8QnEeXVcV+BsQJOfq5E=";
            environment = {
              "SYNAPSE_CONFIG_PATH" = "/data/homeserver.yaml";
            };
            environmentFiles = getServiceEnvFiles "synapse";
            volumes = [
              "/data/services/synapse/app:/data"
              "${./config/homeserver.yaml.j2}:/data/homeserver.yaml.j2:ro"
              "${./render-config.py}:/render-config.py:ro"
              "${./entrypoint.sh}:/entrypoint.sh:ro"
              "${./config/log.config}:/data/log.config:ro"
            ];
            entrypoint = "/entrypoint.sh";
            networks = [
              "traefik"
              backendNetwork
              authBackendNetwork
              matrixRtcNetwork
              "monitoring"
            ];
            labels =
              (mkTraefikLabels {
                name = "matrix";
                port = "8008";
                allowedPaths = [
                  "/_matrix"
                  "/_synapse/client"
                ];
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Media";
                "homepage.name" = "Matrix Synapse";
                "homepage.icon" = "matrix";
                "homepage.href" = "https://matrix.${domain}";
                "homepage.description" = "Matrix homeserver";
              };
          };

          synapse-wellknown =
            let
              wellknownServerFile = pkgs.writeTextFile {
                name = "matrix-wellknown-server";
                text = "{ \"m.server\": \"matrix.${domain}:443\" }";
              };

              wellknownClientFile = pkgs.writeTextFile {
                name = "matrix-wellknown-client";
                text = builtins.toJSON {
                  "m.homeserver" = {
                    "base_url" = "https://matrix.${domain}";
                  };
                  "org.matrix.msc4143.rtc_foci" = [
                    {
                      "type" = "livekit";
                      "livekit_service_url" = "https://matrix-rtc-jwt.${domain}";
                    }
                  ];
                };
              };
            in
            {
              rawImageReference = "nginx:1.29.6-alpine@sha256:9a4a85e7006ced27ca077d759ffed671b8a094856703b0af15e2c28902800b1d";
              nixSha256 = "sha256-721iRIX2RQ9cID4tHPoLsoeTaDDbjVtR8StdfQuk+A4=";
              networks = [
                "traefik"
              ];
              volumes = [
                "${wellknownServerFile}:/usr/share/nginx/html/.well-known/matrix/server:ro"
                "${wellknownClientFile}:/usr/share/nginx/html/.well-known/matrix/client:ro"
                "${./config/wellknown-nginx.conf}:/etc/nginx/nginx.conf:ro"
              ];
              labels = {
                "traefik.enable" = "true";
                "traefik.http.routers.matrix-wellknown.rule" =
                  "Host(`${domain}`) && (PathPrefix(`/.well-known/matrix/server`) || PathPrefix(`/.well-known/matrix/client`))";
                "traefik.http.routers.matrix-wellknown.entrypoints" = "websecure";
                "traefik.http.routers.matrix-wellknown.tls.certresolver" = "myresolver";
                "traefik.http.routers.matrix-wellknown.tls.domains[0].main" = domain;
                "traefik.http.services.matrix-wellknown.loadbalancer.server.port" = "80";
              };
            };

          synapse-admin = {
            rawImageReference = "ghcr.io/etkecc/synapse-admin:v0.11.1-etke48@sha256:b0d794c33eaa862bfe968ffb02ab82747f1218e5f259568c40cbfff9dc07bf8c";
            nixSha256 = "sha256-5r22gCLJxgSNNasvXcFNc1Jc31oFzsuLcplE+4HuUaQ=";
            volumes = [
              "${./config/synapse-admin-config.json}:/app/config.json:ro"
            ];
            networks = [
              "traefik"
              backendNetwork
            ];
            labels =
              (mkTraefikLabels {
                name = "synapse-admin";
                port = "80";
                isPublic = false;
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Utilities";
                "homepage.name" = "Synapse Admin";
                "homepage.icon" = "matrix";
                "homepage.href" = "http://synapse-admin.${hostname}.local";
                "homepage.description" = "Matrix homeserver admin interface";
              };
          };

          # LiveKit SFU for MatrixRTC backend
          livekit-sfu = {
            image = "livekit-derived:" + livekitImageReference.tag;
            imageFile = livekitImageDerived;
            environmentFiles = getServiceEnvFiles "synapse";
            volumes = [
              "${./config/livekit-config.yaml}:/etc/livekit-pre.yaml:ro"
              "${./livekit-entrypoint.sh}:/entrypoint.sh:ro"
            ];
            entrypoint = "/entrypoint.sh";
            networks = [
              "traefik"
              "frp-ingress"
              matrixRtcNetwork
            ];
            labels = (
              mkTraefikLabels {
                name = "matrix-rtc-sfu";
                port = "7880";
              }
            );
          };

          # Element Call JWT Auth Service for MatrixRTC
          element-call-jwt = {
            rawImageReference = "ghcr.io/element-hq/lk-jwt-service:0.4.1@sha256:6beec945a59b9b8b02161d29884abc2c1e5af9a376c1a2ccabbec3e26b07cf0c";
            nixSha256 = "sha256-A80V4rpvY3+EpoN71Vkrc3Cf5VWsUzwmnivs9XKTLXI=";
            environment = {
              "LIVEKIT_JWT_PORT" = "8080";
              "LIVEKIT_URL" = "https://matrix-rtc-sfu.${domain}";
              # "LIVEKIT_KEY" = ""; # Set via secret-mgmt
              # "LIVEKIT_SECRET" = ""; # Set via secret-mgmt
              "LIVEKIT_FULL_ACCESS_HOMESERVERS" = domain;
            };
            environmentFiles = getServiceEnvFiles "synapse";
            networks = [
              "traefik"
              matrixRtcNetwork
            ];
            labels = (
              mkTraefikLabels {
                name = "matrix-rtc-jwt";
                port = "8080";
                corsAllowPost = true;
              }
            );
          };
        };
    };
}
