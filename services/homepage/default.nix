{
  config,
  pkgs,
  mkTraefikLabels,
  ...
}:
{
  myVirtualization.containers.homepage.app = {
    rawImageReference = "ghcr.io/gethomepage/homepage:v2.7.0@sha256:19c5c09184458a41b7b5915e71463a39f36cd33540f41bdbed008791b8182d5f";
    nixSha256 = "sha256-lNeJekEdiran3wVMx6Jp7N+Jx/dPHvEj87HFSGeScY0=";
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
