resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-public-subnet"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count                  = length(var.private_subnet_cidrs)
  vpc_id                 = aws_vpc.main.id
  cidr_block             = varvar.private_subnet_cidrs[count.index]
  availability_zone      = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-private-subnet-${count.index + 1}"
  }
}

# NAT Gateway infra
resource "aws_eip" "nat" {
  vpc = true
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.name}-nat"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.name}-private-rt-${count.index + 1}"
  }
}

# Route associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group – Boundary Public Entry
resource "aws_security_group" "boundary" {
  name   = "${var.name}-boundary-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Boundary TCP Listener"
    from_port   = 9200
    to_port     = 9201
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "boundary-sg"
  }
}

# Security Group – Private Infra Services
resource "aws_security_group" "infra_services" {
  name   = "${var.name}-infra-sg"
  vpc_id = aws_vpc.main.id

  # Allow SSH from Boundary only
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.boundary.id]
  }

  # Nomad ports from Boundary
  ingress {
    from_port       = 4646
    to_port         = 4648
    protocol        = "tcp"
    security_groups = [aws_security_group.boundary.id]
  }

  # Consul UI and RPC from Boundary
  ingress {
    from_port   = 8500
    to_port     = 8502
    protocol    = "tcp"
    security_groups = [aws_security_group.boundary.id]
  }

  # Vault UI
  ingress {
    from_port   = 8200
    to_port     = 8201
    protocol    = "tcp"
    security_groups = [aws_security_group.boundary.id]
  }

  # Waypoint UI
  ingress {
    from_port   = 9702
    to_port     = 9702
    protocol    = "tcp"
    security_groups = [aws_security_group.boundary.id]
  }

  # Frontend (via ALB ou proxy)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # <-- Só se expor pra web. Preferível limitar ao ALB depois.
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend (via ALB ou proxy)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "infra-services-sg"
  }
}
