{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S2R6NX0H476708Y";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "ef00";
              size = "2g";
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
      games = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-eui.00000000000000000026b7381c5c1f05";
        content = {
          type = "gpt";
          partitions = {
            games = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/Games";
                mountOptions = [
                  "defaults"
                  "nofail"
                ];
              };
            };
          };
        };
      };
    };
  };
}
