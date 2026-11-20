{
  config,
  lib,
  pkgs,
  domain,
  mkTraefikLabels,
  getEnvFiles,
  ...
}:
let
  hostname = config.networking.hostName;
  backendNetwork = "grafana-backend";
  cfg = config.grafana;
  textfileDir = "/var/lib/node-exporter-textfiles";
in
{
  options.grafana = {
    oidcClientId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Grafana OAuth client ID registered in Authentik.";
    };
    enableGrafana = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Grafana container.";
    };
    enablePrometheus = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Prometheus container.";
    };
    enableLoki = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Loki container.";
    };
    enableAlloy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Alloy container.";
    };
    enableAlloyGateway = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to expose Alloy as a public mTLS ingest gateway for remote metrics and logs.";
    };
    alloyConfigFile = lib.mkOption {
      type = lib.types.path;
      default = ./config/config.alloy;
      description = "Path to the Alloy configuration file to mount into the container.";
    };
    alloyExtraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional volume mounts for the Alloy container (e.g. TLS certificate files).";
    };
    enableNodeExporter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable the Prometheus node exporter on the host.";
    };
    enableDirSizeCollector = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run a periodic collector that measures subdirectory sizes and exposes them via the node exporter textfile collector.";
    };
    dirSizeCollectorPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/data/services" ];
      description = "Directories whose immediate subdirectories are measured for size.";
    };
  };

  config = {
    services.prometheus.exporters.node = lib.mkIf cfg.enableNodeExporter {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd"
        "textfile"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
      ];
      extraFlags = lib.mkIf cfg.enableDirSizeCollector [
        "--collector.textfile.directory=${textfileDir}"
      ];
    };

    systemd.services.directory-size-collector = lib.mkIf (cfg.enableNodeExporter && cfg.enableDirSizeCollector) {
      description = "Collect subdirectory sizes for node_exporter textfile collector";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${./collector.sh} ${textfileDir}/directory_sizes.prom ${lib.escapeShellArgs cfg.dirSizeCollectorPaths}";
        StateDirectory = "node-exporter-textfiles";
      };
      path = with pkgs; [
        findutils
        coreutils
      ];
    };

    systemd.timers.directory-size-collector = lib.mkIf (cfg.enableNodeExporter && cfg.enableDirSizeCollector) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "10min";
        Persistent = true;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.enableNodeExporter [ 9100 ];

    myVirtualization.networks.${backendNetwork} = "";
    myVirtualization.networks.monitoring = "";

    myVirtualization.containers.grafana.app = lib.mkIf cfg.enableGrafana {
      rawImageReference = "grafana/grafana:13.3.1@sha256:0615ec4fbd4072004b7d86b46ded63013a74b7d6eb1119273dd89e8fa25c13cf";
      nixSha256 = "sha256-iaK2oXrJTgRKSQb5tVE8nFz7e2SYyvZ4VZDbaolvvR8=";
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
        GF_AUTH_GENERIC_OAUTH_CLIENT_ID = cfg.oidcClientId;
        GF_AUTH_GENERIC_OAUTH_SCOPES = "openid profile email";
        GF_AUTH_GENERIC_OAUTH_AUTH_URL = "https://auth.${domain}/application/o/authorize/";
        GF_AUTH_GENERIC_OAUTH_TOKEN_URL = "https://auth.${domain}/application/o/token/";
        GF_AUTH_GENERIC_OAUTH_API_URL = "https://auth.${domain}/application/o/userinfo/";
        GF_AUTH_SIGNOUT_REDIRECT_URL = "https://auth.${domain}/application/o/grafana/end-session/";
        GF_AUTH_OAUTH_AUTO_LOGIN = "true";
        GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH = "contains(groups[*], 'admins') && 'Admin' || 'Viewer'";
        GF_SERVER_ROOT_URL = "https://grafana.${domain}";
        GF_LOG_LEVEL = "warn";
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

    myVirtualization.containers.grafana.prometheus = lib.mkIf cfg.enablePrometheus {
      rawImageReference = "prom/prometheus:v3.16.0@sha256:e04987641b57704f408e31f6373ba4138ecf27cb4a165d24aabb6c38fddd0f06";
      nixSha256 = "sha256-WyYzvCUezr+AJtVi0Rwt8omeAXZG/R4l5JmjPY9PKtI=";
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
        "--log.level=warn"
      ];
      labels =
        (mkTraefikLabels {
          name = "prometheus";
          port = "9090";
          useInfraForwardAuth = true;
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

    myVirtualization.containers.grafana.loki = lib.mkIf cfg.enableLoki {
      rawImageReference = "grafana/loki:3.7.10@sha256:6d789ab9a603ee4429d0fdc4d11512bf2423e8a8c5fc898a9e5aa2d8471ce459";
      nixSha256 = "sha256-f29HSegktDXteve6D+aENLnpzf9MzDxWIfAZH+yiu10=";
      networks = [ backendNetwork ];
      volumes = [
        "/data/services/grafana/loki:/loki"
        "${./config/loki.yml}:/etc/loki/config.yml:ro"
      ];
      cmd = [ "-config.file=/etc/loki/config.yml" ];
    };

    myVirtualization.containers.grafana.alloy = lib.mkIf cfg.enableAlloy {
      rawImageReference = "grafana/alloy:v1.22.0@sha256:f520f92be9ec37af83df426692d578411f039b0663e0456812c8f39015af8f8f";
      nixSha256 = "sha256-+hhzZOWNvtFKe/kzgsuT9ASdzXcCCMkrBcRzT5DADpU=";
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
        "${cfg.alloyConfigFile}:/etc/alloy/config.alloy:ro"
      ]
      ++ cfg.alloyExtraVolumes;
      cmd = [
        "run"
        "--server.http.listen-addr=0.0.0.0:12345"
        "--storage.path=/var/lib/alloy"
        "/etc/alloy/config.alloy"
        "--disable-reporting"
      ];
      labels =
        (mkTraefikLabels {
          name = "alloy";
          port = "12345";
          useInfraForwardAuth = true;
        })
        // (lib.optionalAttrs cfg.enableAlloyGateway (
          mkTraefikLabels {
            name = "alloy-metrics";
            port = "12346";
            passthrough = true;
          }
          // mkTraefikLabels {
            name = "alloy-logs";
            port = "12347";
            passthrough = true;
          }
        ))
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
