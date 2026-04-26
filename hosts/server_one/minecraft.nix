{pkgs,lib, ...}: {
  services.minecraft-servers = {
    enable = true;
    eula = true;

    dataDir = "/var/lib/minecraft";
    servers.stoneblock = {
      enable = true;
      autoStart = true;
# Inkludera verktyg i PATH för systemd-tjänsten
      path = [ pkgs.jdk21_headless pkgs.bash pkgs.coreutils pkgs.file ];
          managementSystem.tmux.enable = false;
          managementSystem.systemd-socket.enable = true;
      # VIKTIGT: Skriv jvmOpts på en enda rad utan manuella radbrytningar
      jvmOpts = "";

      package = pkgs.writeShellScriptBin "start-stoneblock" ''
        # Gå till rätt mapp så att @libraries/ i run.sh hittas
        cd "/var/lib/minecraft/stoneblock"
        echo "Fixing shit"
        echo "Running shit now lets goo"
        # Kör skriptet och skicka vidare alla argument ($@)
        exec ./run.sh "$@"
      '';

    };
  };
}
