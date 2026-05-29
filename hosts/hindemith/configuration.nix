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

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/3cc6d298-9fb8-4819-9ecb-063002d46a0a";
    fsType = "btrfs";
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "broadcom-sta-6.30.223.271-59-6.18.31"
    ];
  };

  networking.hostName = "hindemith";
  networking.wireguard.enable = true;
  networking.wg-quick.interfaces.home = {
    configFile = "/etc/wireguard/home.conf";
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      address = [ "/.mahler.local/192.168.178.100" ];
    };
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb.layout = "de";
  services.libinput = {
    enable = true;
    touchpad.naturalScrolling = true;
    touchpad.horizontalScrolling = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  system.autoUpgrade.persistent = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = [
      pkgs.steam-run
    ];
  };

  users.users.matthias.shell = pkgs.zsh;

  programs.firefox.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  security.polkit.enable = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;

  system.stateVersion = "25.05";
}
