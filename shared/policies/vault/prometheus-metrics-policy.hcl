path "/sys/metrics" {
  capabilities = ["read"]
}
path "auth/token/create/*" {
  capabilities = ["update"]
}