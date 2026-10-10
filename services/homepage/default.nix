{
  config,
  pkgs,
  mkTraefikLabels,
  ...
}:
{
  myVirtualization.containers.homepage.app = {
    rawImageReference = "ghcr.io/gethomepage/homepage:v2.4.0@sha256:643bd0be730d40f69d58028a55d1a896739333e8815786df42bc97f109ecbe61";
    nixSha256 = "sha256-s8BmanyOcwkvd9Ii0nKtkWtAEso5YkpFUGRDTs+3FP4=";
    volumes =
      (map (file: "${./config}/${file}:/app/config/${file}:ro") (
        builtins.attrNames (builtins.readDir ./config)
      ))
      ++ [
        "/var/run/docker.sock:/var/run/docker.sock"
        "/data:/data"
      ];
    networks = [ "traefik" ];
    environment = {
      HOMEPAGE_ALLOWED_HOSTS = "*";
    };
    labels = mkTraefikLabels {
      name = "homepage";
      port = "3000";
      useForwardAuth = true;
    };
  };
}
