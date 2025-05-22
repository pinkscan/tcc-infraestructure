# Values for retry_join, and ip_address are
# placed here during Terraform setup and come from the 
# ../shared/data-scripts/user-data-client.sh script

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "dc1"

advertise {
  http = "IP_ADDRESS"
  rpc  = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}

acl {
  enabled = true
}

vault {
  enabled = true
  address = "http://127.0.0.1:8200"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
 
client {
  enabled = true

  host_volume "nomad_data" {
    path      = "/opt/nomad/data"
    read_only = false
  }
  host_volume "grafana_data" {
    path      = "/opt/grafana"
    read_only = false
  }
  host_volume "jupyter_data" {
    path      = "/opt/jupyter"
    read_only = false
  }
  # Montagem do volume de dados do Prometheus
  host_volume "prometheus_data" {
    path      = "/opt/prometheus"
    read_only = false
  }

  # Montagem do volume de dados do Loki
  host_volume "loki_data" {
    path      = "/opt/loki"
    read_only = false
  }

  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }

  server_join {
    retry_join = ["RETRY_JOIN"]
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
    allow_privileged = false  
  }
}

consul {
  address = "127.0.0.1:8500"
  client_service_name = "nomad-client"
  server_service_name = "nomad-server"
  auto_advertise = true
  token = "CONSUL_TOKEN"
}