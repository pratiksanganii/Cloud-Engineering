# Fetch the latest Amazon Linux 2023 AMI for the ap-south-1 region
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  # Bootstrap script: install and start Nginx on first boot
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>${var.project_name} — Deployed with Terraform</h1>" \
      > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name        = "${var.project_name}-web"
    Environment = var.environment
  }
}
