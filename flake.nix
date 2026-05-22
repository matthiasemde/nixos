{
  description = "Top level flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Local flakes
    ## Utilities
    vscode-server.url = "path:./services/vscode-server";
    sops-nix.url = "github:Mic92/sops-nix";
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
    ollama.url = "path:./services/ollama";
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
      sops-nix,
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
      ollama,
      ...
    }:
    {
      nixosConfigurations.mahler = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/mahler/configuration.nix

          vscode-server.nixosModules.default
          sops-nix.nixosModules.default

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
            ollama
          ];
          getEnvFiles = secret-mgmt.lib.getEnvFiles;
          getSecretFile = secret-mgmt.lib.getSecretFile;
        };
      };

      nixosConfigurations.vogel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/vogel/configuration.nix

          sops-nix.nixosModules.default

          secret-mgmt.nixosModules.default
        ];

        specialArgs = {
          hostname = "vogel";
          services = [ ];
        };
      };
    };
}
