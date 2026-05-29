{
  config,
  pkgs,
  mkTraefikLabels,
  ...
}:
let

  configDerivation = pkgs.runCommand "radicale-config" { } ''
    mkdir -p $out/etc/radicale
    cp ${./config/config} $out/etc/radicale/config
    cp ${./users} $out/etc/radicale/users
  '';

  radicaleImage = pkgs.dockerTools.buildImage {
    name = "radicale";
    tag = "v1.0.0";
    copyToRoot = [
      pkgs.dockerTools.binSh
      pkgs.dockerTools.caCertificates
      pkgs.radicale
      configDerivation
    ];
    config = {
      Cmd = [ "/bin/radicale" ];
      ExposedPorts = {
        "5232/tcp" = { };
      };
    };
  };
in
{
  myVirtualization.containers.radicale = {
    image = "radicale:v1.0.0";
    imageFile = radicaleImage;
    volumes = [
      "/data/services/radicale/collections:/var/lib/radicale/collections"
    ];
    networks = [ "traefik" ];
    labels = mkTraefikLabels {
      name = "radicale";
      port = "5232";
    };
  };
}
