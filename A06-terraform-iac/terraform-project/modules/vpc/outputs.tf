output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "web_security_group_id" {
  description = "ID of the web security group (ports 80, 443, 22)"
  value       = aws_security_group.web.id
}

output "db_security_group_id" {
  description = "ID of the DB security group (port 5432 from web SG only)"
  value       = aws_security_group.db.id
}
