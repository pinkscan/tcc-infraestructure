job "fabio-lb" {
  datacenters = ["dc1"]
  type = "service"

  group "fabio" {
    count = 1

    network {
      port "http" {
        static = 9998  
      }
    }

    task "fabio-task" {
      driver = "docker"

      config {
        image = "fabiolb/fabio:latest"
        ports = ["http"]
      }

      env {
        FABIO_REGISTRY_CONSUL_ADDR          = "10.0.1.116:8500"
        FABIO_REGISTRY_CONSUL_REGISTER_NAME = "fabio"
        FABIO_UI_ADDR                       = ":9998"
        FABIO_LISTEN_ADDR                   = ":9998"
        FABIO_LOG_LEVEL                     = "INFO"
      }

      resources {
        cpu    = 300
        memory = 256
      }

      service {
        name = "fabio"
        port = "http"
        provider = "consul"
        tags = ["urlprefix-/"]
      }
    }
  }
}
