{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.web-projects.app = {
    rawImageReference = "nginx:1.31.4-alpine@sha256:db35bfc6b2951e7f8a72db5db120288c127ffaeeb4a6d4b95a26fead017d5913";
    nixSha256 = "sha256-q3wcRf2vAOya2ty38o0a7ARPVnDJ2sfOmdzdsrhpm2c=";
    networks = [ "traefik" ];
    volumes = [
      "/data/nas/home/Matthias/Documents/code/web-projects:/usr/share/nginx/html/projects:ro"
      "${./config/nginx.conf}:/etc/nginx/nginx.conf:ro"
      "${./config/index.html}:/usr/share/nginx/html/index.html:ro"
    ];
    labels =
      mkTraefikLabels {
        name = "web-projects";
        port = "80";
        useForwardAuth = false;
      }
      // {
        "homepage.group" = "Fun & Games";
        "homepage.name" = "Web Projects";
        "homepage.icon" = "nginx";
        "homepage.href" = "http://web-projects.${domain}";
        "homepage.description" = "Static web project showcase";
      };
  };
}
