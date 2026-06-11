{
  config,
  pkgs,
  domain,
  mkTraefikLabels,
  parseDockerImageReference,
  getEnvFiles,
  getSecretFile,
  ...
}:
let
  hostname = config.networking.hostName;
  backendNetwork = "synapse-backend";
  authBackendNetwork = "matrix-auth-backend";
  matrixRtcNetwork = "matrix-rtc-backend";

  matrixAuthRawImageReference = "ghcr.io/element-hq/matrix-authentication-service:1.16.0@sha256:969d33b20ef4449937ee7bce9e05d159c10d9d1504d9374f2b7d43087bbff924";
  matrixAuthNixSha256 = "sha256-49xzfqgeUelSriFHvrlOJLjpJyGsPXfxHW5i71yegA4=";
  matrixAuthImageReference = parseDockerImageReference matrixAuthRawImageReference;
  matrixAuthImage = pkgs.dockerTools.pullImage {
    imageName = matrixAuthImageReference.name;
    imageDigest = matrixAuthImageReference.digest;
    finalImageTag = matrixAuthImageReference.tag;
    sha256 = matrixAuthNixSha256;
  };

  matrixAuthImageDerived =
    let
      pythonEnv = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);
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

  livekitRawImageReference = "livekit/livekit-server:v1.12.0@sha256:b617bb3363f13e880a82164692d842681276bc6eed7da46092f9ddb22017b927";
  livekitNixSha256 = "sha256-Hw6p1GzIfA2pdiDFlxZdokKVnzsh6rNxLjSz9zJ8JFw=";
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
  myVirtualization.networks.${backendNetwork} = "";
  myVirtualization.networks.${authBackendNetwork} = "";
  myVirtualization.networks.${matrixRtcNetwork} = "";

  myVirtualization.containers.matrix-auth-database = {
    rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
    nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
    environment = {
      "POSTGRES_USER" = "mas_user";
      "POSTGRES_DB" = "mas";
    };
    environmentFiles = getEnvFiles "synapse" "matrix-auth-database";
    volumes = [
      "/data/services/synapse/matrix-auth-database:/var/lib/postgresql/18/docker"
    ];
    networks = [ authBackendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.matrix-auth-app = {
    image = "matix-auth-derived" + ":" + matrixAuthImageReference.tag;
    imageFile = matrixAuthImageDerived;
    environmentFiles = getEnvFiles "synapse" "matrix-auth-app";
    volumes = [
      "${./config/matrix-auth-config.yaml.j2}:/data/config.yaml.j2:ro"
      "${./render-config.py}:/render-config.py:ro"
      "${./matrix-auth-entrypoint.sh}:/entrypoint.sh:ro"
      "${getSecretFile "synapse" "matrix-auth-app" "secrets.yaml"}:/data/secrets.yaml:ro"
    ];
    entrypoint = "/entrypoint.sh";
    networks = [
      "traefik"
      authBackendNetwork
    ];
    labels =
      let
        compatPaths = builtins.concatStringsSep " || " [
          "PathPrefix(`/_matrix/client/v3/login`)"
          "PathPrefix(`/_matrix/client/v3/logout`)"
          "PathPrefix(`/_matrix/client/v3/refresh`)"
        ];
      in
      (mkTraefikLabels {
        name = "matrix-auth";
        port = "8080";
      })
      // {
        "traefik.http.routers.matrix-auth-compat-local.entrypoints" = "web";
        "traefik.http.routers.matrix-auth-compat-local.rule" =
          "Host(`matrix.${hostname}.local`) && (${compatPaths})";
        "traefik.http.routers.matrix-auth-compat-local.service" = "matrix-auth-compat";

        "traefik.http.routers.matrix-auth-compat-public.entrypoints" = "websecure";
        "traefik.http.routers.matrix-auth-compat-public.rule" =
          "Host(`matrix.${domain}`) && (${compatPaths})";
        "traefik.http.routers.matrix-auth-compat-public.tls.certresolver" = "myresolver";
        "traefik.http.routers.matrix-auth-compat-public.tls.domains[0].main" = "matrix.${domain}";
        "traefik.http.routers.matrix-auth-compat-public.service" = "matrix-auth-compat";

        "traefik.http.services.matrix-auth-compat.loadbalancer.server.port" = "8080";
      };
  };

  myVirtualization.containers.synapse-database = {
    rawImageReference = "postgres:18@sha256:073e7c8b84e2197f94c8083634640ab37105effe1bc853ca4d5fbece3219b0e8";
    nixSha256 = "sha256-zH0xxBUum8w4fpGFV6r76jI7ayJuXC8G0qY1Dm26opU=";
    environment = {
      "POSTGRES_USER" = "synapse";
      "POSTGRES_DB" = "synapse";
      "POSTGRES_INITDB_ARGS" = "--encoding=UTF8 --locale=C";
    };
    environmentFiles = getEnvFiles "synapse" "database";
    volumes = [
      "/data/services/synapse/database:/var/lib/postgresql/18/docker"
    ];
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.synapse-redis = {
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

  myVirtualization.containers.synapse-app = {
    rawImageReference = "matrixdotorg/synapse:v1.153.0@sha256:8ba9310909c4f255f942e504d9e5e5d9a7f20e3fa1cdf5aea8acb704b6a15098";
    nixSha256 = "sha256-qL7X70JGLb2bCAoq7e/zFcYuv2p9r3c1CDJAumrfbTk=";
    environment = {
      "SYNAPSE_CONFIG_PATH" = "/data/homeserver.yaml";
    };
    environmentFiles = getEnvFiles "synapse" "app";
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
        "homepage.group" = "Media";
        "homepage.name" = "Matrix Synapse";
        "homepage.icon" = "matrix";
        "homepage.href" = "https://matrix.${domain}";
        "homepage.description" = "Matrix homeserver";
      };
  };

  myVirtualization.containers.synapse-wellknown = {
    rawImageReference = "nginx:1.31.1-alpine@sha256:8b1e78743a03dbb2c95171cc58639fef29abc8816598e27fb910ed2e621e589a";
    nixSha256 = "sha256-1smG0epcEvN6OA/gQF3mxDMmKh8W33LQITKa37WjAP4=";
    networks = [ "traefik" ];
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

  myVirtualization.containers.synapse-admin = {
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
        "homepage.group" = "Utilities";
        "homepage.name" = "Synapse Admin";
        "homepage.icon" = "matrix";
        "homepage.href" = "http://synapse-admin.${hostname}.local";
        "homepage.description" = "Matrix homeserver admin interface";
      };
  };

  myVirtualization.containers.livekit-sfu = {
    image = "livekit-derived:" + livekitImageReference.tag;
    imageFile = livekitImageDerived;
    environmentFiles = getEnvFiles "synapse" "livekit";
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

  myVirtualization.containers.synapse-ntfy = {
    rawImageReference = "binwiederhier/ntfy:v2.24@sha256:f8a9b104313b87cc24ae4f775f39e6328205b57dff6ede3eaf098a91e5d79f59";
    nixSha256 = "sha256-Sq8Ut0W7zCZL8HEfdDDhZ5bqjte7f6JQfuknW+3S1NE=";
    environment = {
      "NTFY_BASE_URL" = "https://ntfy.${domain}";
      "NTFY_BEHIND_PROXY" = "true";
      "NTFY_AUTH_DEFAULT_ACCESS" = "deny-all";
      "NTFY_ENABLE_SIGNUP" = "false";
    };
    networks = [
      "traefik"
      backendNetwork
    ];
    cmd = [ "serve" ];
    labels = mkTraefikLabels {
      name = "ntfy";
      port = "80";
    };
  };

  myVirtualization.containers.element-call-jwt = {
    rawImageReference = "ghcr.io/element-hq/lk-jwt-service:0.4.4@sha256:9c715697c6f7c1f538f2ee41b7b59b04a8d06bf790a7cc8c8517ccac8d28813d";
    nixSha256 = "sha256-ntksAOhWpkuoKrEg+NMN2x7/4+CGVvrLk6T62SfYfzI=";
    environment = {
      "LIVEKIT_JWT_PORT" = "8080";
      "LIVEKIT_URL" = "https://matrix-rtc-sfu.${domain}";
      "LIVEKIT_FULL_ACCESS_HOMESERVERS" = domain;
    };
    environmentFiles = getEnvFiles "synapse" "jwt";
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
}
