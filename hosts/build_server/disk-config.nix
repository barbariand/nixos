{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-P3-1TB_9O60923436789";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "ef00";
              size = "2G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      hdd = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST1000DM003-1SB102_W9A29ABE";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/data";
                mountOptions = [
                  "defaults"
                  "nofail" # Ser till att systemet kan boota även om disken skulle strula
                ];
              };
            };
          };
        };
      };
    };
  };
}
