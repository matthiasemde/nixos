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
    rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.12.1@sha256:370a3bf2daa37b7dbba62183085c57d5d43862189ea127e0765646d230561d9d";
    nixSha256 = "sha256-uNvugV8/wn670qLVyI2XtyEYBA9MOL4JBQ2t9OW2c+w=";
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
