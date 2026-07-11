#!/bin/bash
# ------------------------------------------------------------
# cleanup.sh – Phase 3 AWS CLI Teardown
# ------------------------------------------------------------
# This script terminates the EC2 instance and deletes the 
# Security Group and Key Pair to prevent AWS charges.
# ------------------------------------------------------------

INSTANCE_NAME="Project2-Web-Server"
SG_NAME="project2-web-server-sg"
KEY_NAME="project2-key"

echo "🧹 Starting Infrastructure Cleanup..."

# 1. Terminate EC2 Instance
echo "🔍 Searching for running EC2 instances named $INSTANCE_NAME..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
    echo "⚠️ Terminating Instance: $INSTANCE_ID"
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID > /dev/null
    
    echo "⏳ Waiting for instance to fully terminate (this takes ~1-3 minutes)..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
    echo "✅ Instance terminated."
else
    echo "✅ No active instances found."
fi

# 2. Delete Security Group
echo "🔍 Searching for Security Group: $SG_NAME..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")

if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    echo "🗑️ Deleting Security Group: $SG_ID"
    aws ec2 delete-security-group --group-id $SG_ID
    echo "✅ Security Group deleted."
else
    echo "✅ Security Group already deleted or not found."
fi

# 3. Delete Key Pair (AWS and Local)
echo "🔑 Deleting Key Pair..."
aws ec2 delete-key-pair --key-name $KEY_NAME
rm -f ${KEY_NAME}.pem
echo "✅ Key Pair deleted from AWS and local disk."

echo "🎉 Cleanup Complete! No resources left running."