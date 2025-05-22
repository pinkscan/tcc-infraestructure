job "loki" {
  datacenters = ["dc1"]
  type        = "service"
  namespace = "observability"

  group "loki" {
    count = 1

    network {
      port "http" {
        static = 3100
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "loki" {
      driver = "docker"
      config {
        image = "grafana/loki:latest"
        network_mode = "host" 
        ports = ["http"]
        args = [
          "-config.file",
          "/etc/loki/local-config.yaml",
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "loki"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Loki HTTP"
          type     = "http"
          path     = "/ready"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}