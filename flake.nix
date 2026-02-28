{
  description = "Top level flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Local flakes
    ## Utilities
    vscode-server.url = "path:./services/vscode-server";
    agenix.url = "github:ryantm/agenix";
    secret-mgmt.url = "path:./secret-mgmt";

    ## Virtualization / Services
    virtualization.url = "path:./virtualization";
    homepage.url = "path:./services/homepage";
    traefik.url = "path:./services/traefik";
    frp.url = "path:./services/frp";
    adguard.url = "path:./services/adguard";
    firefly.url = "path:./services/firefly";
    home-assistant.url = "path:./services/home-assistant";
    nas.url = "path:./services/nas";
    immich.url = "path:./services/immich";
    nextcloud.url = "path:./services/nextcloud";
    vaultwarden.url = "path:./services/vaultwarden";
    paperless.url = "path:./services/paperless";
    radicale.url = "path:./services/radicale";
    pterodactyl.url = "path:./services/pterodactyl";
    kopia.url = "path:./services/kopia";
    authentik.url = "path:./services/authentik";
    mealie.url = "path:./services/mealie";
    uptime-kuma.url = "path:./services/uptime-kuma";
    grafana.url = "path:./services/grafana";
    synapse.url = "path:./services/synapse";
    navidrome.url = "path:./services/navidrome";
    audiobookshelf.url = "path:./services/audiobookshelf";
    woodpecker.url = "path:./services/woodpecker";
    web-projects.url = "path:./services/web-projects";
    fl-hofmusic.url = "path:./services/fl-hofmusic";
    lovebox.url = "path:./services/lovebox";
    outline.url = "path:./services/outline";
    microbin.url = "path:./services/microbin";
    silverbullet.url = "path:./services/silverbullet";
  };

  outputs =
    {
      self,
      nixpkgs,
      vscode-server,
      virtualization,
      homepage,
      traefik,
      frp,
      adguard,
      agenix,
      secret-mgmt,
      firefly,
      home-assistant,
      nas,
      immich,
      nextcloud,
      vaultwarden,
      paperless,
      radicale,
      pterodactyl,
      kopia,
      authentik,
      mealie,
      uptime-kuma,
      grafana,
      synapse,
      navidrome,
      audiobookshelf,
      woodpecker,
      web-projects,
      fl-hofmusic,
      lovebox,
      outline,
      microbin,
      silverbullet,
      ...
    }:
    {
      nixosConfigurations.mahler = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/mahler/configuration.nix

          vscode-server.nixosModules.default
          agenix.nixosModules.default
          {
            environment.systemPackages = [ agenix.packages.x86_64-linux.default ];
            age.identityPaths = [ "/home/matthias/infra/secrets/host-key.nix.mahler" ];
          }

          secret-mgmt.nixosModules.default
          virtualization.nixosModules.default
          nas.nixosModules.default
        ];

        specialArgs = {
          hostname = "mahler";
          domain = "emdecloud.de";
          services = [
            homepage
            traefik
            frp
            adguard
            firefly
            home-assistant
            nas
            immich
            nextcloud
            vaultwarden
            paperless
            radicale
            pterodactyl
            kopia
            authentik
            mealie
            uptime-kuma
            grafana
            synapse
            navidrome
            audiobookshelf
            woodpecker
            web-projects
            fl-hofmusic
            lovebox
            outline
            microbin
            silverbullet
          ];
          getServiceEnvFiles = secret-mgmt.lib.getServiceEnvFiles;
          getServiceSecrets = secret-mgmt.lib.getServiceSecrets;
        };
      };
    };
}
