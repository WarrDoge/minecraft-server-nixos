{
  description = "Minecraft server with All Create modpack (Neoforge) — NixOS flake with comin + sops-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    comin = {
      url = "github:nixcloud/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixneight.url = "github:NotAShelf/nixneight";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    comin,
    sops-nix,
    nixneight,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations = {
      minecraft-server = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit nixpkgs-stable nixneight;};
        modules = [
          ./hosts/minecraft-server/configuration.nix
          comin.nixosModules.comin
          sops-nix.nixosModules.sops
        ];
      };
    };

    # Standalone comin config — use this if the machine is already running
    # and you just want to add comin + sops on top without a full flake eval.
    nixosModules = {
      comin-base = import ./hosts/comin.nix;
      sops-base = import ./hosts/sops-base.nix;
      minecraft-server = import ./services/minecraft-server;
    };

    # Dev shell for working on this flake
    devShells.${system}.default = pkgs.mkShell {
      name = "minecraft-server-nixos";
      packages = with pkgs; [
        nixos-generators
        sops
        age
        ssh-to-age
        git
        just
      ];
    };
  };
}
