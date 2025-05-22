# Permissões de criptografia
path "transit/encrypt/boundary-root" {
  capabilities = ["update"]
}

path "transit/decrypt/boundary-root" {
  capabilities = ["update"]
}

path "transit/encrypt/boundary-worker-auth" {
  capabilities = ["update"]
}

path "transit/decrypt/boundary-worker-auth" {
  capabilities = ["update"]
}

path "transit/keys/boundary-root" {
  capabilities = ["read"]
}

path "transit/keys/boundary-worker-auth" {
  capabilities = ["read"]
}