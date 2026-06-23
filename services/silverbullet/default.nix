{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.silverbullet.app = {
    rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.9.0@sha256:82e76a800920370d83e2f50c6946d3c420954b0bd417dbb96f7911513fa05620";
    nixSha256 = "sha256-iTd2ZQ8W6KsbCcBPPXg3mKpLhKuceji6ol2P2XOUI2s=";
    networks = [ "traefik" ];
    volumes = [
      "/data/services/silverbullet/space:/space"
    ];
    labels =
      mkTraefikLabels {
        name = "silverbullet";
        port = "3000";
        useForwardAuth = true;
      }
      // {
        "homepage.group" = "Life Management";
        "homepage.name" = "Silverbullet";
        "homepage.icon" = "silverbullet";
        "homepage.href" = "https://silverbullet.${domain}";
        "homepage.description" = "Personal knowledge management";
      };
  };
}
