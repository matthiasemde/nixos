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

          synapseRawImageReference = "matrixdotorg/synapse:v1.143.0@sha256:b4475c0a7fd55e4430b779adcaef534684a805906e3c15b4bc79054841b24733";
          synapseImageReference = parseDockerImageReference synapseRawImageReference;
          synapseImage = pkgs.dockerTools.pullImage {
            imageName = synapseImageReference.name;
            imageDigest = synapseImageReference.digest;
            finalImageTag = synapseImageReference.tag;
            sha256 = "sha256-iNQ2ucimIEmwQcjl0aBiejsp7Qph1frvWZpcgp91HD0=";
          };

          postgresRawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
          postgresImageReference = parseDockerImageReference postgresRawImageReference;
          postgresImage = pkgs.dockerTools.pullImage {
            imageName = postgresImageReference.name;
            imageDigest = postgresImageReference.digest;
            finalImageTag = postgresImageReference.tag;
            sha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
          };

          redisRawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
          redisImageReference = parseDockerImageReference redisRawImageReference;
          redisImage = pkgs.dockerTools.pullImage {
            imageName = redisImageReference.name;
            imageDigest = redisImageReference.digest;
            finalImageTag = redisImageReference.tag;
            sha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
          };

          matrixAuthRawImageReference = "ghcr.io/element-hq/matrix-authentication-service:1.6.0@sha256:15fdb4665aa339261d4352c058c221470d040a04cd59117c3956994d9e8edc27";
          matrixAuthImageReference = parseDockerImageReference matrixAuthRawImageReference;
          matrixAuthImage = pkgs.dockerTools.pullImage {
            imageName = matrixAuthImageReference.name;
            imageDigest = matrixAuthImageReference.digest;
            finalImageTag = matrixAuthImageReference.tag;
            sha256 = "sha256-sbpxFT+pY7T6FQdcT+QoHCTJU4K82fDwRp82Z2k8ZN8=";
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

          synapseAdminRawImageReference = "ghcr.io/etkecc/synapse-admin:v0.11.1-etke48@sha256:b0d794c33eaa862bfe968ffb02ab82747f1218e5f259568c40cbfff9dc07bf8c";
          synapseAdminImageReference = parseDockerImageReference synapseAdminRawImageReference;
          synapseAdminImage = pkgs.dockerTools.pullImage {
            imageName = synapseAdminImageReference.name;
            imageDigest = synapseAdminImageReference.digest;
            finalImageTag = synapseAdminImageReference.tag;
            sha256 = "sha256-5r22gCLJxgSNNasvXcFNc1Jc31oFzsuLcplE+4HuUaQ=";
          };

          nginxRawImageReference = "nginx:1.29.3-alpine@sha256:b23ea6c10814fccb32ac20485c74168ebefa1c3544a3dddfcb33494d24270df8";
          nginxImageReference = parseDockerImageReference nginxRawImageReference;
          nginxImage = pkgs.dockerTools.pullImage {
            imageName = nginxImageReference.name;
            imageDigest = nginxImageReference.digest;
            finalImageTag = nginxImageReference.tag;
            sha256 = "sha256-qrQIBp2EbKw3Aicu424rbu26v2T1LZgHVQ+hJKKZQxE=";
          };

          # LiveKit SFU for Element Call MatrixRTC
          livekitRawImageReference = "livekit/livekit-server:v1.9.4@sha256:b672d1dd8280ba2501c473803538503707ef72e7559fab53276f7729824593ac";
          livekitImageReference = parseDockerImageReference livekitRawImageReference;
          livekitImage = pkgs.dockerTools.pullImage {
            imageName = livekitImageReference.name;
            imageDigest = livekitImageReference.digest;
            finalImageTag = livekitImageReference.tag;
            sha256 = "sha256-BKjqLhUwdfiAgInojE0iy60Ra8FaHlGBHMNY37LgR94=";
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

          # Element Call JWT Service for MatrixRTC auth
          elementCallJwtRawImageReference = "ghcr.io/element-hq/lk-jwt-service:0.3.0@sha256:52357326970d3f3e3cf6e9c33766e49cf2665e2cd57842e29a5c298514bd2e58";
          elementCallJwtImageReference = parseDockerImageReference elementCallJwtRawImageReference;
          elementCallJwtImage = pkgs.dockerTools.pullImage {
            imageName = elementCallJwtImageReference.name;
            imageDigest = elementCallJwtImageReference.digest;
            finalImageTag = elementCallJwtImageReference.tag;
            sha256 = "sha256-7ebWodUNDJqZlen9vAW6kOJH2Zsz3eQ53hQpfn7c8iw=";
          };
        in
        {
          # Matrix Authentication Service Database
          matrix-auth-database = {
            image = postgresImageReference.name + ":" + postgresImageReference.tag;
            imageFile = postgresImage;
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
            labels =
              (mkTraefikLabels {
                name = "matrix-auth";
                port = "8080";
              })
              // {
                # 🏠 Homepage integration
                "homepage.group" = "Communication";
                "homepage.name" = "Matrix Auth Service";
                "homepage.icon" = "matrix";
                "homepage.href" = "https://matrix-auth.${domain}";
                "homepage.description" = "Matrix Authentication Service";
              };
          };

          synapse-database = {
            image = postgresImageReference.name + ":" + postgresImageReference.tag;
            imageFile = postgresImage;
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
            image = redisImageReference.name + ":" + redisImageReference.tag;
            imageFile = redisImage;
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
            image = synapseImageReference.name + ":" + synapseImageReference.tag;
            imageFile = synapseImage;
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
              image = nginxImageReference.name + ":" + nginxImageReference.tag;
              imageFile = nginxImage;
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
            image = synapseAdminImageReference.name + ":" + synapseAdminImageReference.tag;
            imageFile = synapseAdminImage;
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
                "homepage.group" = "Media";
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
            image = elementCallJwtImageReference.name + ":" + elementCallJwtImageReference.tag;
            imageFile = elementCallJwtImage;
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
