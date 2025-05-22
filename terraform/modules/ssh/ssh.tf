resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = var.key_name
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "key_file" {
  filename        = "${path.module}/tf-key-dev.pem"
  content         = tls_private_key.key.private_key_pem
  file_permission = "0400"
}
