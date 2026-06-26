{ config, lib, pkgs, ... }:

{
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
    ];
    # Remap branch name in case the server uses a different local ref
    remapBranchName = true;
  };

  # Allow comin to rebuild and switch
  nix.settings.trusted-users = [ "comin" ];

  # Required for flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
