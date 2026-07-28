#!/bin/bash
set -e

echo "Starting Cleanup for RDS Infrastructure..."

# 1. Delete RDS Instance (skipping final snapshot)
echo "Deleting RDS DB Instance..."
aws rds delete-db-instance \
  --db-instance-identifier my-postgres-db \
  --skip-final-snapshot || true

echo "Waiting for RDS DB Instance to be deleted..."
aws rds wait db-instance-deleted --db-instance-identifier my-postgres-db || true

# 2. Terminate Bastion Host
echo "Finding and Terminating Bastion Host..."
BASTION_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=A04-Bastion-Host" "Name=instance-state-name,Values=running,pending" --query "Reservations[*].Instances[*].InstanceId" --output text)
if [ -n "$BASTION_ID" ]; then
  aws ec2 terminate-instances --instance-ids $BASTION_ID
  echo "Waiting for Bastion Host to terminate..."
  aws ec2 wait instance-terminated --instance-ids $BASTION_ID
else
  echo "No Bastion Host found."
fi

# 3. Delete DB Subnet Group and Parameter Group
echo "Deleting DB Subnet Group..."
aws rds delete-db-subnet-group --db-subnet-group-name A04-rds-subnet-group || true

echo "Deleting DB Parameter Group..."
aws rds delete-db-parameter-group --db-parameter-group-name custom-postgres-params || true

# Delete CloudWatch Alarms
echo "Deleting CloudWatch Alarms..."
aws cloudwatch delete-alarms --alarm-names rds-high-cpu rds-low-storage || true

# 4. Delete Security Groups
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=A04-RDS-VPC" --query "Vpcs[0].VpcId" --output text)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "Found VPC: $VPC_ID"
  
  RDS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=A04-rds-sg" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text)
  BASTION_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=A04-bastion-sg" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text)
  
  if [ "$RDS_SG_ID" != "None" ] && [ -n "$RDS_SG_ID" ]; then
    echo "Deleting RDS Security Group..."
    aws ec2 delete-security-group --group-id $RDS_SG_ID || true
  fi
  
  if [ "$BASTION_SG_ID" != "None" ] && [ -n "$BASTION_SG_ID" ]; then
    echo "Deleting Bastion Security Group..."
    aws ec2 delete-security-group --group-id $BASTION_SG_ID || true
  fi

  # 5. Remove all VPC resources
  echo "Cleaning up VPC resources..."
  
  # Delete Internet Gateway
  IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text)
  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID || true
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID || true
  fi
  
  # Delete Subnets
  SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)
  for SUBNET_ID in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id $SUBNET_ID || true
  done
  
  # Delete Custom Route Tables (Main route table gets deleted with VPC)
  RTB_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=A04-public-rt" --query "RouteTables[*].RouteTableId" --output text)
  for RTB_ID in $RTB_IDS; do
    aws ec2 delete-route-table --route-table-id $RTB_ID || true
  done
  
  echo "Deleting VPC..."
  aws ec2 delete-vpc --vpc-id $VPC_ID || true
else
  echo "VPC not found."
fi

# 6. Delete Key Pair
echo "Deleting Key Pair..."
aws ec2 delete-key-pair --key-name A04-bastion-key || true
rm -f A04-bastion-key.pem deployment-info.txt

echo "Cleanup Complete!"
