{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "mahler";

  console = {
    font = "Lat2-Terminus16";
    keyMap = lib.mkForce "de";
    useXkbConfig = true;
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    wget
    bat
    btop
    pciutils
    lsof
    age
    age-plugin-yubikey
  ];

  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
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

  networking = {
    resolvconf.enable = false;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        53 # Allow TCP DNS
        9100 # Node exporter metrics
      ];
      allowedUDPPorts = [ 53 ]; # Allow UDP DNS
    };
  };

  environment.etc = {
    "resolv.conf".text = "nameserver 192.168.178.1\n";
  };

  system.stateVersion = "24.11";
}
