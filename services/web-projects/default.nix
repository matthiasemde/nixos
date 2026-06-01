{
  config,
  domain,
  mkTraefikLabels,
  ...
}:
let
in
{
  myVirtualization.containers.web-projects = {
    rawImageReference = "nginx:1.31.1-alpine@sha256:8b1e78743a03dbb2c95171cc58639fef29abc8816598e27fb910ed2e621e589a";
    nixSha256 = "sha256-1smG0epcEvN6OA/gQF3mxDMmKh8W33LQITKa37WjAP4=";
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
