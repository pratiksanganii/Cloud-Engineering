#!/bin/bash
# Project 5: Provision AWS Infrastructure for GitHub Actions CI/CD

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Provisioning AWS Infrastructure for GitHub Actions OIDC...${NC}"
echo "------------------------------------------------------------"

if [ -f "./config.sh" ]; then
    source ./config.sh
else
    echo -e "${RED}❌ Error: config.sh not found.${NC}"
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}❌ Error: Missing arguments.${NC}"
    echo "Usage: ./configure-aws.sh <github-username> <repo-name>"
    echo "Example: ./configure-aws.sh johndoe my-awesome-app"
    exit 1
fi

GITHUB_USER="$1"
REPO_NAME="$2"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not installed.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "AWS Account ID: ${GREEN}$ACCOUNT_ID${NC}"
echo -e "Target Region: ${GREEN}$REGION${NC}"

# Step 1: OIDC Provider
echo -e "${BLUE}Step 1: Checking/Creating IAM OIDC Provider...${NC}"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER_URL#https://}"

EXISTING_OIDC=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='$OIDC_ARN'].Arn" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_OIDC" ] && [ "$EXISTING_OIDC" != "None" ]; then
    echo "OIDC Provider already exists: $OIDC_ARN"
else
    echo "Creating OIDC Provider for $OIDC_PROVIDER_URL..."
    aws iam create-open-id-connect-provider \
        --url "$OIDC_PROVIDER_URL" \
        --client-id-list "$OIDC_AUDIENCE" \
        --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" 2>/dev/null || echo "OIDC provider created."
fi

# Step 2: IAM Role & Trust Policy
echo -e "${BLUE}Step 2: Creating IAM Role '$ROLE_NAME'...${NC}"

cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER_URL#https://}:aud": "$OIDC_AUDIENCE"
        },
        "StringLike": {
          "${OIDC_PROVIDER_URL#https://}:sub": [
            "repo:${GITHUB_USER}@*/${REPO_NAME}@*:ref:refs/heads/*",
            "repo:${GITHUB_USER}/${REPO_NAME}:ref:refs/heads/*"
          ]
        }
      }
    }
  ]
}
EOF

aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json \
    2>/dev/null || aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document file://trust-policy.json

aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess" 2>/dev/null || true

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo -e "${GREEN}✓ IAM Role configured: $ROLE_ARN${NC}"

# Step 3: S3 Bucket
echo -e "${BLUE}Step 3: Creating Private S3 Artifact Bucket...${NC}"
BUCKET_NAME="${S3_BUCKET_PREFIX}-${ACCOUNT_ID}-${REGION}"

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "S3 Bucket '$BUCKET_NAME' already exists."
else
    echo "Creating bucket '$BUCKET_NAME' in $REGION..."
    if [ "$REGION" == "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
fi

# Ensure Public Access is blocked (private bucket)
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo -e "${GREEN}✓ S3 Bucket configured: $BUCKET_NAME${NC}"

# Clean up local JSON
rm -f trust-policy.json

# Save Config
cat > "$CONFIG_FILE" << EOF
AWS_ACCOUNT_ID=$ACCOUNT_ID
AWS_REGION=$REGION
ROLE_NAME=$ROLE_NAME
ROLE_ARN=$ROLE_ARN
S3_BUCKET_NAME=$BUCKET_NAME
GITHUB_USER=$GITHUB_USER
REPO_NAME=$REPO_NAME
EOF

echo "------------------------------------------------------------"
echo -e "${GREEN}✅ AWS Resources Provisioned Successfully!${NC}"
echo ""
echo -e "Resource Summary saved to: ${BLUE}$CONFIG_FILE${NC}"
echo "------------------------------------------------------------"
cat "$CONFIG_FILE"
echo "------------------------------------------------------------"
echo ""
echo -e "${YELLOW}Next Step: Set GitHub Repository Secrets:${NC}"
echo "  AWS_ACCOUNT_ID = $ACCOUNT_ID"
echo "  S3_BUCKET_NAME = $BUCKET_NAME"
