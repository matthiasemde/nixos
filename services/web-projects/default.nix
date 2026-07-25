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
    rawImageReference = "nginx:1.31.3-alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752";
    nixSha256 = "sha256-TPH/skkh6iPG936I7yHLgIZZ1qv8LRQT4pk8Q7qwpi8=";
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
