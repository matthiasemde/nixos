{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.silverbullet = {
    rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.9.0@sha256:82e76a800920370d83e2f50c6946d3c420954b0bd417dbb96f7911513fa05620";
    nixSha256 = "sha256-63Cevrh6Q/Z7Jgek32w5XVSYb5f4f2iuo9SD4jOHvKA=";
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
