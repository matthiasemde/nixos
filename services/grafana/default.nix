{
  config,
  lib,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  hostname = config.networking.hostName;
  backendNetwork = "grafana-backend";
in
{
  options.grafana.oidcClientId = lib.mkOption {
    type = lib.types.str;
    description = "Grafana OAuth client ID registered in Authentik.";
  };

  config = {
    myVirtualization.networks.${backendNetwork} = "";
    myVirtualization.networks.monitoring = "";

    myVirtualization.containers.grafana = {
      rawImageReference = "grafana/grafana:13.0.1@sha256:0f86bada30d65ef9d0183b90c1e2682ac92d53d95da8bed322b984ea78a4a73a";
      nixSha256 = "sha256-N5vSEYmVvEpeBK0h6bAU+A2nf9xQO4OuiH5pGPxYt/g=";
      networks = [
        backendNetwork
        "traefik"
      ];
      environmentFiles = getEnvFiles "grafana" "grafana";
      volumes = [
        "/data/services/grafana/grafana:/var/lib/grafana"
        "${./config/datasources.yml}:/etc/grafana/provisioning/datasources/datasources.yml:ro"
      ];
      environment = {
        GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION = "true";
        GF_SMTP_ENABLED = "true";
        GF_SMTP_HOST = "${config.myInfrastructure.smtp.host}:${toString config.myInfrastructure.smtp.port}";
        GF_SMTP_FROM_ADDRESS = config.myInfrastructure.smtp.fromAddress;
        GF_SMTP_FROM_NAME = "Grafana";
        GF_AUTH_GENERIC_OAUTH_ENABLED = "true";
        GF_AUTH_GENERIC_OAUTH_NAME = "authentik";
        GF_AUTH_GENERIC_OAUTH_CLIENT_ID = config.grafana.oidcClientId;
        GF_AUTH_GENERIC_OAUTH_SCOPES = "openid profile email";
        GF_AUTH_GENERIC_OAUTH_AUTH_URL = "https://auth.${domain}/application/o/authorize/";
        GF_AUTH_GENERIC_OAUTH_TOKEN_URL = "https://auth.${domain}/application/o/token/";
        GF_AUTH_GENERIC_OAUTH_API_URL = "https://auth.${domain}/application/o/userinfo/";
        GF_AUTH_SIGNOUT_REDIRECT_URL = "https://auth.${domain}/application/o/grafana/end-session/";
        GF_AUTH_OAUTH_AUTO_LOGIN = "true";
        GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH = "contains(groups[*], 'admins') && 'Admin' || 'Viewer'";
        GF_SERVER_ROOT_URL = "https://grafana.${domain}";
      };
      labels =
        (mkTraefikLabels {
          name = "grafana";
          port = "3000";
        })
        // {
          "homepage.group" = "Monitoring";
          "homepage.name" = "Grafana";
          "homepage.icon" = "grafana";
          "homepage.href" = "https://grafana.${domain}";
          "homepage.description" = "Metrics visualization and dashboards";
        };
    };

    myVirtualization.containers.prometheus = {
      rawImageReference = "prom/prometheus:v3.12.0@sha256:69f5241418838263316593f7274a304b095c40bcf22e57272865da91bd60a8ac";
      nixSha256 = "sha256-9edEaCOOgv1d5HtXQIlu3IxhAOiiwud4g8ytlEqsGwE=";
      networks = [
        backendNetwork
        "monitoring"
        "traefik"
      ];
      volumes = [
        "/data/services/grafana/prometheus:/prometheus"
        "${./config/prometheus.yml}:/etc/prometheus/prometheus.yml:ro"
      ];
      cmd = [
        "--config.file=/etc/prometheus/prometheus.yml"
        "--storage.tsdb.path=/prometheus"
        "--web.console.libraries=/etc/prometheus/console_libraries"
        "--web.console.templates=/etc/prometheus/consoles"
        "--storage.tsdb.retention.time=14d"
        "--web.enable-lifecycle"
        "--web.enable-admin-api"
        "--web.enable-remote-write-receiver"
        "--web.listen-address=0.0.0.0:9090"
      ];
      labels =
        (mkTraefikLabels {
          name = "prometheus";
          port = "9090";
          isPublic = false;
        })
        // {
          "homepage.group" = "Monitoring";
          "homepage.name" = "Prometheus";
          "homepage.icon" = "prometheus";
          "homepage.href" = "http://prometheus.${hostname}.local";
          "homepage.description" = "Metrics collection and storage";
          "alloy.metrics.enabled" = "true";
          "alloy.metrics.port" = "9090";
        };
    };

    myVirtualization.containers.loki = {
      rawImageReference = "grafana/loki:3.7.2@sha256:800ec439ed2692b79c5a1fe17a6d2955f8999ad5d05f0276c6e4a10ac11cc491";
      nixSha256 = "sha256-Vp6LlgV8NjQh9EwL4EXC/bAv6mrdjD2AbEXvv+X+Xrc=";
      networks = [ backendNetwork ];
      volumes = [
        "/data/services/grafana/loki:/loki"
        "${./config/loki.yml}:/etc/loki/config.yml:ro"
      ];
      cmd = [ "-config.file=/etc/loki/config.yml" ];
      labels =
        (mkTraefikLabels {
          name = "loki";
          port = "3100";
          isPublic = false;
        })
        // {
          "homepage.group" = "Monitoring";
          "homepage.name" = "Loki";
          "homepage.icon" = "loki";
          "homepage.href" = "http://loki.${hostname}.local";
          "homepage.description" = "Log aggregation and storage";
        };
    };

    myVirtualization.containers.alloy = {
      rawImageReference = "grafana/alloy:v1.16.10@sha256:41e0ad9b7c74cdc0a01ca8ce10f8d8262d49029167fd0b1d2db84a0f10468284";
      nixSha256 = "sha256-granJTLCZ/7M39cMUxhSJcQYffK1c59KBrvVUn1wrxY=";
      networks = [
        backendNetwork
        "monitoring"
        "traefik"
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/var/log/journal:/var/log/journal:ro"
        "/:/rootsfs:ro"
        "/var/run:/var/run:rw"
        "/sys:/sys:ro"
        "/var/lib/docker/:/var/lib/docker:ro"
        "/dev/disk/:/dev/disk:ro"
        "/etc/machine-id:/etc/machine-id:ro"
        "${./config/config.alloy}:/etc/alloy/config.alloy:ro"
      ];
      cmd = [
        "run"
        "--server.http.listen-addr=0.0.0.0:12345"
        "--storage.path=/var/lib/alloy"
        "/etc/alloy/config.alloy"
      ];
      labels =
        (mkTraefikLabels {
          name = "alloy";
          port = "12345";
          isPublic = false;
        })
        // {
          "homepage.group" = "Monitoring";
          "homepage.name" = "Alloy";
          "homepage.icon" = "alloy";
          "homepage.href" = "http://alloy.${hostname}.local";
          "homepage.description" = "Metrics and logs forwarding and processing";
          "alloy.metrics.enabled" = "true";
          "alloy.metrics.port" = "12345";
        };
    };
  };
}
