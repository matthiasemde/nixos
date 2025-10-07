{
  description = "Custom VSCode server config";

  inputs.vscode.url = "github:nix-community/nixos-vscode-server";

  outputs =
    {
      self,
      nixpkgs,
      vscode,
    }:
    {
      nixosModules.default =
        { ... }:
        {
          imports = [
            vscode.nixosModules.default
          ];

          services.vscode-server.enable = true;
        };
    };
}
