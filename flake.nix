{
  description = "Minecraft server with All Create modpack (Neoforge) — NixOS flake with comin + sops-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    comin = {
      url = "github:nixcloud/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    comin,
    sops-nix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.minecraft-server = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit comin sops-nix;};
      modules = [
        ./hosts/minecraft-server/configuration.nix
        comin.nixosModules.comin
        sops-nix.nixosModules.sops
      ];
    };

    nixosModules.minecraft-server = import ./services/minecraft-server;

    devShells.${system}.default = pkgs.mkShell {
      name = "minecraft-server-nixos";
      packages = with pkgs; [
        nixos-generators
        sops
        age
        ssh-to-age
        git
      ];
    };

    # Verify the nixosConfig evaluates — nix flake check will build this
    checks.${system}.default = self.nixosConfigurations.minecraft-server.config.system.build.toplevel;
  };
}
