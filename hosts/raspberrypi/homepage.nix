{config, ...}: {
  config.sensible.homepage = {
    environmentFile = config.age.secrets."homepage.env".path;
    allowedHosts = [
      "homepage.simd.me"
      "127.0.0.1:8082"
      "localhost:8082"
    ];
    enable = true;
    port = 8082;

    settings = {
      title = "NixOS Infrastructure Hub";
      theme = "dark";
      layout = {
        iconStyle = "nord";
      };
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
    ];

    services = [
      {
        "Monitoring & Logs" = [
          {
            "Loki Engine" = {
              icon = "grafana-loki";
              href = "https://grafana.simd.me";
              description = "Loki log ingestion rate";
              widget = {
                type = "customapi";

                url = "https://logs.simd.me/loki/api/v1/query_range?query=sum(count_over_time({job=~\".%2B\"}[5m]))";
                method = "GET";
                refreshInterval = 10000;

                mappings = [
                  {
                    label = "Log Lines (5m)";
                    target = "$.data.result[0].values[-1:][0][1]";
                    format = "number";
                  }
                ];
              };
            };
          }
        ];
      }
      {
        "Infrastructure & Automation" = [
          {
            "Raspberry Pi Gateway" = {
              icon = "raspberry-pi";
              href = "https://dns.simd.me";
              description = "Nginx reverse proxy & Unbound DNS server";
              ping = "10.55.0.1";
            };
          }
          {
            "OpenClaw Host" = {
              icon = "windows";
              href = "https://openclaw.simd.me";
              description = "Gaming rig and OpenClaw execution environment";
              ping = "10.55.0.2";
            };
          }
        ];
      }
      {
        "K3s Cluster Resources" = [
          {
            "Kubernetes API" = {
              icon = "kubernetes";
              href = "https://10.55.0.1:6443";
              description = "Internal K3s control plane bound to WireGuard IP";
              ping = "10.55.0.1";
            };
          }
        ];
      }
    ];

    bookmarks = [
      {
        "Log Shortcuts (LogQL)" = [
          {
            "Nginx Errors" = [
              {
                abbr = "NX";
                href = "https://grafana.simd.me/explore?left=%5B%22now-1h%22,%22now%22,%22Loki%22,%7B%22expr%22:%22%7Bunit%3D%5C%22nginx.service%5C%22%7D%20%7C%3D%20%5C%22error%5C%22%22%7D%5D";
              }
            ];
          }
          {
            "K3s Core Logs" = [
              {
                abbr = "K3S";
                href = "https://grafana.simd.me/explore?left=%5B%22now-1h%22,%22now%22,%22Loki%22,%7B%22expr%22:%22%7Bunit%3D%5C%22k3s.service%5C%22%7D%22%7D%5D";
              }
            ];
          }
        ];
      }
    ];
  };
}
