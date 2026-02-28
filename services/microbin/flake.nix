{
  description = "Service flake for MicroBin";

  outputs =
    { self, nixpkgs }:
    {
      name = "microbin";
      containers =
        {
          domain,
          mkTraefikLabels,
          ...
        }:
        {
          microbin = {
            rawImageReference = "danielszabo99/microbin:2.1.0@sha256:f97990e9c777103babfe4158f30dc084ad7b5ce34cd0729f3f7b2c1eec982374";
            nixSha256 = "sha256-aV9peKIJy7I07u13mlPBAmxeU4QYvktN7YEYPKO0ndg=";
            networks = [ "traefik" ];
            volumes = [
              "/data/services/microbin/data:/app/microbin_data"
            ];
            environment = {
              MICROBIN_PUBLIC_PATH = "https://microbin.${domain}";
              MICROBIN_DISABLE_UPDATE_CHECKING = "true";
            };
            labels =
              mkTraefikLabels {
                name = "microbin";
                port = "8080";
              }
              // {
                "homepage.group" = "Utilities";
                "homepage.name" = "MicroBin";
                "homepage.icon" = "microbin";
                "homepage.href" = "https://microbin.${domain}";
                "homepage.description" = "File-sharing and URL shortening";
              };
          };
        };
    };
}
