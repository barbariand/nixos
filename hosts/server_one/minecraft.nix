{pkgs, ...}: {
  services.minecraft-servers = {
    enable = true;
    eula = true;
    servers.stoneblock4 = {
      enable = true;
      package = pkgs.openjdk17;

      dataDir = "/var/lib/minecraft/stoneblock4";

      serverProperties = {
        server-port = 25565;
        motd = "Stoneblock 4 på NixOS";
      };

      jvmOpts = "-Xms8G -Xmx12G -XX:+UseG1GC -XX:+ParallelRefProcEnabled";
    };
  };
}
