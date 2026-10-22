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

  matrixAuthRawImageReference = "ghcr.io/element-hq/matrix-authentication-service:1.27.1@sha256:02712e68c90f3743fedbd5e3343517481b2b4f246a9fd9e2f050dc2553033847";
  matrixAuthNixSha256 = "sha256-+MSG+Wr0C58Nut4TMgACiIucfERfS5PWuOEC3xu6O58=";
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
      name = "matrix-auth-derived";
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

  livekitRawImageReference = "livekit/livekit-server:v1.13.10@sha256:89ca9ce0791e18d6e03bf6e2c49ceb27e1c754eae8bd50c989386c1a5963791a";
  livekitNixSha256 = "sha256-BzDE2IA6e8izhwAxAIzk82R30P0YRdWgGhP1wJRixvg=";
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

  myVirtualization.containers.synapse.matrix-auth-database = {
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
    cmd = [
      "postgres"
      "-c"
      "log_checkpoints=off"
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.synapse.matrix-auth-app = {
    image = "matrix-auth-derived" + ":" + matrixAuthImageReference.tag;
    imageFile = matrixAuthImageDerived;
    environment = {
      "RUST_LOG" = "warn";
    };
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

  myVirtualization.containers.synapse.database = {
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
    cmd = [
      "postgres"
      "-c"
      "log_checkpoints=off"
    ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.synapse.redis = {
    rawImageReference = "redis:8@sha256:f0957bcaa75fd58a9a1847c1f07caf370579196259d69ac07f2e27b5b389b021";
    nixSha256 = "sha256-CXa5elUnGSjjqWhPDs+vlIuLr/7XLcM19zkQPijjUrY=";
    cmd = [
      "redis-server"
      "--loglevel"
      "warning"
    ];
    networks = [ backendNetwork ];
    labels = {
      "traefik.enable" = "false";
    };
  };

  myVirtualization.containers.synapse.app = {
    rawImageReference = "matrixdotorg/synapse:v1.163.0@sha256:e98ab72138d90fa8b8876c6421fe78a9fdb181c0d7cc690ad740e5173e0c65e6";
    nixSha256 = "sha256-jedmW5WTFVeAr7gPt/9xr18UvG3p2ghuLuW1RRjgq5A=";
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
      })
      // {
        "homepage.group" = "Media";
        "homepage.name" = "Matrix Synapse";
        "homepage.icon" = "matrix";
        "homepage.href" = "https://matrix.${domain}";
        "homepage.description" = "Matrix homeserver";
      };
  };

  myVirtualization.containers.synapse.wellknown = {
    rawImageReference = "nginx:1.31.6-alpine@sha256:092a82dc1cb2fa653ee660f24a8f8603f55b4ea9316923f9a0d394e50714ae10";
    nixSha256 = "sha256-lwT+kVdXGLHBpyjxmZBGIMn+xKgO3L9AwS5D5X1VALM=";
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

  myVirtualization.containers.synapse.admin = {
    rawImageReference = "oci.element.io/element-admin:0.1.17@sha256:55dce08800f425d1eeacadb8864eea95acc5a8a0824efef3bae3d84e2eb83d35";
    nixSha256 = "sha256-GIbq7U926cCYI7PVznAyvT71q/e++OD18Cdf3/kI7xM=";
    networks = [
      "traefik"
      backendNetwork
    ];
    environment = {
      "SERVER_NAME" = "emdecloud.de";
    };
    labels =
      (mkTraefikLabels {
        name = "synapse-admin";
        port = "8080";
      })
      // {
        "homepage.group" = "Utilities";
        "homepage.name" = "Synapse Admin";
        "homepage.icon" = "matrix";
        "homepage.href" = "http://synapse-admin.${hostname}.local";
        "homepage.description" = "Matrix homeserver admin interface";
      };
  };

  myVirtualization.containers.synapse.livekit-sfu = {
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

  myVirtualization.containers.synapse.ntfy = {
    rawImageReference = "binwiederhier/ntfy:v2.28@sha256:6ef4b819f722fccdc036af611c4774cfdc2de821ab74fdd48bbf4c9d6f8973da";
    nixSha256 = "sha256-7MsRRdhL5ZqXSjV2YZ9k9NS8R9jEGjurs39tQsrJm4Q=";
    environment = {
      "NTFY_BASE_URL" = "https://ntfy.${domain}";
      "NTFY_BEHIND_PROXY" = "true";
      "NTFY_AUTH_DEFAULT_ACCESS" = "deny-all";
      "NTFY_ENABLE_SIGNUP" = "false";
      "NTFY_LOG_LEVEL" = "warn";
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

  myVirtualization.containers.synapse.element-call-jwt = {
    rawImageReference = "ghcr.io/element-hq/lk-jwt-service:0.9.0@sha256:d210fd778ba38b7e42e6fc64e8a24a7d66ccc3b938fb20d73bd713224af2dfea";
    nixSha256 = "sha256-NyJ2Ut6RB1vgQ1WEeaUfrpPSgOSFrRzvqkC3OdPag+o=";
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
