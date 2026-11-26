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

  matrixAuthRawImageReference = "ghcr.io/element-hq/matrix-authentication-service:1.30.0@sha256:9252ed4ae66a172864c73550eedb1e805ad52586cf1949d8172b9e6f0db44918";
  matrixAuthNixSha256 = "sha256-balnpzkZnvNIvZ+2C3LMeRWhdCc6cdUQzQWR1jtDT0s=";
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

  livekitRawImageReference = "livekit/livekit-server:v1.13.11@sha256:25cd902de7cacbd5f1f779f6a6ac1eae20ba8f56b0935934ce6b0ab80d1e3d20";
  livekitNixSha256 = "sha256-aNPRQURh43inSl9UXg64au2CSCgv7SymGKVaWDs1y5c=";
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
    rawImageReference = "matrixdotorg/synapse:v1.165.0@sha256:673b4223c81a7634fd07d832b939a58f97081cfdaae7cdd2d1664cdcf7611b62";
    nixSha256 = "sha256-0Po4DykH3p+HFb0LWxRlLF6tJN8yQBif5ggNiHHl+B4=";
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
    rawImageReference = "nginx:1.31.7-alpine@sha256:892bb2152464f0c5d8972593a5f5afaf8054552580b699d95f8ff4af08c2d33d";
    nixSha256 = "sha256-Xd7q8/xe2gQ/a6wTY5pwsn7dNz5xLbg+9/M8H/vh8QY=";
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
    rawImageReference = "oci.element.io/element-admin:0.1.20@sha256:65a3b877d9bae585f6c7174788fab3ce68b979cb395e35f06a331b89fab076f1";
    nixSha256 = "sha256-j13aFZSLPsKS1FnNk+ygM3R9uqjloXg2GreUpqC75vs=";
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
    rawImageReference = "binwiederhier/ntfy:v2.38@sha256:038da2be5e668fee6d36a62884eea48975e1b71c29a56964e5298c1b9165a573";
    nixSha256 = "sha256-a664hAtXwNzHtPjli2BdvwJE/VGMbJGJ9y9iLprmHz0=";
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
    rawImageReference = "ghcr.io/element-hq/lk-jwt-service:0.10.0@sha256:caea79d24fa442e74527cab3bc6fa82979d2aea56b9a79c0b18c57d66a182996";
    nixSha256 = "sha256-Qq8K7Yqu+ptZzBD4W69izPHs89cG5YFhT94HPD152Is=";
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
