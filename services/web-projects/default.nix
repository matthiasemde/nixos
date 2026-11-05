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
    rawImageReference = "nginx:1.31.8-alpine@sha256:785835ea65db4bba6f021acc0f3be91b0fef76a53fe41f8588c6698d2aed0606";
    nixSha256 = "sha256-Xd7q8/xe2gQ/a6wTY5pwsn7dNz5xLbg+9/M8H/vh8QY=";
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
