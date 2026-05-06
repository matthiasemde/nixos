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
            rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.7.0@sha256:8653860d7e22099f84c955f7cb0bc8afc6d7bb35742958401430a06837b66b25";
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
