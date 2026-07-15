#!/bin/bash
# Project 3: Serverless Contact Form Cleanup Script

set -e

# Load Centralized Configuration
if [ -f "./config.sh" ]; then
    source ./config.sh
else
    echo "❌ Error: config.sh not found. Please ensure it exists in the same directory."
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}🗑️  Starting cleanup of Serverless Contact Form resources...${NC}"
echo "------------------------------------------------------------"

# 1. API Gateway
echo -e "${BLUE}Step 1: Deleting API Gateway...${NC}"
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$API_ID" ] && [ "$API_ID" != "None" ]; then
    echo "Found API Gateway ID: $API_ID. Deleting..."
    aws apigateway delete-rest-api --rest-api-id "$API_ID" --region "$REGION"
    echo -e "${GREEN}✓ API Gateway deleted${NC}"
else
    echo "API Gateway '$API_NAME' not found. Skipping."
fi

# 2. Lambda Function
echo -e "${BLUE}Step 2: Deleting Lambda Function...${NC}"
aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null || echo "Lambda function '$FUNCTION_NAME' not found. Skipping."
echo -e "${GREEN}✓ Lambda Function check completed${NC}"

# 3. IAM Role & Policies
echo -e "${BLUE}Step 3: Deleting IAM Role and Policies...${NC}"
# Delete inline policy
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name SESSendPolicy 2>/dev/null || echo "Inline policy 'SESSendPolicy' not found. Skipping."

# Detach managed policy
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || echo "Managed policy 'AWSLambdaBasicExecutionRole' not attached. Skipping."

# Delete role
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || echo "IAM Role '$ROLE_NAME' not found. Skipping."
echo -e "${GREEN}✓ IAM Role cleanup completed${NC}"

# 4. Local Files
echo -e "${BLUE}Step 4: Cleaning up local files...${NC}"
rm -f lambda-trust-policy.json ses-policy.json function.zip deployment-info.txt
# Reset the API endpoint in the HTML file back to placeholder for future deployments
if [ -f "frontend/contact.html" ]; then
    # Cross-platform sed for restoring the placeholder
    sed -i.bak 's|API_ENDPOINT = ".*"|API_ENDPOINT = "YOUR_API_GATEWAY_URL"|g' frontend/contact.html
    rm -f frontend/contact.html.bak
fi
echo -e "${GREEN}✓ Local files cleaned${NC}"

# 5. SES Verification (Commented out by default)
echo -e "${YELLOW}Step 5: SES Email Verification${NC}"
echo "SES verified email identities are kept active by default so you don't have to re-verify them in your inbox every time you deploy."
# To remove the SES identity, uncomment the lines below and set your email:
# EMAIL_TO_REMOVE="your-email@example.com"
# aws ses delete-identity --identity "$EMAIL_TO_REMOVE" --region "$REGION"
# echo -e "${GREEN}✓ SES Identity deleted${NC}"

echo "------------------------------------------------------------"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
