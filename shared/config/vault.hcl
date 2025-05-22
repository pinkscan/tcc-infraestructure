storage "consul" {
  address      = "127.0.0.1:8500"
  path         = "vault/"
  service      = "vault"
  service_tags = "secrets"
  token        = "VAULT_TOKEN"
  scheme       = "http"
}

api_addr     = "http://IP_ADDRESS:8200"
cluster_addr = "http://IP_ADDRESS:8201"

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1

}

disable_mlock = true
ui            = true

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}
log_level = "info"                 
log_format = "json"                
log_file = "/opt/vault/logs/vault.log" 

audit "file" {
  file_path = "/opt/vault/logs/vault_audit.log"
  log_raw = true

}

retry_join = ["RETRY_JOIN"]
# seal "awskms" {
#   region     = "us-east-1" 
#   kms_key_id = "arn:aws:kms:us-east-1:571600843355:key/40e7c141-a2b8-4aa4-aa4e-9216980f0f66"
# }