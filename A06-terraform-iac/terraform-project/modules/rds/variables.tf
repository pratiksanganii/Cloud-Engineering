variable "project_name" {
  description = "Name prefix applied to all resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial database to create"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance (minimum 8 characters)"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group (minimum 2 across different AZs)"
  type        = list(string)
}

variable "security_group_id" {
  description = "DB security group ID to attach to the RDS instance"
  type        = string
}

variable "multi_az" {
  description = "Enable Multi-AZ standby replica (recommended for production)"
  type        = bool
  default     = false
}
