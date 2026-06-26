{ config, lib, pkgs, ... }:

{
  imports = [
    ./sops-base.nix
  ];

  # --- comin: gitops pull-based deploy -----------------
  services.comin = {
    enable = true;
    repository = {
      url = "https://github.com/WarrDoge/minecraft-server-nixos";
      ref = "main";
      # TODO: set deployKeyFile when using a private repo
      # deployKeyFile = config.sops.secrets."comin/deploy-key".path;
    };
    autoUpdate = true;
    wantedServices = [
      "minecraft-server"
      "sops-nix"
    ];
  };

  # Allow comin to rebuild and switch
  nix.settings = {
    trusted-users = ["comin"];
    substituters = ["https://cache.nixos.org"];
    trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
  };
}
