{ config, lib, pkgs, ... }:

{
  # --- sops-nix: secrets management --------------------
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      # Fallback: systemd service that auto-generates a key on first boot.
      # Replace with your own key file in production:
      #   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
      #   => age1...
      # Then set:
      #   age.keyFile = "/var/lib/sops-nix/key.txt";
      # or use the SSH key directly:
      #   age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      generateKey = true;
    };
  };

  # Necessary for sops-nix to work before network
  systemd.services.sops-nix = {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
  };

  environment.systemPackages = with pkgs; [ sops age ];
}
