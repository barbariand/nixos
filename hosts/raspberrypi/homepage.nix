{config, ...}: {
  config.sensible.homepage = {
    environmentfile = config.age.secrets."homepage.env".path;
    allowedhosts = [
      "homepage.simd.me"
      "127.0.0.1:8082"
      "localhost:8082"
    ];
    enable = true;
    port = 8082;

    settings = {
      title = "nixos infrastructure hub";
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
        "monitoring & logs" = [
          {
            "loki engine" = {
              icon = "grafana-loki";
              href = "https://grafana.simd.me";
              description = "loki log ingestion rate";
              widget = {
                type = "customapi";
                url = "https://logs.simd.me/loki/api/v1/query?query=sum(count_over_time(%7Bjob%3D~%22.%2B%22%7D%5B5m%5D))";
                method = "get";
                refreshInterval = 10000;
                mappings = [
                  {
                    label = "log lines (5m)";
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
        "infrastructure & automation" = [
          {
            "raspberry pi gateway" = {
              icon = "raspberry-pi";
              href = "https://dns.simd.me";
              description = "nginx reverse proxy & unbound dns server";
              ping = "10.55.0.1";
            };
          }
          {
            "openclaw host" = {
              icon = "windows";
              href = "https://openclaw.simd.me";
              description = "gaming rig and openclaw execution environment";
              ping = "10.55.0.2";
            };
          }
        ];
      }
      {
        "k3s cluster resources" = [
          {
            "kubernetes api" = {
              icon = "kubernetes";
              href = "https://10.55.0.1:6443";
              description = "internal k3s control plane bound to wireguard ip";
              ping = "10.55.0.1";
            };
          }
        ];
      }
    ];

    bookmarks = [
      {
        "log shortcuts (logql)" = [
          {
            "nginx errors" = [
              {
                abbr = "nx";
                href = "https://grafana.simd.me/explore?left=%5b%22now-1h%22,%22now%22,%22loki%22,%7b%22expr%22:%22%7bunit%3d%5c%22nginx.service%5c%22%7d%20%7c%3d%20%5c%22error%5c%22%22%7d%5d";
              }
            ];
          }
          {
            "k3s core logs" = [
              {
                abbr = "k3s";
                href = "https://grafana.simd.me/explore?left=%5b%22now-1h%22,%22now%22,%22loki%22,%7b%22expr%22:%22%7bunit%3d%5c%22k3s.service%5c%22%7d%22%7d%5d";
              }
            ];
          }
        ];
      }
    ];
  };
}
