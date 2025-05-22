output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID da subnet pública"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "boundary_sg_id" {
  description = "ID do Security Group para o Boundary"
  value       = aws_security_group.boundary.id
}

output "infra_services_sg_id" {
  description = "ID do Security Group para os serviços privados (Vault, Nomad, etc)"
  value       = aws_security_group.infra_services.id
}
