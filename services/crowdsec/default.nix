# services/crowdsec/default.nix
{
  domain,
  mkTraefikLabels,
  getEnvFiles,
  getSecretFile,
  ...
}:
{
  myVirtualization.containers.crowdsec.server = {
    rawImageReference = "crowdsecurity/crowdsec:v1.8.2-debian@sha256:828cece4ae73204d5c266bc3937543b58c8c9a4f8c908a8294a1f9b90b9c9e91";
    nixSha256 = "sha256-dX1BwDlJ9SkEuu7bDGnRaCge9i4ou+65mO3JeQcq+Hc=";
    networks = [ "traefik" ];
    environmentFiles = getEnvFiles "crowdsec" "app";
    volumes = [
      "/data/services/crowdsec/config:/etc/crowdsec"
      "${./config.yaml}:/etc/crowdsec/config/config.yaml"
      "/data/services/crowdsec/database:/var/lib/crowdsec/data"
      "${./appsec.yaml}:/etc/crowdsec/acquis.d/appsec.yaml:ro"
    ];
    environment = {
      "COLLECTIONS" = "crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules";
    };
    labels = {
        "alloy.metrics.enabled" = "true";
        "alloy.metrics.port" = "6060";
      };
  };
}
