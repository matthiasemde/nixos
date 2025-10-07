{
  description = "Cloudflared container config for NixOS";

  outputs =
    { self, nixpkgs }:
    {
      name = "cloudflared";
      dependencies = {
        networks = {
          "cloudflare-ingress" = "";
        };
      };
      containers =
        { getServiceEnvFiles, ... }:
        {
          cloudflared = {
            image = "cloudflare/cloudflared:2025.7.0";
            networks = [ "cloudflare-ingress" ];
            volumes = [
              "${./config/config.yaml}:/etc/cloudflared/config/config.yaml"
            ];
            # Make sure cloudflared can always connect to cloudflare DNS
            extraOptions = [ "--dns=1.1.1.1" ];
            cmd = [
              "tunnel"
              "--config"
              "/etc/cloudflared/config/config.yaml"
              "run"
            ];
            environmentFiles = getServiceEnvFiles "cloudflared";

            labels = {
              # Traefik (disabled)
              "traefik.enable" = "false";
            };
          };
        };
    };
}
