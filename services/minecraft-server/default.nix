{ config, lib, pkgs, ... }:

let
  cfg = config.services.minecraft-server;
  jdk = pkgs.jdk21;

  # ---- Modpack: All Create (Neoforge) ----------------
  # Pack hosted on CurseForge.
  # Update fileId from: https://www.curseforge.com/minecraft/modpacks/all-create/files
  modpack = {
    slug = "all-create";
    projectId = 886033;
    fileId = 6350000; # placeholder — update me!
  };

  # ---- Neoforge server --------------------------------
  neoforgeVersion = "21.4.144-beta";

  neoforgeJar = pkgs.fetchurl {
    url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/${neoforgeVersion}/neoforge-${neoforgeVersion}-installer.jar";
    hash = lib.fakeSha256; # FIXME: set after first build
  };

  # ---- Modpack download --------------------------------
  modpackData = pkgs.stdenv.mkDerivation {
    name = "all-create-modpack";
    src = pkgs.fetchurl {
      url = "https://mediafilez.forgecdn.net/files/${builtins.toString (builtins.div modpack.fileId 1000)}/${builtins.toString (modpack.fileId % 1000)}/All+Create-1.0.0.zip";
      hash = lib.fakeSha256; # FIXME
    };
    sourceRoot = ".";
    installPhase = ''
      mkdir -p $out
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
      default = neoforgeJar;
      description = "Neoforge server installer JAR";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/minecraft-server";
      description = "Minecraft server data directory";
    };

    jvmArgs = lib.mkOption {
      type = lib.types.str;
      default = "-Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true";
      description = "JVM arguments for the server";
    };

    eula = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Accept Minecraft EULA";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "8G";
      description = "MemoryMax for the service (systemd resource control)";
    };
  };

  config = lib.mkIf cfg.enable {
    # --- User ------------------------------------------
    users.users.minecraft-server = {
      description = "Minecraft server user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "minecraft-server";
    };
    users.groups.minecraft-server = {};

    # --- EULA ------------------------------------------
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
        jdk
        openssl
        curl
      ];

      preStart = ''
        if [ ! -f ${cfg.dataDir}/eula.txt ]; then
          if [ -f /etc/minecraft-eula.txt ]; then
            cp /etc/minecraft-eula.txt ${cfg.dataDir}/eula.txt
          fi
        fi

        if [ ! -f ${cfg.dataDir}/neoforge-${neoforgeVersion}.jar ]; then
          echo "Installing Neoforge server..."
          ${jdk}/bin/java -jar ${neoforgeJar} --installServer ${cfg.dataDir}/
        fi

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
        exec ${jdk}/bin/java \
          ${cfg.jvmArgs} \
          -jar neoforge-${neoforgeVersion}.jar \
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
        ProtectSystem = "full";
        PrivateTmp = true;
        NoNewPrivileges = true;
        MemoryMax = cfg.memoryMax;
      };
    };
  };
}
