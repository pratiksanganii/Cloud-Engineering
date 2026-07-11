#!/bin/bash
# ------------------------------------------------------------
# deploy.sh – Phase 3 (Idempotent AWS CLI Automation)
# ------------------------------------------------------------
set -e

# Configuration
VPC_NAME="project2-vpc"
SUBNET_NAME="project2-public-subnet"
IGW_NAME="project2-igw"
SG_NAME="project2-web-server-sg"
KEY_NAME="project2-key"
INSTANCE_NAME="Project2-Web-Server"
ROLE_NAME="Project2-EC2-Role"
AMI_ID="ami-006f82a1d5a27da54" # Ubuntu Server 24.04 LTS
INSTANCE_TYPE="t3.micro"

MY_IP=$(curl -s https://checkip.amazonaws.com)

echo "🚀 Starting Idempotent Deployment..."

# 1. VPC Idempotency
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query "Vpcs[0].VpcId" --output text)
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "Creating VPC..."
    VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query "Vpc.VpcId" --output text)
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME
    # Enable DNS hostnames (required for public EC2 instances)
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"
    echo "✅ Created VPC: $VPC_ID"
else
    echo "✅ Found existing VPC: $VPC_ID"
fi

# 2. Internet Gateway Idempotency
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=$IGW_NAME" --query "InternetGateways[0].InternetGatewayId" --output text)
if [ "$IGW_ID" == "None" ] || [ -z "$IGW_ID" ]; then
    echo "Creating Internet Gateway..."
    IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
    aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$IGW_NAME
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
    echo "✅ Created and attached IGW: $IGW_ID"
else
    echo "✅ Found existing IGW: $IGW_ID"
fi

# 3. Subnet Idempotency
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$SUBNET_NAME" --query "Subnets[0].SubnetId" --output text)
if [ "$SUBNET_ID" == "None" ] || [ -z "$SUBNET_ID" ]; then
    echo "Creating Subnet..."
    SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query "Subnet.SubnetId" --output text)
    aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$SUBNET_NAME
    # Auto-assign public IP
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch
    echo "✅ Created Subnet: $SUBNET_ID"
else
    echo "✅ Found existing Subnet: $SUBNET_ID"
fi

# 4. Route Table Idempotency (Updating main route table for VPC)
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --query "RouteTables[0].RouteTableId" --output text)
ROUTE_EXISTS=$(aws ec2 describe-route-tables --route-table-ids $ROUTE_TABLE_ID --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0']" --output text)
if [ -z "$ROUTE_EXISTS" ]; then
    echo "Adding 0.0.0.0/0 route to IGW..."
    aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
    echo "✅ Route added."
else
    echo "✅ Route to IGW already exists."
fi

# 5. Security Group Idempotency
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating Security Group..."
    SG_ID=$(aws ec2 create-security-group --group-name $SG_NAME --description "Security group for Project 2" --vpc-id $VPC_ID --query 'GroupId' --output text)
    
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr "${MY_IP}/32" > /dev/null
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 > /dev/null
    echo "✅ Created Security Group: $SG_ID"
else
    echo "✅ Found existing Security Group: $SG_ID"
    # Note: A truly idempotent script would also check if the rules match exactly and update them if not!
fi

# 6. Key Pair Idempotency
KEY_EXISTS=$(aws ec2 describe-key-pairs --key-names $KEY_NAME --query "KeyPairs[0].KeyName" --output text 2>/dev/null || echo "None")
if [ "$KEY_EXISTS" == "None" ] || [ -z "$KEY_EXISTS" ]; then
    echo "Creating Key Pair..."
    rm -f ${KEY_NAME}.pem
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem # Use Windows equivalent if needed
    echo "✅ Created Key Pair and saved to ${KEY_NAME}.pem"
else
    echo "✅ Found existing Key Pair in AWS: $KEY_NAME"
fi

# 7. EC2 Instance Idempotency
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending" --query "Reservations[0].Instances[0].InstanceId" --output text)
if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "Launching EC2 Instance..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SG_ID \
        --subnet-id $SUBNET_ID \
        --iam-instance-profile Name=$ROLE_NAME \
        --user-data fileb://user-data.sh \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    echo "✅ Instance launching with ID: $INSTANCE_ID"
else
    echo "✅ Found running instance: $INSTANCE_ID"
fi

echo "⏳ Waiting for public IP..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "🎉 Deployment Complete! http://$PUBLIC_IP"