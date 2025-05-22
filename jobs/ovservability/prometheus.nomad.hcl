job "prometheus" {
  datacenters = ["dc1"]
  namespace   = "observability"

  group "prometheus-group" {
    vault {
      policies = ["prometheus-metrics"]
    }

    task "prometheus" {
      driver = "docker"

      config {
        image         = "prom/prometheus:latest"
        network_mode  = "host" # Permite acesso à rede do host
        ports         = ["prometheus"]
        args = [
          "--config.file=/local/prometheus.yml",
          "--web.enable-admin-api"
        ]
        volumes = [
          "/opt/prometheus/opt/prometheus:/var/lib/prometheus",
        ]
      }

      # Template para o arquivo de configuração do Prometheus
      template {
        destination = "/local/prometheus.yml"
        data = <<EOT
global:
  scrape_interval: 15s

scrape_configs:

  - job_name: 'data-generator'
    consul_sd_configs:
      - server: '127.0.0.1:8500'
        services: ["data-generator"]
    metrics_path: "/metrics"

    relabel_configs:
      - source_labels: [__meta_consul_service_metadata_external_source]
        target_label: source
        regex: (.*)
        replacement: '$1'

      - source_labels: [__meta_consul_service_id]
        regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
        target_label: 'task_id'
        replacement: '$1'

      - source_labels: [__meta_consul_tags]
        regex: '.*,prometheus,.*'
        action: keep

      - source_labels: [__meta_consul_tags]
        regex: ',(app|monitoring),'
        target_label: 'group'
        replacement: '$1'

      - source_labels: [__meta_consul_service]
        target_label: job

      - source_labels: ['__meta_consul_node']
        target_label: 'instance'
        regex: '(.*)'
        replacement: '$1'

  - job_name: "vault"
    params:
      format: ['prometheus']
    scheme: http
    authorization:
      credentials: "{{with secret "auth/token/create/nomad-cluster" "policies=prometheus-metrics"}}{{.Auth.ClientToken}}{{end}}"
    consul_sd_configs:
      - server: "http://127.0.0.1:8500"
        services: ["vault"]
    metrics_path: "/v1/sys/metrics"

  - job_name: "consul"
    consul_sd_configs:
      - server: "http://127.0.0.1:8500"
    metrics_path: "/v1/metrics"
    relabel_configs:
      - source_labels: ["__meta_consul_tags"]
        regex: ".*prometheus.*"
        action: "keep"

  - job_name: 'nomad_metrics'
    consul_sd_configs:
      - server: 'http://127.0.0.1:8500'
        services: ['nomad-client', 'nomad-server']
    relabel_configs:
      - source_labels: ['__meta_consul_tags']
        regex: '(.*)http(.*)'
        action: keep
    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: "node_exporter"
    consul_sd_configs:
      - server: "http://127.0.0.1:8500"
        services: ["node-exporter"]  # Nome exato do serviço no Consul
    metrics_path: "/metrics"

    # Exemplos de relabeling para manter apenas serviços/tags específicas (se desejar)
    relabel_configs:
      # Mantém apenas serviços com a tag "prometheus" (caso você use essa tag no registro do node-exporter)
      - source_labels: ["__meta_consul_tags"]
        regex: ".*prometheus.*"
        action: "keep"

      # Ajusta o rótulo "instance" para o nome do node no Consul
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"

      # Ajusta o rótulo "job" para o nome do serviço no Consul
      - source_labels: ["__meta_consul_service"]
        target_label: "job"

EOT
      }

      # Registro do Prometheus no Consul
      service {
        name = "prometheus"
        port = "prometheus"

        check {
          name     = "Prometheus HTTP Health Check"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    network {
      port "prometheus" {
        static = 9090
      }
    }
  }
}
