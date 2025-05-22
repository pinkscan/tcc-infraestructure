variable "key_name" {
  type        = string
  description = "Nome da chave SSH"
}

variable "key_private" {
  type        = string
  description = "Chave privada PEM"
}

variable "instance_type" {
  type        = string
  description = "Tipo base de instância"
}

variable "subnet_public_id" {
  type        = string
  description = "ID da subnet pública (Boundary controller)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Lista de subnets privadas para os serviços"
}

variable "boundary_sg_id" {
  type        = string
  description = "Security Group da Boundary"
}

variable "instance_sg_id" {
  type        = string
  description = "Security Group para instâncias privadas"
}

variable "instance_profile" {
  type        = string
  description = "Perfil de instância IAM"
}
