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
    rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.12.0@sha256:1b97ce0f7b5085c76e0e9363c88ed97673db62a3b0f78c7bb12868827fff8b37";
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
