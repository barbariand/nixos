{
  lib,
  domain,
  secretKeyFileFn, # Måste vara en funktion (config -> string)
  port ? 3100,
  grafanaPort ? 3000,
  retentionPeriod ? "28d",
  clients ? [],
  serverName ? "loki-server",
}:
assert lib.asserts.assertMsg (builtins.isString domain) "domain must be a fully qualified string (e.g., 'logs.simd.me').";
assert lib.asserts.assertMsg (builtins.isFunction secretKeyFileFn) "secretKeyFileFn must be a function taking 'config' and returning a string path.";
assert lib.asserts.assertMsg (builtins.isInt port && port > 0 && port <= 65535) "The port number must be between 1 and 65535.";
assert lib.asserts.assertMsg (builtins.isList clients) "clients must be a list of hostnames (strings)."; let
  endpoint = "https://${domain}/loki/api/v1/push";

  localEndpoint = "http://127.0.0.1:${builtins.toString port}/loki/api/v1/push";

  alloyConfig = targetUrl: hostname: {
    services.alloy.enable = true;

    systemd.services.alloy.serviceConfig.SupplementaryGroups = ["systemd-journal"];

    environment.etc."alloy/config.alloy".text = ''
      loki.write "local_loki" {
        endpoint {
          url = "${targetUrl}"
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
        labels     = { job = "systemd-journal", host = "${hostname}" }
      }
    '';
  };

  # Omvandlad till en NixOS-modul som tar emot maskinens state (config)
  server = {config, ...}:
    lib.attrsets.recursiveUpdate {
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;

          server = {
            http_listen_address = "0.0.0.0";
            http_listen_port = port;
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
            retention_period = retentionPeriod;
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
          http_port = grafanaPort;
        };

        settings.security = {
          # Utvärderar din funktion med maskinens specifika konfiguration
          secret_key = "$__file{${secretKeyFileFn {inherit config;}}}";
        };

        provision.datasources.settings.datasources = [
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:${builtins.toString port}";
          }
        ];
      };

      networking.firewall.allowedTCPPorts = [port grafanaPort];
    } (alloyConfig localEndpoint serverName);

  # Klienterna omvandlas också till lambdas för konsekvens
  clientModule = hostname: {config, ...}: alloyConfig endpoint hostname;

  clientAttrSet =
    lib.lists.map (clientName: {
      name = clientName;
      value = clientModule clientName;
    })
    clients
    |> lib.listToAttrs;
in
  {
    ${serverName} = server;
  }
  // clientAttrSet
