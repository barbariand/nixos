{interface}:
import ../lib/syncthing.nix {
  inherit interface;

  clusterMap = {
    homecomputer = {
      id = "CSUGSY3-3UAQVQF-7ITSVFQ-KJZ7RAY-Q3PBWKX-OAHMTIC-NMPYM2M-N55QNAS";
      ip = "10.55.0.2"; # WireGuard IP
    };
    "lenovo-yoga" = {
      id = "QN3QYRB-BZPFGRD-2AOT3AD-XLKJ22N-LM275P4-QCXRIBZ-7GEZ6UX-PZFBNAE";
      ip = "10.55.0.3";
    };
    raspberrypi = {
      id = "GFDQ3LP-LXUFOFQ-TT5P4EG-NTW23RF-SXR2GVS-XNFUFOE-IISNZ4R-I5ZARAW";
      ip = "10.55.0.1";
    };
  };

  syncedFolders = {
    "nixos-config" = {
      id = "x4k9z-q1p2m";
      path = "/etc/nixos";
    };
  };
}
