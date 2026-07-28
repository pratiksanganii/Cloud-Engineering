#!/bin/bash
set -e

# Set variables — DB_PASSWORD must be set as an environment variable before running
# Usage: DB_PASSWORD="YourSecurePassword" ./deploy-rds.sh
if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: DB_PASSWORD environment variable is not set."
  echo "Usage: DB_PASSWORD=\"YourSecurePassword\" ./deploy-rds.sh"
  exit 1
fi

echo "Deploying RDS Infrastructure..."

# 1. Create VPC and Networking
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=A04-RDS-VPC}]' \
  --query 'Vpc.VpcId' --output text)

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

echo "Creating Subnets..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=A04-rds-private-1a}]' \
  --query 'Subnet.SubnetId' --output text)

SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=A04-rds-private-1b}]' \
  --query 'Subnet.SubnetId' --output text)

PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block 10.0.10.0/24 --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=A04-bastion-public}]' \
  --query 'Subnet.SubnetId' --output text)

echo "Creating Internet Gateway and Route Table..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=A04-RDS-VPC-IGW}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=A04-public-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_ID \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $PUBLIC_SUBNET_ID

# 2. Create Security Groups
echo "Creating Security Groups..."
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name A04-rds-sg \
  --description "Security group for RDS PostgreSQL" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)

BASTION_SG_ID=$(aws ec2 create-security-group \
  --group-name A04-bastion-sg \
  --description "Security group for bastion host" \
  --vpc-id $VPC_ID --query 'GroupId' --output text)

MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID --protocol tcp --port 22 --cidr $MY_IP/32

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID --protocol tcp --port 5432 \
  --source-group $BASTION_SG_ID

# 3. Create DB Subnet Group
echo "Creating DB Subnet Group..."
aws rds create-db-subnet-group \
  --db-subnet-group-name A04-rds-subnet-group \
  --db-subnet-group-description "Subnet group for RDS" \
  --subnet-ids $SUBNET1_ID $SUBNET2_ID

# 4. Create RDS PostgreSQL Instance
echo "Creating Custom DB Parameter Group..."
aws rds create-db-parameter-group \
  --db-parameter-group-name custom-postgres-params \
  --db-parameter-group-family postgres18 \
  --description "Custom PostgreSQL parameters"

aws rds modify-db-parameter-group \
  --db-parameter-group-name custom-postgres-params \
  --parameters \
    "ParameterName=max_connections,ParameterValue=200,ApplyMethod=pending-reboot" \
    "ParameterName=shared_buffers,ParameterValue=262144,ApplyMethod=pending-reboot"

echo "Creating RDS DB Instance... (This will take 10-15 minutes)"
aws rds create-db-instance \
  --db-instance-identifier my-postgres-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 18 \
  --master-username dbadmin \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --storage-encrypted \
  --db-subnet-group-name A04-rds-subnet-group \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-parameter-group-name custom-postgres-params \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --multi-az \
  --auto-minor-version-upgrade \
  --no-publicly-accessible

echo "Waiting for RDS Instance to become available..."
aws rds wait db-instance-available --db-instance-identifier my-postgres-db

DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier my-postgres-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)
echo "DB Endpoint: $DB_ENDPOINT"

# 5. Create Bastion Host
echo "Creating Key Pair for Bastion..."
aws ec2 create-key-pair --key-name A04-bastion-key \
  --query 'KeyMaterial' --output text > A04-bastion-key.pem
chmod 400 A04-bastion-key.pem

echo "Finding Latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

echo "Launching Bastion Host..."
BASTION_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name A04-bastion-key \
  --security-group-ids $BASTION_SG_ID \
  --subnet-id $PUBLIC_SUBNET_ID \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=A04-Bastion-Host}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "Waiting for Bastion Host to run..."
aws ec2 wait instance-running --instance-ids $BASTION_ID

BASTION_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Bastion IP: $BASTION_IP"

# 7. Configure Monitoring and Alarms
echo "Creating CloudWatch Alarms..."
aws cloudwatch put-metric-alarm \
  --alarm-name rds-high-cpu \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=my-postgres-db \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --statistic Average

aws cloudwatch put-metric-alarm \
  --alarm-name rds-low-storage \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=my-postgres-db \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 2000000000 \
  --comparison-operator LessThanThreshold \
  --statistic Average

echo "Deployment Complete!"
echo "DB Endpoint: $DB_ENDPOINT" > deployment-info.txt
echo "Bastion IP: $BASTION_IP" >> deployment-info.txt
echo "SSH Command: ssh -i A04-bastion-key.pem ec2-user@$BASTION_IP" >> deployment-info.txt
cat deployment-info.txt
