data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "IP_ADDRESS"
datacenter = "dc1"

ui = true
log_level = "INFO"
retry_join = ["RETRY_JOIN"]

acl {
    enabled = true
    default_policy = "deny"
    down_policy = "extend-cache"
    tokens {
      default = "CONSUL_TOKEN"  
  }
}
telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}

recursors = ["8.8.8.8"] # Resolva nomes que não estão no Consul
translate_wan_addrs = true

service {
    name = "consul-client"
}
connect {
  enabled = true
}

ports {
  grpc = 8502
  dns = 8600
}