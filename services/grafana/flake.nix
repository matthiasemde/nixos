{
  description = "Grafana + Prometheus monitoring stack service flake";

  outputs =
    { self, nixpkgs }:
    let
      backendNetwork = "grafana-backend";
    in
    {
      name = "grafana";
      dependencies = {
        networks = {
          ${backendNetwork} = ""; # network for communcation between grafana and prometheus
          "monitoring" = ""; # network for all services which expose a prometheus endpoint
        };
      };
      containers =
        {
          hostname,
          domain,
          mkTraefikLabels,
          getServiceEnvFiles,
          ...
        }:
        {
          grafana = {
            rawImageReference = "grafana/grafana:12.4.0@sha256:b0ae311af06228bcfd4a620504b653db80f5b91e94dc3dc2a5b7dab202bcde20";
            nixSha256 = "sha256-x4EeDN8c9STjxrWmpvkj/qli1Au3FeIMPcznafcx/tg=";
            networks = [
              backendNetwork
              "traefik"
            ];
            environmentFiles = getServiceEnvFiles "grafana";
            volumes = [
              "/data/services/grafana/grafana:/var/lib/grafana"
              "${./config/datasources.yml}:/etc/grafana/provisioning/datasources/datasources.yml:ro"
            ];
            environment = {
              GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION = "true"; # login via authentik

              # SMTP configuration for notifications
              GF_SMTP_ENABLED = "true";
              GF_SMTP_HOST = "mail.privateemail.com:465";
              # GF_SMTP_USER = ""; # set via secret-mgmt
              # GF_SMTP_PASSWORD = ""; # set via secret-mgmtr
              GF_SMTP_FROM_ADDRESS = "no-reply@emdecloud.de";
              GF_SMTP_FROM_NAME = "Grafana";

              # Authentik config
              GF_AUTH_GENERIC_OAUTH_ENABLED = "true";
              GF_AUTH_GENERIC_OAUTH_NAME = "authentik";
              GF_AUTH_GENERIC_OAUTH_CLIENT_ID = "E0ryu0936Q62OLtR4W1DHdPjz87RtJp3Jn2pWb27";
              # GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = "<Client Secret>"; # set via secret-mgmt
              GF_AUTH_GENERIC_OAUTH_SCOPES = "openid profile email";
              GF_AUTH_GENERIC_OAUTH_AUTH_URL = "https://auth.${domain}/application/o/authorize/";
              GF_AUTH_GENERIC_OAUTH_TOKEN_URL = "https://auth.${domain}/application/o/token/";
              GF_AUTH_GENERIC_OAUTH_API_URL = "https://auth.${domain}/application/o/userinfo/";
              GF_AUTH_SIGNOUT_REDIRECT_URL = "https://auth.${domain}/application/o/grafana/end-session/";
              # Optionally enable auto-login (bypasses Grafana login screen)
              GF_AUTH_OAUTH_AUTO_LOGIN = "true";
              # Optionally map user groups to Grafana roles
              GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH = "contains(groups[*], 'admins') && 'Admin' || 'Viewer'";
              # Required if Grafana is running behind a reverse proxy
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

          prometheus = {
            rawImageReference = "prom/prometheus:v3.10.0@sha256:4a61322ac1103a0e3aea2a61ef1718422a48fa046441f299d71e660a3bc71ae9";
            nixSha256 = "sha256-F9kVULQ+94epS9mCQHsSncmPf4jSn9QogkyxyTeOpho=";
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
              "--storage.tsdb.retention.time=30d"
              "--web.enable-lifecycle"
              "--web.enable-admin-api"
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
              };
          };

          cadvisor = {
            rawImageReference = "gcr.io/cadvisor/cadvisor:v0.52.1@sha256:f40e65878e25c2e78ea037f73a449527a0fb994e303dc3e34cb6b187b4b91435";
            nixSha256 = "sha256-LrD875RTiMyqAvaeDg+czmCQMcdlMuQEnfdCVnnDypU=";
            volumes = [
              "/:/rootfs:ro"
              "/var/run:/var/run:ro"
              "/sys:/sys:ro"
              "/var/lib/docker/:/var/lib/docker:ro"
              "/dev/disk/:/dev/disk:ro"
            ];
            networks = [
              backendNetwork
            ];
            cmd = [
              "-enable_metrics=cpu,memory,oom_event,disk,diskIO,network"
              "-store_container_labels=false"
            ];
          };
        };
    };
}
