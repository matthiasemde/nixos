{
  description = "Top level flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      sops-nix,
      vscode-server,
    }:
    let
      lib = nixpkgs.lib;

      mkHost =
        {
          nixpkgs,
          domain ? null,
          modules,
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/common.nix
            ./secret-mgmt
            sops-nix.nixosModules.default
          ]
          ++ modules;
          specialArgs = lib.optionalAttrs (domain != null) { inherit domain; };
        };
    in
    {
      nixosConfigurations.mahler = mkHost {
        nixpkgs = nixpkgs-stable;
        domain = "emdecloud.de";
        modules = [
          ./hosts/mahler/configuration.nix
          ./hosts/mahler/services.nix
          ./virtualization
          vscode-server.nixosModules.default
          { services.vscode-server.enable = true; }
        ];
      };

      nixosConfigurations.bartok = mkHost {
        nixpkgs = nixpkgs-stable;
        domain = "remote.emdecloud.de";
        modules = [
          ./hosts/bartok/configuration.nix
          ./hosts/bartok/services.nix
          ./virtualization
        ];
      };

      nixosConfigurations.vogel = mkHost {
        inherit nixpkgs;
        modules = [ ./hosts/vogel/configuration.nix ];
      };

      nixosConfigurations.hindemith = mkHost {
        inherit nixpkgs;
        modules = [ ./hosts/hindemith/configuration.nix ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
