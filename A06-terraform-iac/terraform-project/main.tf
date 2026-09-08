terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
}

# ── VPC Module ───────────────────────────────────────────────────────────────
# Creates: VPC, public/private subnets, IGW, route tables, security groups
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ── EC2 Module ───────────────────────────────────────────────────────────────
# Creates: EC2 instance in first public subnet, using web security group
module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  environment       = var.environment
  instance_type     = var.instance_type
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.web_security_group_id
}

# ── RDS Module ───────────────────────────────────────────────────────────────
# Creates: RDS PostgreSQL in private subnets, using db security group
module "rds" {
  source = "./modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.vpc.db_security_group_id
  multi_az          = var.multi_az
}
