# ── General ──────────────────────────────────────────────────────────────────
project_name = "terraform-project"
environment  = "dev"
aws_region   = "ap-south-1"

# ── VPC ───────────────────────────────────────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["ap-south-1a", "ap-south-1b"]

# ── EC2 ───────────────────────────────────────────────────────────────────────
instance_type = "t3.micro"

# ── RDS ───────────────────────────────────────────────────────────────────────
db_instance_class = "db.t3.micro"
db_name           = "appdb"
multi_az          = false

# db_username and db_password are intentionally excluded here.
# Set them as environment variables before running terraform plan/apply:
#
#   $env:TF_VAR_db_username = "dbadmin"
#   $env:TF_VAR_db_password = "YourSecurePassword123!"
