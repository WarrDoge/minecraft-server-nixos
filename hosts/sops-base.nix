{ config, lib, pkgs, ... }:

{
  # --- sops-nix: secrets management --------------------
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      # Use SSH host key directly — no extra key file to manage.
      # Generate your age public key on the server:
      #   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
      # Add the result to .sops.yaml creation_rules.
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  environment.systemPackages = with pkgs; [ sops age ];
}
