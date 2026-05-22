{
  description = "NAS configuration using Samba";

  outputs =
    { self, nixpkgs }:
    {
      name = "nas";
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          getSecretFile,
          ...
        }:
        let
          shareUser = "fileshare";
          shareUserPasswordFile = getSecretFile config.sops.secrets "nas" "fileshare" "password";
          shares = [
            {
              name = "home";
              path = "/data/nas/home";
            }
            {
              name = "files";
              path = "/data/nas/files";
            }
            {
              name = "paperless";
              path = "/data/nas/paperless-consumer";
            }
            {
              name = "navidrome";
              path = "/data/nas/navidrome";
            }
            {
              name = "audiobookshelf";
              path = "/data/nas/audiobookshelf";
            }
          ];
        in
        {
          users.users.${shareUser} = {
            isSystemUser = true;
            group = "users";
          };

          systemd.tmpfiles.rules = builtins.map (share: "d ${share.path} 0777 ${shareUser} users -") shares;

          services.samba = {
            enable = true;
            openFirewall = true;
            package = pkgs.samba;
            settings = {
              global = {
                "follow symlinks" = "yes";
                "wide links" = "yes";
                "unix extensions" = "no";
                security = "user";
                "map to guest" = "Bad User";
              };
            }
            // builtins.listToAttrs (
              builtins.map (share: {
                name = share.name;
                value = {
                  path = share.path;
                  "read only" = "no";
                  "guest ok" = "no";
                  "valid users" = [ shareUser ];
                };
              }) shares
            );
          };

          systemd.services.nas-set-samba-password = {
            description = "Set Samba password for ${shareUser}";
            wantedBy = [ "multi-user.target" ];
            after = [
              "sops-nix.service"
              "userborn.service"
            ];
            wants = [ "sops-nix.service" ];
            serviceConfig = {
              Type = "oneshot";
            };
            script = ''
              cat ${shareUserPasswordFile} ${shareUserPasswordFile} | ${pkgs.samba}/bin/smbpasswd -s -a ${shareUser}
            '';
          };
        };
    };
}
