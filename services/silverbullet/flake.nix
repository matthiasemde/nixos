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
            rawImageReference = "ghcr.io/silverbulletmd/silverbullet:2.4.1@sha256:feab34d6f4f7fe6bfed8289cb67c028650e69ee6d2bf143c6d0437b49d044a0d";
            nixSha256 = "sha256-T0ziLBxLzF0wKOjg0+IdQQLkDbifhDUut27vDfYYn4o=";
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
