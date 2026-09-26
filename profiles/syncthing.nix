{ user, ... }:
{
  sensible.syncthing = {
    enable = true;
    inherit user;

    cluster = {
      wireguard = "wg0";
    };

    nodes = {
      homecomputer = {
        id = "CSUGSY3-3UAQVQF-7ITSVFQ-KJZ7RAY-Q3PBWKX-OAHMTIC-NMPYM2M-N55QNAS";
      };
      "lenovo-yoga" = {
        id = "QN3QYRB-BZPFGRD-2AOT3AD-XLKJ22N-LM275P4-QCXRIBZ-7GEZ6UX-PZFBNAE";
      };
      raspberrypi = {
        id = "GFDQ3LP-LXUFOFQ-TT5P4EG-NTW23RF-SXR2GVS-XNFUFOE-IISNZ4R-I5ZARAW";
      };
    };

    folders = {
      "nixos-config" = {
        id = "x4k9z-q1p2m";
        path = "/etc/nixos";
        isGitRepo = true;
        fsWatcherDelayS = 15;
      };
      "bsk-latex" = {
        id = "a6gbd-afyse";
        path = "/home/cindy/code/bsk/";
        isGitRepo = true;
        ignorePatterns = [
          "*.aux"
          "*.log"
          "*.out"
          "*.toc"
          "*.synctex.gz"
          "*.fls"
          "*.fdb_latexmk"
        ];
      };
    };
  };
}
