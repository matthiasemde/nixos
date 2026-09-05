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
    rawImageReference = "crowdsecurity/crowdsec:v1.8.1-debian@sha256:a5575ae76abd47635b4d2b292ff0412717172bf3a95cc3cbe21f807fb934620a";
    nixSha256 = "sha256-+t3WxunMsCgeCUlB47fjh9zkeyz9oJzz8Nw3baRHx44=";
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
