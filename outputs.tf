output "name" {
  value       = aws_instance.web-server.associate_public_ip_address
  sensitive   = false
  description = "Print out my public IP Address"
  depends_on  = [aws_instance.web-server]
}

