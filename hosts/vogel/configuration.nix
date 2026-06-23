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

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.config.allowUnfree = true;

  networking.hostName = "vogel";
  networking.wireguard.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb.layout = "de";
  };
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applicatisons, uncomment the following
    #jack.enable = true;
  };

  system.autoUpgrade.persistent = true;

  # Configure Yubikey support
  # following https://joinemm.dev/blog/yubikey-nixos-guide and https://github.com/drduh/YubiKey-Guide
  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true;
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var actions = ["access_pcsc", "org.debian.pcsc-lite.access_card"];
      if (actions.indexOf(action.id) !== -1 && subject.active && subject.isInGroup("ykusers")) {
        return polkit.Result.YES;
      }
    });
  '';
  security.pam = {
    u2f = {
      enable = true;
      settings = {
        cue = true;
      };
    };
  };

  programs.firefox.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    wget
    vscode
    teamviewer
    wireguard-tools
    cifs-utils
    age-plugin-yubikey
  ];

  fileSystems = lib.listToAttrs (
    map
      (share: {
        name = "/mnt/mahler/${share}";
        value = {
          device = "//mahler/${share}";
          fsType = "cifs";
          options = [
            "credentials=/run/secrets/smb-credentials"
            "uid=1000"
            "gid=1000"
            "_netdev"
            "noauto"
            "x-systemd.automount"
            "x-systemd.idle-timeout=60"
            "x-systemd.device-timeout=5s"
            "x-systemd.mount-timeout=30s"
          ];
        };
      })
      [
        "home"
        "files"
        "paperless"
        "navidrome"
        "audiobookshelf"
      ]
  );

  system.stateVersion = "25.11";
}
