output "key_name" {
  value = aws_key_pair.key.key_name
}

output "private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}
