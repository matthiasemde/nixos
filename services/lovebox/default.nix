{
  config,
  pkgs,
  domain,
  mkTraefikLabels,
  ...
}:
let

  phpWithImagick = pkgs.php82.buildEnv {
    extensions = { enabled, all }: enabled ++ [ all.imagick ];
    extraConfig = ''
      memory_limit = 512M
    '';
  };

  startScript = pkgs.writeShellScript "start.sh" ''
    set -e
    mkdir -p /var/log/nginx /var/run /tmp/nginx

    # Start PHP-FPM in background
    ${phpWithImagick}/bin/php-fpm -F -y /etc/php-fpm.conf &

    # Start Nginx in foreground
    ${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -g 'daemon off;'
  '';

  passwdFile = pkgs.writeText "passwd" ''
    root:x:0:0:root:/root:/bin/bash
    www-data:x:33:33:www-data:/var/www:/sbin/nologin
  '';

  groupFile = pkgs.writeText "group" ''
    root:x:0:
    www-data:x:33:
  '';

  loveboxImage = pkgs.dockerTools.buildLayeredImage {
    name = "lovebox";
    tag = "v1.0.0";
    contents = [
      phpWithImagick
      pkgs.nginx
      pkgs.bash
      pkgs.coreutils
      (pkgs.runCommand "app-files" { } ''
        mkdir -p $out/app
        cp -r ${./server}/* $out/app
      '')
      (pkgs.runCommand "config-files" { } ''
        mkdir -p $out/etc/nginx $out/etc
        cp ${./config/nginx.conf} $out/etc/nginx/nginx.conf
        cp ${./config/php-fpm.conf} $out/etc/php-fpm.conf

        cp ${passwdFile} $out/etc/passwd
        cp ${groupFile} $out/etc/group

        ln -s ${pkgs.nginx}/conf/mime.types $out/etc/nginx/
        ln -s ${pkgs.nginx}/conf/fastcgi_params $out/etc/nginx/
      '')
    ];
    config = {
      Cmd = [ "${startScript}" ];
      WorkingDir = "/app";
      ExposedPorts = {
        "80/tcp" = { };
      };
    };
  };
in
{
  myVirtualization.containers.lovebox = {
    image = "lovebox:v1.0.0";
    imageFile = loveboxImage;
    networks = [ "traefik" ];
    volumes = [
      "/data/services/lovebox:/app/messages"
    ];
    labels =
      mkTraefikLabels {
        name = "lovebox";
        port = "80";
        useForwardAuth = true;
      }
      // {
        "homepage.group" = "Media";
        "homepage.name" = "Lovebox ♥️";
        "homepage.icon" = "php";
        "homepage.href" = "http://lovebox.${domain}";
        "homepage.description" = "Service for special ♥️ messages";
      };
  };
}
