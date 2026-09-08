# ── DB Subnet Group ───────────────────────────────────────────────────────────
# Spans private subnets across both AZs — required for RDS
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# ── RDS PostgreSQL Instance ───────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  multi_az            = var.multi_az
  publicly_accessible = false

  # Safe defaults for learning/dev — change for production
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 7

  tags = {
    Name        = "${var.project_name}-rds"
    Environment = var.environment
  }
}
