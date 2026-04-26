{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nixos-auto-deploy;
in
{
  options.services.nixos-auto-deploy = {
    enable = lib.mkEnableOption "automatic NixOS deployment from the main branch";

    repoUrl = lib.mkOption {
      type = lib.types.str;
      description = "Git repository URL used for the deployment clone (prefer HTTPS for public repos).";
      example = "https://github.com/example/nixos.git";
    };

    deployDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nixos-deploy";
      description = "Directory where the deployment clone is maintained. Never used for development.";
    };

    calendar = lib.mkOption {
      type = lib.types.str;
      default = "Tue *-*-* 01:00:00 Europe/Berlin";
      description = "systemd OnCalendar expression for when to trigger the deployment.";
    };

    persistent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run a missed deployment on the next boot.
        Set to true for machines that are not always on (e.g. desktops).
        Set to false for always-on servers.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixos-auto-deploy = {
      description = "Automatic NixOS deployment from origin/main";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        # nixos-rebuild lives in the current system profile; git is pulled from the store
        PATH = lib.mkForce "${pkgs.git}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        # Passed to deploy.sh as overrides for its defaults
        DEPLOY_DIR = cfg.deployDir;
        REPO_URL = cfg.repoUrl;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash ${./deploy.sh}";
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutStartSec = "1h";
      };
    };

    systemd.timers.nixos-auto-deploy = {
      description = "Timer for automatic NixOS deployment";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = cfg.persistent;
        Unit = "nixos-auto-deploy.service";
      };
    };
  };
}
