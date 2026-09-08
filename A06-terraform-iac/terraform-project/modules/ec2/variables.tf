variable "project_name" {
  description = "Name prefix applied to all resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Public subnet ID to launch the EC2 instance in"
  type        = string
}

variable "security_group_id" {
  description = "Web security group ID to attach to the instance"
  type        = string
}
