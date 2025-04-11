#!/bin/bash

# Colors for messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}AWS Credentials Check and Setup${NC}"
echo -e "${YELLOW}This script will help you configure your AWS credentials correctly${NC}"
echo -e ""

# Check if AWS CLI is installed
command -v aws >/dev/null 2>&1 || { 
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    echo -e "${YELLOW}To install AWS CLI, follow these steps:${NC}"
    echo -e "1. Download and install AWS CLI from: https://aws.amazon.com/cli/"
    echo -e "2. For macOS, you can also use Homebrew: brew install awscli"
    echo -e ""
    exit 1
}

# Check if AWS credentials are configured
AWS_CREDS_FILE=~/.aws/credentials
AWS_CONFIG_FILE=~/.aws/config

if [ ! -f "$AWS_CREDS_FILE" ] || [ ! -f "$AWS_CONFIG_FILE" ]; then
    echo -e "${YELLOW}AWS credentials or config not found. Let's set them up.${NC}"
    echo -e "${YELLOW}You will need your AWS Access Key ID and Secret Access Key.${NC}"
    echo -e "${YELLOW}If you don't have these, create a new access key in the AWS IAM console:${NC}"
    echo -e "${YELLOW}https://console.aws.amazon.com/iam/home#/security_credentials${NC}"
    echo -e ""
    
    # Run AWS configure to set up credentials
    echo -e "${GREEN}Running aws configure...${NC}"
    aws configure
else
    echo -e "${GREEN}AWS credentials exist. Let's validate them.${NC}"
    
    # Check if we can get caller identity
    AWS_IDENTITY=$(aws sts get-caller-identity 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: AWS credentials are invalid or expired.${NC}"
        echo -e "${YELLOW}Let's reconfigure your AWS credentials.${NC}"
        echo -e ""
        
        # Run AWS configure to reset credentials
        echo -e "${GREEN}Running aws configure...${NC}"
        aws configure
    else
        echo -e "${GREEN}AWS credentials are valid!${NC}"
        echo -e "${GREEN}Current AWS identity:${NC}"
        echo -e "$AWS_IDENTITY"
        
        # Check region
        AWS_REGION=$(aws configure get region)
        echo -e "${GREEN}Current AWS region: ${AWS_REGION}${NC}"
        
        # Ask if user wants to change region
        echo -e "${YELLOW}Do you want to change the AWS region? (y/n)${NC}"
        read -p "> " change_region
        
        if [[ "$change_region" == "y" || "$change_region" == "Y" ]]; then
            echo -e "${YELLOW}Enter the AWS region (e.g., us-east-1, us-west-2, eu-west-1):${NC}"
            read -p "> " new_region
            aws configure set region "$new_region"
            echo -e "${GREEN}AWS region updated to: $(aws configure get region)${NC}"
        fi
    fi
fi

# Check for required IAM permissions
echo -e "${GREEN}Checking for required IAM permissions...${NC}"

# Try to check IAM permissions
IAM_RESULT=$(aws iam get-user 2>&1)
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: Cannot access IAM. This may be due to insufficient permissions.${NC}"
    echo -e "${YELLOW}Please ensure your IAM user or role has the following policies:${NC}"
    echo -e "- IAMReadOnlyAccess (to check permissions)"
    echo -e "- AmazonS3FullAccess (for S3 bucket management)"
    echo -e "- CloudFrontFullAccess (for CloudFront distribution)"
    echo -e "- AWSLambdaFullAccess (for Lambda functions)"
    echo -e "- AmazonAPIGatewayAdministrator (for API Gateway)"
    echo -e ""
    echo -e "${YELLOW}You can attach these policies in the AWS IAM console:${NC}"
    echo -e "${YELLOW}https://console.aws.amazon.com/iam/home#/users${NC}"
else
    echo -e "${GREEN}IAM access confirmed! User: $(echo $IAM_RESULT | grep -o '"UserName":"[^"]*' | cut -d'"' -f4)${NC}"
    
    # Test S3 access
    S3_RESULT=$(aws s3 ls 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Warning: Cannot list S3 buckets. You may need S3 permissions.${NC}"
    else
        echo -e "${GREEN}S3 access confirmed!${NC}"
    fi
    
    # Test CloudFront access
    CF_RESULT=$(aws cloudfront list-distributions --max-items 1 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Warning: Cannot access CloudFront. You may need CloudFront permissions.${NC}"
    else
        echo -e "${GREEN}CloudFront access confirmed!${NC}"
    fi
    
    # Test Lambda access
    LAMBDA_RESULT=$(aws lambda list-functions --max-items 1 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Warning: Cannot access Lambda. You may need Lambda permissions.${NC}"
    else
        echo -e "${GREEN}Lambda access confirmed!${NC}"
    fi
    
    # Test API Gateway access
    APIGW_RESULT=$(aws apigateway get-rest-apis --limit 1 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Warning: Cannot access API Gateway. You may need API Gateway permissions.${NC}"
    else
        echo -e "${GREEN}API Gateway access confirmed!${NC}"
    fi
fi

echo -e ""
echo -e "${GREEN}AWS credentials check completed!${NC}"
echo -e "${YELLOW}If you encountered any permission issues, please update your IAM policies.${NC}"
echo -e "${YELLOW}Once your credentials and permissions are set correctly, run the deploy.sh script again.${NC}" 