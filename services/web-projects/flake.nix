{
  description = "Service flake exporting Web Projects static server container config";

  outputs =
    { self, nixpkgs }:
    {
      name = "web-projects";
      containers =
        {
          parseDockerImageReference,
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          web-projects = {
            rawImageReference = "nginx:1.30.0-alpine@sha256:f60d139a69209d4340f6621fc6a50c9843702214231522a3390432f8db0ed870";
            nixSha256 = "sha256-p/wXlo+5I07qOfGEvlSceEJBuQumGODGWUF8cQJVmjE=";
            networks = [
              "traefik"
            ];
            volumes = [
              "/data/nas/home/Matthias/Documents/code/web-projects:/usr/share/nginx/html/projects:ro"
              "${./config/nginx.conf}:/etc/nginx/nginx.conf:ro"
              "${./config/index.html}:/usr/share/nginx/html/index.html:ro"
            ];
            labels = mkTraefikLabels {
              name = "web-projects";
              port = "80";
              useForwardAuth = false;
            } // {
              "homepage.group" = "Fun & Games";
              "homepage.name" = "Web Projects";
              "homepage.icon" = "nginx";
              "homepage.href" = "http://web-projects.${domain}";
              "homepage.description" = "Static web project showcase";
            };
          };
        };
    };
}
