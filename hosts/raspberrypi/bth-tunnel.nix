{pkgs, ...}: {
  systemd.network.networks."30-wg0".address = [
    "10.55.0.1/24"
    "10.55.0.20/32"
    "10.55.0.21/32"
  ];

  systemd.services.bth-ssh-forward = {
    description = "SSH Port Forward to dani24@ssh.student.bth.se on 10.55.0.20";
    after = [
      "network-online.target"
      "systemd-networkd.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      User = "cindy";
      AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
      CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
      Restart = "always";
      RestartSec = "10s";
      ExecStart = ''
        ${pkgs.openssh}/bin/ssh -N \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o ExitOnForwardFailure=yes \
          -o StrictHostKeyChecking=accept-new \
          -L 10.55.0.20:22:127.0.0.1:22 \
          dani24@ssh.student.bth.se
      '';
    };
  };

  systemd.services.bth-multiprocessor-server-forward = {
    description = "SSH Port Forward via BTH jump host on 10.55.0.21";
    after = [
      "network-online.target"
      "systemd-networkd.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      User = "cindy";
      AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
      CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
      Restart = "always";
      RestartSec = "10s";
      ExecStart = ''
        ${pkgs.openssh}/bin/ssh -N \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o ExitOnForwardFailure=yes \
          -o StrictHostKeyChecking=accept-new \
          -J dani24@ssh.student.bth.se \
          -L 10.55.0.21:22:127.0.0.1:22 \
          dani24@jane.lab.bth.se
      '';
    };
  };
}
