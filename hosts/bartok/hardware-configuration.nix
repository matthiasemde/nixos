{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ ];
  boot.initrd.availableKernelModules = [
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/78c5e868-3217-4d49-a6c7-4ee2b64a722d";
    fsType = "ext4";
  };

  fileSystems."/s3" = {
    device = "/dev/disk/by-uuid/33c5979c-579e-4415-bd8d-86c3553854f0";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/4A25-1581";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/49b1720d-9cb5-4bd4-8ffc-c2d04169c18f"; } ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  virtualisation.hypervGuest.enable = true;
}
