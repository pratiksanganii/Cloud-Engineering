# Project 6: Infrastructure as Code with Terraform

## Overview

Manually creating cloud resources through the AWS Console is error-prone, difficult to reproduce, and impossible to version control. In this project you will use **Terraform** to define your entire AWS infrastructure as code, provision a complete VPC, EC2, and RDS stack using reusable modules, and manage state remotely with S3 and DynamoDB — the same pattern used in production-grade cloud environments.

Every resource is expressed as HCL (HashiCorp Configuration Language), committed to Git, and deployable with a single `terraform apply`. The same configuration deploys identically to development, staging, and production — eliminating configuration drift forever.

## Architecture

```
Internet
    │
    ▼
┌──────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16   (us-east-1)                          │
│                                                          │
│  ┌─────────────────────┐    ┌─────────────────────────┐  │
│  │  Public Subnet       │    │  Public Subnet          │  │
│  │  10.0.1.0/24        │    │  10.0.2.0/24            │  │
│  │  (us-east-1a)       │    │  (us-east-1b)           │  │
│  │                     │    │                         │  │
│  │  ┌───────────────┐  │    │                         │  │
│  │  │  EC2 Instance │  │    │                         │  │
│  │  │  (t3.micro)   │  │    │                         │  │
│  │  │  Web Server   │  │    │                         │  │
│  │  └───────────────┘  │    │                         │  │
│  │     Web SG:          │    │                         │  │
│  │     80, 443, 22      │    │                         │  │
│  └─────────────────────┘    └─────────────────────────┘  │
│                                                          │
│  ┌─────────────────────┐    ┌─────────────────────────┐  │
│  │  Private Subnet      │    │  Private Subnet         │  │
│  │  10.0.11.0/24       │    │  10.0.12.0/24           │  │
│  │  (us-east-1a)       │    │  (us-east-1b)           │  │
│  │                     │    │                         │  │
│  │  ┌───────────────┐  │    │  ┌───────────────────┐  │  │
│  │  │  RDS Primary  │  │    │  │  RDS Standby      │  │  │
│  │  │  PostgreSQL   │  │    │  │  (Multi-AZ)       │  │  │
│  │  │  Port 5432    │◀─┼────┼─▶│  Automatic        │  │  │
│  │  └───────────────┘  │    │  │  Failover         │  │  │
│  │     DB SG:           │    │  └───────────────────┘  │  │
│  │     5432 from Web SG │    │                         │  │
│  └─────────────────────┘    └─────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
          │
          │ Route: 0.0.0.0/0
          ▼
  Internet Gateway
          │
          ▼
      Internet


Remote State Backend
┌──────────────────────────────────────────┐
│  S3 Bucket                               │
│  terraform-state-<account-id>            │
│  ├── Versioning: Enabled                 │
│  └── Encryption: SSE-S3                  │
│                                          │
│  DynamoDB Table                          │
│  terraform-state-lock                    │
│  └── LockID (String PK) — state locking  │
└──────────────────────────────────────────┘
```

## What You Will Build

| Resource | Module | Purpose |
|----------|--------|---------|
| VPC (`10.0.0.0/16`) | `vpc` | Isolated network boundary |
| Public Subnets (×2) | `vpc` | EC2 instances, internet-facing resources |
| Private Subnets (×2) | `vpc` | RDS, future private workloads |
| Internet Gateway | `vpc` | Public internet access for public subnets |
| Route Tables | `vpc` | Traffic routing — public subnets routed to IGW |
| Web Security Group | `vpc` | EC2 inbound: ports 80, 443, 22 |
| DB Security Group | `vpc` | RDS inbound: port 5432 from web SG only |
| EC2 Instance (`t3.micro`) | `ec2` | Web/app server in public subnet |
| RDS PostgreSQL 15 | `rds` | Managed database in private subnet with Multi-AZ |
| S3 Bucket | *(manual bootstrap)* | Remote Terraform state storage |
| DynamoDB Table | *(manual bootstrap)* | State locking to prevent concurrent modifications |

## Project Structure

```text
A06-terraform-iac/
├── README.md                   # This file
├── create-terraform-project.sh # One-shot scaffolding script
└── terraform-project/
    ├── backend.tf              # Remote state backend (S3 + DynamoDB)
    ├── main.tf                 # Root module: provider + module calls
    ├── variables.tf            # Input variable declarations
    ├── outputs.tf              # Output values printed after apply
    ├── terraform.tfvars        # Variable values (non-secret)
    └── modules/
        ├── vpc/
        │   ├── main.tf         # VPC, subnets, IGW, route tables, SGs
        │   ├── variables.tf    # VPC module inputs
        │   └── outputs.tf      # vpc_id, subnet IDs, SG IDs
        ├── ec2/
        │   ├── main.tf         # EC2 instance, key pair, EIP
        │   ├── variables.tf    # EC2 module inputs
        │   └── outputs.tf      # instance_id, public_ip
        └── rds/
            ├── main.tf         # RDS instance, subnet group, parameter group
            ├── variables.tf    # RDS module inputs
            └── outputs.tf      # db_endpoint, db_port
```

## Prerequisites

- An AWS account with broad IAM permissions (EC2, VPC, RDS, S3, DynamoDB)
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5 installed
- AWS CLI installed and configured (`aws configure`)
- Git installed
- Basic understanding of HCL (HashiCorp Configuration Language)

---

## Step 1 — Set Up the Remote State Backend

Terraform state tracks every resource it manages. Storing it remotely in S3 means your team shares the same state, and DynamoDB prevents two people from running `apply` simultaneously.

> ⚠️ **These resources must be created before** `terraform init` — Terraform cannot manage its own backend using itself.

### Using the Automated Script

The `create-terraform-project.sh` script scaffolds everything in one step:

```bash
bash create-terraform-project.sh
```

This creates `terraform-project/` with all module files and a ready-to-use `setup-backend.sh`. Run the backend script next:

```bash
bash terraform-project/setup-backend.sh
```

### Manual AWS CLI

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="terraform-state-${ACCOUNT_ID}"

# Create S3 bucket (use --create-bucket-configuration for regions other than us-east-1)
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning — keeps a history of every state file revision
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable server-side encryption at rest
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block all public access — state files must never be public
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "Backend ready. Bucket: $BUCKET_NAME"
```

### Manual AWS Console

**S3 Bucket:**
1. Go to **S3 → Create bucket**
   - **Bucket name:** `terraform-state-<your-account-id>` (must be globally unique)
   - **Region:** `us-east-1`
   - Keep **Block all public access** enabled
2. Click **Create bucket**
3. Open the bucket → **Properties → Bucket Versioning → Edit** → Enable → **Save**
4. **Properties → Default encryption → Edit** → Enable **SSE-S3 (AES-256)** → **Save**

**DynamoDB Table:**
1. Go to **DynamoDB → Tables → Create table**
   - **Table name:** `terraform-state-lock`
   - **Partition key:** `LockID` (String)
   - **Billing mode:** On-demand
2. Click **Create table**

> **Why DynamoDB for locking?** When two engineers run `terraform apply` at the same time, both would read the same state and generate conflicting writes. DynamoDB's conditional writes implement a distributed lock — the second apply is blocked until the first completes.

---

## Step 2 — Configure the Backend

Edit `terraform-project/backend.tf` and replace `ACCOUNT_ID` with your actual 12-digit account ID. Alternatively, run:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" terraform-project/backend.tf
```

`backend.tf` looks like this:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-<ACCOUNT_ID>"
    key            = "terraform-project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

> **What is** `key`**?** The S3 object path within the bucket. Using a path like `terraform-project/terraform.tfstate` lets a single bucket serve multiple Terraform projects — each project uses a unique key.

---

## Step 3 — Initialize Terraform

```bash
cd terraform-project
terraform init
```

Terraform will:
1. Download the AWS provider plugin (from the Terraform registry)
2. Verify the S3 backend bucket and DynamoDB table exist
3. Migrate any local state to the remote backend

Successful output ends with:

```
Terraform has been successfully initialized!
```

> **What does** `terraform init` **actually download?** The AWS provider is a plugin (~80MB) containing Go code that translates HCL resource definitions into AWS API calls. It's cached in `.terraform/` — never commit this directory.

---

## Step 4 — Review and Set Variables

The `terraform.tfvars` file sets all non-sensitive variables. Open it and review the defaults:

```hcl
# terraform.tfvars
project_name     = "terraform-project"
environment      = "dev"
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
instance_type    = "t3.micro"
db_instance_class = "db.t3.micro"
db_name          = "appdb"
```

Set the sensitive DB credentials via environment variables — **never hardcode passwords in `.tfvars` files that get committed to Git**:

```bash
export TF_VAR_db_username="dbadmin"
export TF_VAR_db_password="YourSecurePassword123!"
```

> **How do** `TF_VAR_` **env vars work?** Terraform automatically maps any environment variable prefixed with `TF_VAR_` to the corresponding input variable. `TF_VAR_db_password` sets `var.db_password` at runtime without touching any file on disk.

---

## Step 5 — Validate and Plan

```bash
# Check HCL syntax and internal consistency (no AWS API calls)
terraform validate

# Preview all changes — generates an execution plan
terraform plan -out=tfplan
```

The plan output shows every resource that will be **created** (+), **modified** (~), or **destroyed** (-). Read it carefully before proceeding. You should see approximately:

```
Plan: 18 to add, 0 to change, 0 to destroy.
```

Key resources in the plan:
- `aws_vpc.main` — the VPC
- `aws_subnet.public[0]`, `aws_subnet.public[1]` — two public subnets
- `aws_subnet.private[0]`, `aws_subnet.private[1]` — two private subnets
- `aws_internet_gateway.main` — internet gateway
- `aws_security_group.web`, `aws_security_group.db` — security groups
- `aws_instance.web` — EC2 instance
- `aws_db_instance.main` — RDS PostgreSQL instance

> **Why save the plan with** `-out=tfplan`**?** The saved plan file guarantees that `terraform apply` executes exactly what was reviewed — no drift between the preview and the apply step if variables or remote resources change in the meantime.

---

## Step 6 — Apply the Configuration

```bash
terraform apply tfplan
```

Terraform provisions all resources in dependency order: VPC → subnets → security groups → EC2 → RDS. The RDS instance takes 5–10 minutes to become available.

Successful output ends with:

```
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.
```

---

## Step 7 — View Outputs

```bash
terraform output
```

Expected output:

```
vpc_id                 = "vpc-0abc12345def67890"
public_subnet_ids      = ["subnet-0111", "subnet-0222"]
private_subnet_ids     = ["subnet-0333", "subnet-0444"]
web_security_group_id  = "sg-0aaa"
db_security_group_id   = "sg-0bbb"
web_instance_id        = "i-0abc123"
web_public_ip          = "54.x.x.x"
db_instance_endpoint   = "terraform-project-dev.xxxx.us-east-1.rds.amazonaws.com:5432"
```

You can reference individual outputs:

```bash
terraform output web_public_ip
terraform output db_instance_endpoint
```

---

## Step 8 — Manage State

```bash
# List all resources tracked in remote state
terraform state list

# Inspect a specific resource in detail
terraform state show module.ec2.aws_instance.web

# Pull a local backup of the remote state
terraform state pull > terraform.tfstate.backup

# Remove a resource from state without destroying it (useful for import workflows)
terraform state rm module.ec2.aws_instance.web

# Import an existing AWS resource into Terraform state
terraform import module.vpc.aws_vpc.main vpc-12345678
```

> **When would you use** `terraform import`**?** If someone manually created a resource in the console, Terraform doesn't know about it. `terraform import` brings it under management — after importing, any subsequent `plan` will show diffs between the actual resource and your HCL definition.

---

## Step 9 — Make Changes and Update

Edit `terraform.tfvars` to change a value — for example, upgrade the instance type:

```hcl
instance_type = "t3.small"
```

Then re-plan and apply:

```bash
terraform plan
terraform apply
```

Terraform will show only what changed:

```
  ~ resource "aws_instance" "web" {
      ~ instance_type = "t3.micro" -> "t3.small"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

> **Why does Terraform only change what's needed?** Terraform computes a diff between the current remote state and your desired HCL configuration. Resources that haven't changed are left untouched — this is the core IaC guarantee: declarative intent, not imperative scripts.

---

## Step 10 — Verify Resources in the Console

After `terraform apply` completes, verify each resource was created correctly:

| Resource | Console Location | What to Check |
|----------|-----------------|---------------|
| VPC | **VPC → Your VPCs** | CIDR `10.0.0.0/16`, state `available` |
| Subnets | **VPC → Subnets** | 2 public + 2 private subnets across 2 AZs |
| Internet Gateway | **VPC → Internet Gateways** | State `attached` to your VPC |
| Route Tables | **VPC → Route Tables** | Public RT has route `0.0.0.0/0 → IGW` |
| Security Groups | **EC2 → Security Groups** | Web SG (80, 443, 22) and DB SG (5432) |
| EC2 Instance | **EC2 → Instances** | State `running`, has a public IP |
| RDS Instance | **RDS → Databases** | Status `available`, in private subnets |

---

## Module Reference

### `modules/vpc`

Creates the entire network layer.

| Input Variable | Default | Description |
|----------------|---------|-------------|
| `project_name` | — | Used as a prefix for all resource names |
| `environment` | — | Tagged on all resources (dev/staging/prod) |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_cidrs` | `["10.0.1.0/24", "10.0.2.0/24"]` | Public subnet CIDRs |
| `private_subnet_cidrs` | `["10.0.11.0/24", "10.0.12.0/24"]` | Private subnet CIDRs |
| `availability_zones` | `["us-east-1a", "us-east-1b"]` | AZs for subnet placement |

| Output | Description |
|--------|-------------|
| `vpc_id` | ID of the created VPC |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `web_security_group_id` | SG allowing ports 80, 443, 22 |
| `db_security_group_id` | SG allowing port 5432 from web SG |

### `modules/ec2`

Creates the EC2 instance in the first public subnet.

| Input Variable | Default | Description |
|----------------|---------|-------------|
| `project_name` | — | Used in instance Name tag |
| `instance_type` | `t3.micro` | EC2 instance size |
| `subnet_id` | — | Public subnet to launch into |
| `security_group_id` | — | Web security group ID |
| `ami_id` | Latest Amazon Linux 2023 | AMI for the instance |

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 instance ID |
| `public_ip` | Elastic Public IP address |

### `modules/rds`

Creates a PostgreSQL RDS instance in a DB subnet group spanning private subnets.

| Input Variable | Default | Description |
|----------------|---------|-------------|
| `project_name` | — | Used in DB identifier |
| `db_instance_class` | `db.t3.micro` | RDS instance size |
| `db_name` | — | Initial database name |
| `db_username` | — | Master username (sensitive) |
| `db_password` | — | Master password (sensitive) |
| `subnet_ids` | — | Private subnet IDs for the subnet group |
| `security_group_id` | — | DB security group ID |
| `multi_az` | `false` | Enable Multi-AZ for production |

| Output | Description |
|--------|-------------|
| `db_endpoint` | RDS connection endpoint |
| `db_port` | Database port (5432) |
| `db_name` | Database name |

---

## Testing and Validation

```bash
# Format all .tf files consistently (always run before committing)
terraform fmt -recursive

# Validate configuration syntax
terraform validate

# Check that EC2 instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=terraform-project-web" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}' \
  --output table

# Verify RDS is available
aws rds describe-db-instances \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address}' \
  --output table

# Test EC2 web server connectivity (replace with actual IP from terraform output)
curl http://$(terraform output -raw web_public_ip)
```

---

## Cleanup

> ⚠️ **Always destroy resources when finished to avoid ongoing charges. RDS and EC2 incur costs every hour they run.**

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all managed resources
terraform destroy

# Destroy a specific module only (e.g., to keep VPC but remove EC2)
terraform destroy -target=module.ec2
```

After `terraform destroy` completes, remove the state backend manually:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="terraform-state-${ACCOUNT_ID}"

# Empty and delete the S3 bucket (must be empty before deletion)
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# Delete the DynamoDB lock table
aws dynamodb delete-table --table-name terraform-state-lock
```

**AWS Console cleanup:**
1. **S3** → open `terraform-state-<account-id>` → **Empty** bucket → **Delete bucket**
2. **DynamoDB → Tables** → select `terraform-state-lock` → **Delete**

> **Why must you empty the S3 bucket before deleting it?** S3 does not allow deleting non-empty buckets via the standard delete API — this is a safety guard against accidental data loss. The `--recursive` flag on `aws s3 rm` removes all versioned objects including delete markers.

---

## Verification Checklist

- [ ] S3 bucket created with versioning and SSE-S3 encryption enabled
- [ ] DynamoDB table `terraform-state-lock` created with `LockID` partition key
- [ ] `backend.tf` updated with correct Account ID
- [ ] `terraform init` completes and connects to S3 backend
- [ ] `TF_VAR_db_username` and `TF_VAR_db_password` set as environment variables
- [ ] `terraform validate` reports no errors
- [ ] `terraform plan` shows 18 resources to add, 0 to change
- [ ] `terraform apply` completes successfully
- [ ] `terraform output` shows VPC ID, subnet IDs, EC2 IP, RDS endpoint
- [ ] VPC visible in **VPC → Your VPCs** with correct CIDR
- [ ] EC2 instance in **running** state with a public IP
- [ ] RDS instance in **available** state in private subnets
- [ ] `terraform destroy` completes and removes all resources
- [ ] S3 bucket and DynamoDB table manually deleted

---

## Troubleshooting

| Problem | Solution |
|---------|---------|
| `terraform init` fails with "bucket does not exist" | Run `setup-backend.sh` first, or manually create the S3 bucket and DynamoDB table before `init` |
| `Error: No valid credential sources found` | Run `aws configure` or set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars |
| `Error acquiring the state lock` | Another apply is running, or a previous apply crashed. Check DynamoDB for a stale lock item and delete it manually |
| RDS apply hangs for more than 20 minutes | RDS creation can take up to 15 minutes — this is normal. If it exceeds 25 minutes, check the RDS Events tab in the console |
| `InvalidSubnet` error on RDS | Ensure the DB subnet group covers at least 2 subnets in different AZs. Check `private_subnet_cidrs` in `terraform.tfvars` |
| EC2 unreachable on port 80/443 | Verify the web security group allows inbound on those ports. Also check that the EC2 user-data ran and a web server is actually listening |
| `terraform destroy` fails on RDS | RDS deletion protection may be enabled. Set `deletion_protection = false` in `modules/rds/main.tf` and apply before destroying |
| State drift — plan shows unexpected changes | Someone modified the resource manually via console. Run `terraform refresh` to sync state with reality, then `terraform plan` to review diffs |
| `TF_VAR_db_password` not picked up | Ensure there are no spaces around `=` and the variable name in `variables.tf` is exactly `db_password` |

---

## Learning Objectives

After completing this project, you will understand:

- Infrastructure as Code principles — declarative configuration vs. imperative scripts
- Terraform HCL syntax: resources, data sources, locals, variables, and outputs
- Creating reusable child modules with well-defined inputs and outputs
- Managing remote state with S3 and preventing concurrent modifications with DynamoDB
- Using `terraform plan` as a safe preview gate before any infrastructure change
- The Terraform workflow: `init → validate → plan → apply → destroy`
- How Terraform resolves resource dependencies automatically (implicit references)
- Importing existing resources into Terraform state management
- Secrets management for infrastructure — environment variables vs. `.tfvars`
- Rebuilding entire environments from scratch — the foundation of disaster recovery
