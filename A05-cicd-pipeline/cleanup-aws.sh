#!/bin/bash
# Project 5: Cleanup AWS Infrastructure

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}🗑️ Starting cleanup of Project 5 AWS resources...${NC}"
echo "------------------------------------------------------------"

if [ -f "./config.sh" ]; then
    source ./config.sh
else
    echo -e "${RED}❌ Error: config.sh not found.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

BUCKET_NAME="${S3_BUCKET_NAME:-${S3_BUCKET_PREFIX}-${ACCOUNT_ID}-${REGION}}"

# 1. Delete S3 Bucket
echo -e "${BLUE}Step 1: Emptying and deleting S3 Bucket '${BUCKET_NAME}'...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || true
    aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || true
    echo -e "${GREEN}✓ S3 bucket deleted.${NC}"
else
    echo "S3 Bucket '$BUCKET_NAME' not found or already deleted."
fi

# 2. Delete IAM Role & Policies
echo -e "${BLUE}Step 2: Deleting IAM Role '${ROLE_NAME}'...${NC}"
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess" 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true
echo -e "${GREEN}✓ IAM Role deleted.${NC}"

# 3. Delete OIDC Provider
echo -e "${BLUE}Step 3: Deleting OIDC Provider...${NC}"
if [ -n "$ACCOUNT_ID" ]; then
    OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_URL#https://}"
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null || true
    echo -e "${GREEN}✓ OIDC Provider deleted.${NC}"
fi

# 4. Cleanup Local Files
echo -e "${BLUE}Step 4: Cleaning up local configuration files...${NC}"
rm -f "$CONFIG_FILE" trust-policy.json
echo -e "${GREEN}✓ Local configuration files removed.${NC}"

echo "------------------------------------------------------------"
echo -e "${GREEN}✅ Cleanup Complete! All Project 5 AWS resources destroyed.${NC}"
