{ config, lib, pkgs, ... }:

let
  cfg = config.services.minecraft-server;

  # ---- Modpack: All Create (Neoforge) ----------------
  # Pack hosted on CurseForge / Modrinth.
  # Update these when the modpack releases a new version.
  # This is the "All Create: Fabric & Forge" / "All Create" modpack on CurseForge.
  # We use the Neoforge variant.
  modpack = {
    slug = "all-create";
    # The Project ID on CurseForge
    projectId = 886033;
    # Latest known file ID for Neoforge version
    # Get from: https://www.curseforge.com/minecraft/modpacks/all-create/files
    fileId = 6350000; # placeholder — update me!
  };

  # ---- Neoforge server --------------------------------
  neoforge = {
    # Neoforge version matching the modpack requirements
    version = "21.4.144-beta";
    # Minecraft version this neoforge targets
    mcVersion = "1.21.4";

    # URL pattern: https://maven.neoforged.net/releases/net/neoforged/neoforge/{version}/neoforge-{version}-installer.jar
    installer = pkgs.fetchurl {
      url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/${neoforge.version}/neoforge-${neoforge.version}-installer.jar";
      hash = ""; # FIXME: set after first build
    };
  };

  # ---- Modpack download using cfetcher or direct curl --
  # We use a simple derivation that downloads the modpack zip
  # from CurseForge and extracts it.
  modpackData = pkgs.stdenv.mkDerivation {
    name = "all-create-modpack";
    src = pkgs.fetchurl {
      # CurseForge direct download URL (requires API token or cookie)
      # Alternative: use Modrinth API
      url = "https://mediafilez.forgecdn.net/files/${builtins.toString (builtins.div modpack.fileId 1000)}/${builtins.toString (modpack.fileId % 1000)}/All+Create-1.0.0.zip";
      hash = ""; # FIXME
    };
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out
      # Only extract mods/ and config/ and scripts/
      cp -r mods $out/ 2>/dev/null || true
      cp -r config $out/ 2>/dev/null || true
      cp -r scripts $out/ 2>/dev/null || true
      cp -r defaultconfigs $out/ 2>/dev/null || true
      cp manifest.json $out/ 2>/dev/null || true
    '';
  };

in {
  options.services.minecraft-server = {
    enable = lib.mkEnableOption "Minecraft server (Neoforge + All Create modpack)";

    package = lib.mkOption {
      type = lib.types.package;
      default = neoforge.installer;
      description = "Neoforge server installer JAR";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/minecraft-server";
      description = "Minecraft server data directory (server files, world, config)";
    };

    jvmArgs = lib.mkOption {
      type = lib.types.str;
      default = "-Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true";
      description = "JVM arguments for the server";
    };

    eula = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Accept Minecraft EULA (Minecraft EULA at https://account.mojang.com/documents/minecraft_eula)";
    };
  };

  config = lib.mkIf cfg.enable {
    # --- Pre-requisites --------------------------------
    users.users.minecraft-server = {
      description = "Minecraft server user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "minecraft-server";
    };
    users.groups.minecraft-server = {};

    # Accept EULA automatically
    environment.etc."minecraft-eula.txt".text = lib.mkIf cfg.eula ''
      # By changing the setting below to TRUE you are indicating your agreement to our EULA
      # (https://account.mojang.com/documents/minecraft_eula).
      eula=true
    '';

    # --- Service ---------------------------------------
    systemd.services.minecraft-server = {
      description = "Minecraft Server (Neoforge + All Create)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [
        jdk21        # Neoforge needs JDK 21+
        openssl
        curl
      ];

      preStart = ''
        # Create symlink for EULA
        if [ ! -f ${cfg.dataDir}/eula.txt ]; then
          if [ -f /etc/minecraft-eula.txt ]; then
            cp /etc/minecraft-eula.txt ${cfg.dataDir}/eula.txt
          fi
        fi

        # If server JAR doesn't exist, run the installer
        if [ ! -f ${cfg.dataDir}/neoforge-${neoforge.version}.jar ]; then
          echo "Installing Neoforge server..."
          ${jdk21}/bin/java -jar ${neoforge.installer} --installServer ${cfg.dataDir}/
        fi

        # Install modpack if not present
        if [ ! -f ${cfg.dataDir}/mods/.installed ]; then
          echo "Installing All Create modpack..."
          cp -r ${modpackData}/mods ${cfg.dataDir}/ 2>/dev/null || true
          cp -r ${modpackData}/config ${cfg.dataDir}/ 2>/dev/null || true
          cp -r ${modpackData}/scripts ${cfg.dataDir}/ 2>/dev/null || true
          cp -r ${modpackData}/defaultconfigs ${cfg.dataDir}/ 2>/dev/null || true
          chown -R minecraft-server:minecraft-server ${cfg.dataDir}
          touch ${cfg.dataDir}/mods/.installed
        fi
      '';

      script = ''
        cd ${cfg.dataDir}
        exec ${pkgs.jdk21}/bin/java \
          ${cfg.jvmArgs} \
          -jar neoforge-${neoforge.version}.jar \
          nogui
      '';

      serviceConfig = {
        User = "minecraft-server";
        Group = "minecraft-server";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "10s";
        StandardInput = "null";
        StandardOutput = "journal";
        StandardError = "journal";
        LimitNOFILE = 1048576;
        # ProtectHome = true;   # Breaks some mods that write to user home
        ProtectSystem = "full";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
