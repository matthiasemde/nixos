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
    rawImageReference = "nginx:1.31.6-alpine@sha256:092a82dc1cb2fa653ee660f24a8f8603f55b4ea9316923f9a0d394e50714ae10";
    nixSha256 = "sha256-kNgaEBAOSIdjl/8E6uiPttX+WJDyVOz+T9HSc7++gnk=";
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
