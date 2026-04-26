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
  networking.hostName = "bartok";

  networking.firewall.enable = true;

  system.stateVersion = "25.11"; # set to whatever your VM installed version is
}
