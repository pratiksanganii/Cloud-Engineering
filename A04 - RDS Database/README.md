# Project 4: RDS Database with Automated Backups

## Overview

Your application requires a managed relational database that is highly available and automatically backed up. Instead of managing database servers yourself, you will use Amazon RDS to deploy a PostgreSQL database with Multi-AZ redundancy, automated backups, and a secure network configuration. A bastion host provides safe administrative access to the database from your workstation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16) — RDS-VPC                               │
│                                                             │
│  ┌──────────────────────┐   ┌────────────────────────────┐  │
│  │  Public Subnet        │   │  Private Subnets            │  │
│  │  10.0.10.0/24 (1a)    │   │  10.0.1.0/24 (1a)          │  │
│  │                       │   │  10.0.2.0/24 (1b)          │  │
│  │  ┌─────────────────┐ │   │                            │  │
│  │  │  Bastion Host    │ │   │  ┌──────────────────────┐  │  │
│  │  │  (t2.micro)      │─┼───┼─▶│  RDS PostgreSQL      │  │  │
│  │  │  SSH (port 22)   │ │   │  │  (db.t3.micro)       │  │  │
│  │  └─────────────────┘ │   │  │  Multi-AZ             │  │  │
│  │         ▲             │   │  │  Encrypted            │  │  │
│  └─────────┼────────────┘   │  │  7-day backups        │  │  │
│            │                 │  └──────────────────────┘  │  │
│            │                 └────────────────────────────┘  │
│  ┌─────────┼────────────┐                                   │
│  │  Internet Gateway     │                                   │
│  └─────────┼────────────┘                                   │
└────────────┼────────────────────────────────────────────────┘
             │
        Your Workstation
```



## What You Will Build


| Resource                | Purpose                                            |
| ----------------------- | -------------------------------------------------- |
| VPC                     | Isolated network for all resources                 |
| 2 Private Subnets       | Host the RDS instance across two AZs               |
| 1 Public Subnet         | Host the bastion for SSH access                    |
| Internet Gateway        | Allow the bastion to reach the internet            |
| Route Table             | Route public subnet traffic through the IGW        |
| Bastion Security Group  | Allow SSH (port 22) from your IP only              |
| RDS Security Group      | Allow PostgreSQL (port 5432) from the bastion only |
| DB Subnet Group         | Tell RDS which subnets to use                      |
| DB Parameter Group      | Custom PostgreSQL performance settings             |
| RDS PostgreSQL Instance | Managed database with Multi-AZ and backups         |
| Bastion Host (EC2)      | Jump box for secure database access                |
| CloudWatch Alarms       | Alerts for high CPU and low storage                |




## Prerequisites

- AWS account with RDS, EC2, VPC, and CloudWatch permissions
- PostgreSQL client tools (optional, for testing from the bastion)

---



## Step 1 — Create the VPC

1. Go to **VPC → Your VPCs → Create VPC**
2. Configure:
  - **Name tag:** `A04-RDS-VPC`
  - **IPv4 CIDR block:** `10.0.0.0/16`
3. Click **Create VPC**
4. Select the new VPC → **Actions → Edit VPC settings** → enable **DNS hostnames** → **Save**

> **Why DNS hostnames?** RDS gives you a DNS endpoint like `my-postgres-db.abc123.us-east-1.rds.amazonaws.com`. DNS hostnames must be enabled on the VPC for instances inside it to resolve that address.

---



## Step 2 — Create Subnets

Go to **VPC → Subnets → Create subnet**, select `RDS-VPC`, and add three subnets one by one:


| Name             | Availability Zone | CIDR Block     | Purpose                |
| ---------------- | ----------------- | -------------- | ---------------------- |
| `A04-rds-private-1a` | ap-south-1a        | `10.0.1.0/24`  | RDS primary            |
| `A04-rds-private-1b` | ap-south-1b        | `10.0.2.0/24`  | RDS standby (Multi-AZ) |
| `A04-bastion-public` | ap-south-1a        | `10.0.10.0/24` | Bastion host           |


After creating all three:

1. Select `A04-bastion-public` → **Actions → Edit subnet settings**
2. Enable **Auto-assign public IPv4 address** → **Save**

> **Why two private subnets in different AZs?** RDS Multi-AZ requires at least two subnets in separate Availability Zones. If the primary AZ fails, RDS automatically fails over to the standby in the other AZ.

---



## Step 3 — Create Internet Gateway and Route Table



### Internet Gateway

1. Go to **VPC → Internet Gateways → Create internet gateway**
2. **Name tag:** `A04-RDS-VPC-IGW` → click **Create**
3. Select the new IGW → **Actions → Attach to VPC** → choose `A04-RDS-VPC` → **Attach**



### Route Table

1. Go to **VPC → Route Tables → Create route table**
2. **Name:** `A04-public-rt` | **VPC:** `A04-RDS-VPC` → click **Create**
3. Select `A04-public-rt` → **Routes** tab → **Edit routes** → **Add route**:
  - **Destination:** `0.0.0.0/0`
  - **Target:** select the internet gateway (`A04-RDS-VPC-IGW`)
  - Click **Save changes**
4. Select `A04-public-rt` → **Subnet associations** tab → **Edit subnet associations**
  - Check `A04-bastion-public` → **Save associations**

> **Why no route table for the private subnets?** The private subnets use the VPC's default (main) route table, which has no internet route. This keeps the RDS instance completely off the public internet.

---



## Step 4 — Create Security Groups



### Bastion Security Group

1. Go to **EC2 → Security Groups → Create security group**
2. Configure:
  - **Name:** `A04-bastion-sg`
  - **Description:** `Allow SSH from my IP`
  - **VPC:** `A04-RDS-VPC`
3. **Inbound rules → Add rule:**
  - **Type:** SSH | **Port:** 22 | **Source:** My IP
4. Click **Create security group**



### RDS Security Group

1. Click **Create security group** again
2. Configure:
  - **Name:** `A04-rds-sg`
  - **Description:** `Allow PostgreSQL from bastion only`
  - **VPC:** `A04-RDS-VPC`
3. **Inbound rules → Add rule:**
  - **Type:** PostgreSQL | **Port:** 5432 | **Source:** Custom, select `A04-bastion-sg` (type the name to search)
4. Click **Create security group**

> **Why reference the bastion SG instead of an IP?** Security group references are dynamic. Any instance attached to `bastion-sg` can reach the database — no need to update IPs if the bastion is replaced.

---



## Step 5 — Create DB Subnet Group

1. Go to **RDS → Subnet groups → Create DB subnet group**
2. Configure:
  - **Name:** `A04-rds-subnet-group`
  - **Description:** `Subnet group for RDS`
  - **VPC:** `A04-RDS-VPC`
3. **Add subnets:**
  - **Availability Zones:** select `ap-south-1a` and `ap-south-1b`
  - **Subnets:** select `A04-rds-private-1a` and `A04-rds-private-1b`
4. Click **Create**

> **What is a DB Subnet Group?** It tells RDS which subnets (and therefore which AZs) the database can be placed in. Multi-AZ deployments will use one subnet for the primary and another for the standby.

---



## Step 6 — Create RDS PostgreSQL Instance

1. Go to **RDS → Databases → Create database**
2. **Choose a database creation method:** Full configuration
   - *Express configuration* is simpler but gives you less control. Full configuration lets you choose VPC, subnet group, security groups, Multi-AZ, backups, and more.
3. **Engine options:**
   - **Engine type:** PostgreSQL
   - **Engine version:** 18.x (latest minor version)

### Choosing a Template: Free Tier vs Dev/Test

You'll see three templates: **Production**, **Dev/Test**, and **Free tier**.

| Template | Multi-AZ | Cost |
|---|---|---|
| **Free tier** | ❌ Disabled (greyed out) | Free for 12 months (750 hrs/month of `db.t3.micro`) |
| **Dev/Test** | ✅ Available | ~$0.036/hr for the DB instance |
| **Production** | ✅ Enabled by default | Same pricing as Dev/Test, just stricter defaults |

> **💡 Want to practice Multi-AZ?** Select **Dev/Test**. The Free tier template disables Multi-AZ entirely — you can't even toggle it on. Since we've already created two private subnets across two AZs specifically for Multi-AZ, it's worth selecting Dev/Test to see the full architecture in action. The cost for a few hours of practice is minimal (see estimate below).

4. **Templates:** Select **Dev/Test**
5. **Availability and durability:**
   - Select **Multi-AZ DB instance** (creates a standby instance in a second AZ for automatic failover)
6. **Settings:**
   - **DB instance identifier:** `my-postgres-db`
   - **Master username:** `dbadmin`
   - **Master password:** set a strong password and save it somewhere safe
7. **Instance configuration:**
   - **DB instance class:** `db.t3.micro`
8. **Storage:**
   - **Storage type:** gp3
   - **Allocated storage:** 20 GiB
   - Enable **Storage encryption**
9. **Connectivity:**
   - **VPC:** `A04-RDS-VPC`
   - **DB subnet group:** `A04-rds-subnet-group`
   - **Public access:** **No**
   - **VPC security group:** choose existing → select `A04-rds-sg` (remove the default SG)

> **Note:** You won't see an option to choose which subnet is primary and which is standby. That's by design — AWS automatically decides the AZ placement. You provide the subnet group, and RDS handles the rest. After creation, you can check which AZ was chosen under **Connectivity & security**.

10. **Additional configuration:**
    - **Backup retention period:** 7 days
    - **Backup window:** select a preferred window (e.g., 03:00–04:00 UTC)
    - **Maintenance window:** select a preferred window (e.g., Mon 04:00–05:00 UTC)
    - Enable **Auto minor version upgrade**

### Cost Estimate

The console will show an estimated monthly cost of around **~$43/month**. Don't worry — that's if you run it 24/7 for a full month. Your actual cost for practice:

| Duration | Estimated Cost |
|---|---|
| 1 hour | ~$0.06 |
| 2 hours | ~$0.12 |
| 5 hours | ~$0.30 |
| Full month | ~$43.20 |

> **⚠️ Remember to clean up when you're done practicing!** Follow the cleanup steps at the end of this guide to delete all resources and stop charges.

11. Click **Create database**

> ⏳ This takes **10–15 minutes**. Wait until the status shows **Available**. While it's provisioning, you can move on to **Step 7** and set up the bastion host in parallel.

---



## Step 7 — Create Bastion Host



### Create Key Pair

1. Go to **EC2 → Key Pairs → Create key pair**
2. **Name:** `bastion-key` | **Type:** RSA | **Format:** .pem
3. The `.pem` file downloads automatically — save it securely



### Launch Instance

1. Go to **EC2 → Launch instances**
2. Configure:
  - **Name:** `Bastion-Host`
  - **AMI:** Amazon Linux 2023
  - **Instance type:** `t2.micro`
  - **Key pair:** `bastion-key`
3. **Network settings → Edit:**
  - **VPC:** `RDS-VPC`
  - **Subnet:** `bastion-public`
  - **Auto-assign public IP:** Enable
  - **Select existing security group:** `bastion-sg`
4. Click **Launch instance**
5. Wait until the instance is **Running**, then copy its **Public IPv4 address**

---



## Step 8 — Connect to the Database



### SSH into the Bastion

```bash
# Set permissions on the key (Linux/macOS/WSL)
chmod 400 bastion-key.pem

# Connect
ssh -i bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>
```



### Install PostgreSQL Client and Connect

On the bastion host:

```bash
sudo yum install postgresql15 -y
psql -h <RDS_ENDPOINT> -U dbadmin -d postgres
```

> Find the RDS endpoint at **RDS → Databases → my-postgres-db → Connectivity & security → Endpoint**.



### Test with Sample SQL

```sql
CREATE DATABASE testdb;
\c testdb
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));
INSERT INTO users (name, email) VALUES ('Jane Doe', 'jane@example.com');
SELECT * FROM users;
```

---



## Step 9 — Create CloudWatch Alarms



### CPU Utilization Alarm

1. Go to **CloudWatch → Alarms → Create alarm → Select metric**
2. Navigate to **RDS → Per-Database Metrics**
3. Select `my-postgres-db` → **CPUUtilization** → click **Select metric**
4. Configure:
  - **Period:** 5 minutes
  - **Threshold type:** Static
  - **Condition:** Greater than **80**
5. **Alarm name:** `rds-high-cpu`
6. Click **Create alarm**



### Free Storage Alarm

1. Repeat the steps above, but select **FreeStorageSpace**
2. Configure:
  - **Period:** 5 minutes
  - **Condition:** Less than **2000000000** (≈ 2 GB)
3. **Alarm name:** `rds-low-storage`
4. Click **Create alarm**

---



## Verification Checklist

- [ ] RDS instance status is **Available**
- [ ] Multi-AZ shows **Yes** (if using Production template)
- [ ] Automated backups appear under **RDS → Automated backups**
- [ ] Storage encryption shows **Enabled**
- [ ] You can SSH to the bastion host
- [ ] From the bastion, you can `psql` into the RDS endpoint
- [ ] CloudWatch alarms exist and are in **OK** state

---



## Cleanup

> ⚠️ **Always clean up after finishing to avoid ongoing RDS and data transfer charges.**

Delete resources in this order:

1. **RDS → Databases** → select `my-postgres-db` → **Actions → Delete**
  - Uncheck "Create final snapshot" (for test environments)
  - Confirm and delete — **wait for full deletion**
2. **CloudWatch → Alarms** → select `rds-high-cpu` and `rds-low-storage` → **Actions → Delete**
3. **EC2 → Instances** → select `Bastion-Host` → **Instance state → Terminate**
4. **EC2 → Security Groups** → delete `rds-sg` first, then `bastion-sg`
5. **RDS → Subnet groups** → delete `rds-subnet-group`
6. **VPC → Subnets** → delete all three subnets
7. **VPC → Route Tables** → delete `public-rt`
8. **VPC → Internet Gateways** → detach `RDS-VPC-IGW` from the VPC, then delete it
9. **VPC → Your VPCs** → delete `RDS-VPC`
10. **EC2 → Key Pairs** → delete `bastion-key`

> **Cleanup order matters.** RDS must be fully deleted before the subnet group. Security groups can't be deleted while attached to running instances or RDS. The IGW must be detached before it can be deleted.

---



## Learning Objectives

After completing this project, you will understand:

- Deploying managed relational databases with Amazon RDS
- Configuring Multi-AZ for automatic failover and high availability
- Setting up automated backups and point-in-time recovery
- Implementing secure database networking with private subnets
- Creating and using bastion hosts for database administration
- Monitoring database performance with CloudWatch metrics and alarms
- Applying encryption at rest and in transit

---



## Troubleshooting


| Problem                                 | Solution                                                                                             |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Cannot connect to database from bastion | Check that `rds-sg` allows port 5432 from `bastion-sg`, and the bastion is in the correct VPC/subnet |
| Bastion has no public IP                | Confirm `bastion-public` subnet has auto-assign public IP enabled                                    |
| RDS instance stuck in "Creating"        | Normal — RDS provisioning takes 10–15 minutes                                                        |
| `psql: connection refused`              | Verify the RDS endpoint is correct and the instance status is Available                              |
| Backup not appearing                    | Check that backup retention period is greater than 0                                                 |
| Cannot delete security group            | Ensure no instances or RDS databases are still using it                                              |


