{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Networking
  networking = {
    hostName = "bartok";
    firewall = {
      enable = true;
      # Node exporter metrics
      allowedTCPPorts = [ 9100 ];
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [
      "systemd"
      "textfile"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
    ];
  };

  system.stateVersion = "25.11"; # set to whatever your VM installed version is
}
