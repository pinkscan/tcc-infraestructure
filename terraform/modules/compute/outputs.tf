output "controller_public_ip" {
  value = aws_instance.boundary_controller.public_ip
}

output "jupyter_private_ip" {
  value = aws_instance.jupyter_instance.private_ip
}
