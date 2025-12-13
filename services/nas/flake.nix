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
          getServiceSecrets,
          ...
        }:
        let
          shareUser = "fileshare";
          shareUserPasswordFile = builtins.head (getServiceSecrets "nas");
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
          ];
        in
        {
          users.users.${shareUser} = {
            isSystemUser = true;
            group = "users";
          };

          systemd.tmpfiles.rules = builtins.map (share: "d ${share.path} 0770 ${shareUser} users -") shares;

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

          system.activationScripts.nas-set-samba-password.text = ''
            echo "Setting Samba password for ${shareUser} from ${shareUserPasswordFile}"
            ${pkgs.coreutils}/bin/cat ${shareUserPasswordFile} ${shareUserPasswordFile} | \
            ${pkgs.samba}/bin/smbpasswd -s -a ${shareUser}
          '';
        };
    };
}
