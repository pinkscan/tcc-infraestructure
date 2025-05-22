job "grafana" {
  datacenters = ["dc1"]
  namespace = "observability"
  
  group "grafana-group" {
    vault {
      policies = ["grafana-policy"] 
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        network_mode = "host"
        ports = ["grafana"]

        # Montagem do volume definido acima
        volumes = [
          "/opt/grafana:/var/lib/grafana"
        ]
      }
      env {
        GF_LOG_LEVEL          = "DEBUG"
        GF_LOG_MODE           = "console"
        GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
      }

      # Template para buscar o segredo do Vault
      template {
        data = <<EOT
{{ with secret "kv/data/credencials/grafana" }}
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD={{.Data.data.password}}
{{ end }}
EOT
        destination = "secrets/grafana.env"
        env         = true
      }

      template {
        data = <<EOTC
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://{{ with service "prometheus" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ else }}no-prometheus-service{{ end }}
    jsonData:
      timeInterval: "5s"
  - name: Loki
    type: loki
    access: proxy
    url: http://{{ with service "loki" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ else }}no-loki-service{{ end }}
    jsonData:
      derivedFields:
        - name: "traceID"
          matcherRegex: "traceID=(\\w+)"
          url: "http://jaeger-ui/trace/{{`{{ .Value }}`}}"
EOTC
        destination = "/local/grafana/provisioning/datasources/ds.yaml"
      }

      # Template para adicionar o dashboard
      # Usando o template `file` para copiar o arquivo dashboard.json
      template {
        data        = "${NOMAD_DIR}/dashboard.json"
        destination = "/local/grafana/provisioning/dashboards/default-dashboard.json"
      }


      service {
        name = "grafana"
        port = "grafana"
        tags = ["urlprefix-/"]

        check {
          name     = "Grafana HTTP Health Check"
          type     = "http"
          path     = "/api/health"
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
      port "grafana" {
        static = 3000
      }
    }
  }
}
