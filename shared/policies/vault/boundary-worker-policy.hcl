path "kv/data/boundary-token" {
  capabilities = ["read"]
}
path "kv/metadata/boundary-token" {
  capabilities = ["read"]
}
path "kv/*" {
  capabilities = ["list"]
}