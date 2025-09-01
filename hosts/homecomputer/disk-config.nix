{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/wwn-0x5002538d40cf2003";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
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
              };
            };
          };
        };
      };
    };
  };
}
