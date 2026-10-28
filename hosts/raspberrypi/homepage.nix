{config, ...}: {
  config.sensible.homepage = {
    environmentFiles = [config.age.secrets."homepage.env".path];
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
              description = "Loki Log Ingestion Rate";
              widget = {
                type = "customapi";
                url = "https://logs.simd.me/loki/api/v1/query?query=sum(count_over_time(%7Bjob%3D~%22.%2B%22%7D%5B5m%5D))";
                method = "GET";
                refreshInterval = 10000;
                mappings = [
                  {
                    label = "Log Lines (5m)";
                    target = "$.data.result[0].value[1]";
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
              description = "NGINX Reverse Proxy & Unbound DNS Server";
              ping = "10.55.0.1";
            };
          }
          {
            "OpenClaw Host" = {
              icon = "windows";
              href = "https://openclaw.simd.me";
              description = "Gaming Rig and OpenClaw Execution Environment";
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
              description = "Internal K3s Control Plane Bound to WireGuard IP";
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
            "NGINX Errors" = [
              {
                abbr = "NX";
                href = "https://grafana.simd.me/explore?left=%5b%22now-1h%22,%22now%22,%22loki%22,%7b%22expr%22:%22%7bunit%3d%5c%22nginx.service%5c%22%7d%20%7c%3d%20%5c%22error%5c%22%22%7d%5d";
              }
            ];
          }
          {
            "K3s Core Logs" = [
              {
                abbr = "K3s";
                href = "https://grafana.simd.me/explore?left=%5b%22now-1h%22,%22now%22,%22loki%22,%7b%22expr%22:%22%7bunit%3d%5c%22k3s.service%5c%22%7d%22%7d%5d";
              }
            ];
          }
        ];
      }
    ];
  };
}
