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
    rawImageReference = "ghcr.io/silverbulletmd/silverbullet:3.0.1@sha256:c6604f0daef79a842bbee366abb843f88723c4b0504549078da56778a9d854b4";
    nixSha256 = "sha256-tyXauQ8i+/DkcUer4zfCNQ1gDo1phFpOFH4JKE5Kp7Y=";
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
