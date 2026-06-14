{
  pkgs,
  lib,
  ...
}: {
  services.minecraft-servers = {
    enable = true;
    eula = true;

    dataDir = "/var/lib/minecraft";
    servers = {
      stoneblock = {
        enable = true;
        autoStart = true;
        path = [pkgs.jdk21_headless pkgs.bash pkgs.coreutils pkgs.file];
        managementSystem.tmux.enable = false;
        managementSystem.systemd-socket.enable = true;
        jvmOpts = "";

        package = pkgs.writeShellScriptBin "start-stoneblock" ''
          cd "/var/lib/minecraft/stoneblock"
          exec ./run.sh "$@"
        '';
      };

      gustav_jules = {
        enable = true;
        autoStart = true;
        path = [pkgs.jdk25_headless pkgs.bash pkgs.coreutils pkgs.file];
        managementSystem.tmux.enable = false;
        managementSystem.systemd-socket.enable = true;
        jvmOpts = "";

        package = pkgs.writeShellScriptBin "start-stoneblock" ''
          cd "/var/lib/minecraft/gustav_jules"
          exec ./run.sh
        '';
      };
    };
  };
}
