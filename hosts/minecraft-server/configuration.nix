{ config, lib, pkgs, nixpkgs-stable, nixneight, ... }:

{
  imports = [
    ../comin.nix
    ../sops-base.nix
    ../../services/minecraft-server
  ];

  # --- System basics -----------------------------------
  system.stateVersion = "24.11";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda"; # adjust per hardware

  networking = {
    hostName = "minecraft-server";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 25565 22 ];
      allowedUDPPorts = [ 25565 ];
    };
  };

  time.timeZone = "UTC";

  # --- Users ------------------------------------------
  users.users.root.openssh.authorizedKeys.keys = [
    # TODO: add your SSH pubkey
    # "ssh-ed25519 AAAAC3... user@host"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # --- Nix --------------------------------------------
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # --- Monitoring -------------------------------------
  services.tailscale.enable = true;

  # --- Java / Minecraft alloc -------------------------
  # The service module (services/minecraft-server) handles the rest.
  # Tune heap here:
  systemd.services.minecraft-server = {
    serviceConfig = {
      MemoryMax = "8G";
      MemoryHigh = "6G";
    };
  };

  environment.systemPackages = with pkgs; [
    htop
    iotop
    neofetch
    vim
    curl
    wget
    git
  ];
}
