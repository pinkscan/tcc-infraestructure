job "postgres" {
  datacenters = ["dc1"]
  namespace = "sql"

  group "db" {
    network {
      port  "db"{
        static = 5432
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "hashicorp/postgres-nomad-demo:latest"
        ports = ["db"]
      }

      service {
        name = "postgres"
        port = "db"
        provider = "consul"

        check {
          type     = "tcp"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}
