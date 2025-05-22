# compute.tf — Versão final baseada no seu diagrama

# 1. BOUNDARY CONTROLLER 
resource "aws_instance" "boundary_controller" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.small"
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.boundary_sg_id]
  iam_instance_profile        = var.instance_profile
  associate_public_ip_address = true
  subnet_id                   = var.subnet_public_id

  user_data = templatefile("${path.module}/../shared/machine-scripts/boundary-controller.sh", {})

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "boundary-controller"
  }
}

# 2. SERVER PRINCIPAL (Vault + Nomad Server + Consul Server)
resource "aws_instance" "server_main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  key_name               = var.key_name
  vpc_security_group_ids = [var.instance_sg_id]
  iam_instance_profile   = var.instance_profile
  subnet_id              = var.private_subnet_ids[0]

  user_data = templatefile("${path.module}/../shared/machine-scripts/server-main.sh", {})

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "server-main"
  }
}

# 3, 4. NOMAD WORKERS (com Consul + Boundary Worker)
resource "aws_instance" "worker_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  key_name               = var.key_name
  vpc_security_group_ids = [var.instance_sg_id]
  iam_instance_profile   = var.instance_profile
  subnet_id              = var.private_subnet_ids[0]

  user_data = templatefile("${path.module}/../shared/machine-scripts/worker.sh", {})

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "worker-1"
  }
}

# 5. BOUNDARY WORKER
resource "aws_instance" "worker_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [var.instance_sg_id]
  iam_instance_profile   = var.instance_profile
  subnet_id              = var.private_subnet_ids[1]

  user_data = templatefile("${path.module}/../shared/machine-scripts/worker.sh", {})

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "worker-2"
  }
}


