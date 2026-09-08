# ── VPC Outputs ───────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "web_security_group_id" {
  description = "ID of the web security group (ports 80, 443, 22)"
  value       = module.vpc.web_security_group_id
}

output "db_security_group_id" {
  description = "ID of the DB security group (port 5432 from web SG only)"
  value       = module.vpc.db_security_group_id
}

# ── EC2 Outputs ───────────────────────────────────────────────────────────────

output "web_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "web_public_ip" {
  description = "Public IP address of the EC2 web instance"
  value       = module.ec2.public_ip
}

output "web_private_ip" {
  description = "Private IP address of the EC2 web instance"
  value       = module.ec2.private_ip
}

# ── RDS Outputs ───────────────────────────────────────────────────────────────

output "db_instance_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = module.rds.db_endpoint
}

output "db_port" {
  description = "RDS database port"
  value       = module.rds.db_port
}

output "db_name" {
  description = "Name of the initial database"
  value       = module.rds.db_name
}
