{
  config,
  pkgs,
  mkTraefikLabels,
  ...
}:
{
  myVirtualization.containers.homepage.app = {
    rawImageReference = "ghcr.io/gethomepage/homepage:v2.8.0@sha256:019d8f063a7299e7c1c51ee4a70b692291809af3244894fbec2c2ac7d1f71b18";
    nixSha256 = "sha256-nfs4ZkoFTaMRmxhuDN44om4yXYVIX0Dl3BcU2hA8BXs=";
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
