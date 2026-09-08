output "db_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.main.db_name
}
