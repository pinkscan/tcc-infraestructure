variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Lista de CIDRs para as subnets privadas"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zone" {
  description = "Zona de disponibilidade AWS"
  type        = string
  default     = "us-east-1a"
}

variable "region" {
  description = "Região AWS"
  type        = string
}

variable "name" {
  description = "Nome do recurso"
  type        = string
  default     = "tcc"
}