{
  description = "Service flake for Silver Bullet";

  outputs =
    { self, nixpkgs }:
    {
      name = "silverbullet";
      containers =
        {
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          silverbullet = {
            rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.6.1@sha256:4b56c552648dfa05a467407ec97d27151efd9dfcc4f8482acd553b32a2843a45";
            nixSha256 = "sha256-oRoiixQD6T1+expnam/wBbCsCUui61s5395QYj+JkPM=";
            networks = [ "traefik" ];
            volumes = [
              "/data/services/silverbullet/space:/space"
            ];
            labels =
              mkTraefikLabels {
                name = "silverbullet";
                port = "3000";
                useForwardAuth = true;
              }
              // {
                "homepage.group" = "Life Management";
                "homepage.name" = "Silverbullet";
                "homepage.icon" = "silverbullet";
                "homepage.href" = "https://silverbullet.${domain}";
                "homepage.description" = "Personal knowledge management";
              };
          };
        };
    };
}
