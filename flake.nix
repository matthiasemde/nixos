{
  description = "Top level flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      sops-nix,
      vscode-server,
    }:
    let
      lib = nixpkgs.lib;

      mkHost =
        {
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
        domain = "emdecloud.de";
        modules = [
          ./hosts/mahler/configuration.nix
          ./hosts/mahler/services.nix
          ./virtualization
          vscode-server.nixosModules.default
          { services.vscode-server.enable = true; }
        ];
      };

      nixosConfigurations.vogel = mkHost {
        modules = [ ./hosts/vogel/configuration.nix ];
      };

      nixosConfigurations.hindemith = mkHost {
        modules = [ ./hosts/hindemith/configuration.nix ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
