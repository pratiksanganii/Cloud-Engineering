# ── General ──────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Name prefix applied to all resource names and tags"
  type        = string
  default     = "terraform-project"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "ap-south-1"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnet placement"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial database to create"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance (min 8 characters)"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ standby for RDS (recommended for production)"
  type        = bool
  default     = false
}
