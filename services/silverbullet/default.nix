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
    rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.10.0@sha256:27b5724cc36798e7de82180ec9898ea9c157c4f15127f279834bca2897b91f37";
    nixSha256 = "sha256-S2mAB+cJWtucMjeGpIyODZU/FacZ4+NtT6VbPKx/leA=";
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
