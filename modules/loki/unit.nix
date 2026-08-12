{
  lib,
  config,
  sensibleLib,
  ...
}:
with sensibleLib; let
  cfg = config.sensible.loki;
  hostName = config.networking.hostName;

  isServer = hostName == cfg.serverNode;

  endpoint = if isServer
    then "http://127.0.0.1:${builtins.toString cfg.port}/loki/api/v1/push"
    else "https://${cfg.domain}/loki/api/v1/push";

in
  {
    condition = cfg.enable;

    assertions = [
      {
        assertion = isServer -> cfg.secretKeyFile != null;
        message = "sensible.loki: A 'secretKeyFile' must be provided on the server node (${cfg.serverNode}).";
      }
    ];

    system = {
      services.alloy.enable = true;

      systemd.services.alloy.serviceConfig.SupplementaryGroups = ["systemd-journal"];

      environment.etc."alloy/config.alloy".text = ''
        loki.write "local_loki" {
          endpoint {
            url = "${endpoint}"
          }
        }

        loki.relabel "journald_scraping" {
          forward_to = [loki.write.local_loki.receiver]

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }

          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "hostname"
          }
        }

        loki.source.journal "systemd_journal" {
          max_age    = "12h"
          path       = "/var/log/journal"
          forward_to = [loki.relabel.journald_scraping.receiver]
          labels     = { job = "systemd-journal", host = "${hostName}" }
        }
      '';
    } // lib.optionalAttrs isServer {
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;

          server = {
            http_listen_address = "0.0.0.0";
            http_listen_port = cfg.port;
            grpc_listen_port = 0;
          };

          common = {
            instance_addr = "127.0.0.1";
            path_prefix = "/var/lib/loki";
            storage.filesystem = {
              chunks_directory = "/var/lib/loki/chunks";
              rules_directory = "/var/lib/loki/rules";
            };
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };

          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];

          limits_config = {
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
            creation_grace_period = "10m";
            retention_period = cfg.retentionPeriod;
          };

          compactor = {
            working_directory = "/var/lib/loki/compactor";
            compaction_interval = "10m";
            retention_enabled = true;
            retention_delete_delay = "2h";
            retention_delete_worker_count = 15;
            delete_request_store = "filesystem";
          };
        };
      };

      services.grafana = {
        enable = true;
        settings.server = {
          http_addr = "0.0.0.0";
          http_port = cfg.grafanaPort;
        };

        settings.security = {
          secret_key = "$__file{${cfg.secretKeyFile}}";
        };

        provision.datasources.settings.datasources = [
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${builtins.toString cfg.port}";
          }
        ];
      };

      networking.firewall.allowedTCPPorts = [ cfg.port cfg.grafanaPort ];
    };
  } |> sensibleConfig
