{
  config,
  pkgs,
  mkTraefikLabels,
  ...
}:
{
  myVirtualization.containers.homepage.app = {
    rawImageReference = "ghcr.io/gethomepage/homepage:v2.5.0@sha256:57c4a0531937889c0b968b120fe9c2560bbe036b5c9e18c49a9e2479de9975d1";
    nixSha256 = "sha256-RKRvJv7A0Zr0WaNeESrEh56/wv3pXL0kHQGRwAngPqs=";
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
