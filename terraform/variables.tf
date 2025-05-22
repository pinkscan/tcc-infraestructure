variable "region" {
  description = "Aws region to deploy"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR da subnet pública"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Lista de CIDRs para as subnets privadas"
}

variable "availability_zone" {
  type        = string
  description = "Zona de disponibilidade"
}

variable "bucket_name" {
  type        = string
  description = "Nome do bucket S3"
}


variable "policy_name" {
  type        = string
  description = "Nome da policy IAM"
}

variable "instance_profile_name" {
  type        = string
  description = "Nome do instance profile"
}

variable "key_name" {
  type        = string
  description = "Nome da chave SSH"
}

variable "key_output_path" {
  type        = string
  description = "Caminho do arquivo PEM"
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância EC2"
}
