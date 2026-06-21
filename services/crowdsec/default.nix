# services/crowdsec/default.nix
{
  domain,
  mkTraefikLabels,
  getEnvFiles,
  getSecretFile,
  ...
}:
{
  myVirtualization.containers.crowdsec-app = {
    rawImageReference = "crowdsecurity/crowdsec:v1.7.8-debian@sha256:c42776d2b36f84e558b185c3287de3246a1938a1b32f0df7b748bdc6c4443f32";
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
