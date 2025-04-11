#!/bin/bash
# Script to deploy the Task Management System using Docker locally or serverless AWS Lambda + API Gateway in production

# Colors for messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting deployment of the Task Management System...${NC}"

# Check dependencies
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}Error: Python 3 is not installed. Install it from https://www.python.org/downloads/.${NC}"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: AWS CLI is not installed. Install it with 'pip3 install awscli'.${NC}"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo -e "${RED}Error: npm is not installed. Install Node.js.${NC}"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo -e "${RED}Error: npx is not installed. Install Node.js.${NC}"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: Docker is not installed. Install it from https://docs.docker.com/get-docker/.${NC}"; exit 1; }
command -v docker compose >/dev/null 2>&1 || { echo -e "${RED}Error: Docker Compose is not installed. Install it from https://docs.docker.com/compose/install/.${NC}"; exit 1; }

# Get AWS account details if needed
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "not-configured")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

# Generate a random string for unique resource naming
RANDOM_STRING=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | fold -w 8 | head -n 1)
S3_BUCKET_NAME="task-management-frontend-${RANDOM_STRING}"
CLOUDFRONT_DISTRIBUTION_NAME="task-management-dist-${RANDOM_STRING}"
API_NAME="task-management-api-${RANDOM_STRING}"

# Ask for MongoDB Atlas connection string
echo -e "${YELLOW}Please provide a MongoDB Atlas connection string.${NC}"
echo -e "${YELLOW}Format: mongodb+srv://username:password@cluster.mongodb.net/task-management${NC}"
echo -e "${YELLOW}This will be used for both local development and production deployment.${NC}"
read -p "MongoDB Atlas URI: " MONGO_URI

# Validate MongoDB Atlas URI
if [[ ! $MONGO_URI == mongodb+srv://* ]]; then
    echo -e "${RED}Error: Invalid MongoDB Atlas URI. URI must start with mongodb+srv://${NC}"
    echo -e "${YELLOW}For MongoDB Atlas setup instructions, visit: https://docs.atlas.mongodb.com/getting-started/${NC}"
    exit 1
fi

# Ask for deployment mode
echo -e "${YELLOW}Select deployment mode:${NC}"
echo -e "${YELLOW}1. Local development with Docker${NC}"
echo -e "${YELLOW}2. Production deployment with Serverless${NC}"
read -p "Enter your choice (1/2): " DEPLOY_MODE

# Generate JWT secrets for both environments
LOCAL_JWT_SECRET="local-development-jwt-secret"
PROD_JWT_SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 32 | head -n 1)

if [ "$DEPLOY_MODE" = "1" ]; then
    echo -e "${GREEN}Setting up local Docker development environment...${NC}"
    
    # Create local .env file for backend
    echo -e "${GREEN}Creating backend environment file for Docker...${NC}"
    cat > backend/.env << EOL
MONGO_URI=${MONGO_URI}
JWT_SECRET=${LOCAL_JWT_SECRET}
EOL

    # Create frontend environment file for local development
    echo -e "${GREEN}Creating frontend environment file for Docker...${NC}"
    cat > frontend/.env.local << EOL
REACT_APP_API_URL=http://localhost:3001
EOL

    # Create/update docker-compose.yml
    echo -e "${GREEN}Creating docker-compose.yml file...${NC}"
    cat > docker-compose.yml << EOL
version: '3'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "80:80"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    environment:
      - REACT_APP_API_URL=http://localhost:3001
    depends_on:
      - backend

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    volumes:
      - ./backend:/app
    environment:
      - MONGO_URI=${MONGO_URI}
      - JWT_SECRET=${LOCAL_JWT_SECRET}
    command: uvicorn app.api:app --host 0.0.0.0 --port 3001 --reload
EOL

    # Ensure Dockerfiles exist
    # Frontend Dockerfile
    if [ ! -f "frontend/Dockerfile" ]; then
        echo -e "${GREEN}Creating frontend Dockerfile...${NC}"
        cat > frontend/Dockerfile << EOL
# Development stage
FROM node:16-alpine as development
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "start"]

# Build stage
FROM development as build
RUN npm run build

# Production stage
FROM nginx:stable-alpine as production
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOL
    fi

    # Backend Dockerfile
    if [ ! -f "backend/Dockerfile" ]; then
        echo -e "${GREEN}Creating backend Dockerfile...${NC}"
        cat > backend/Dockerfile << EOL
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip3 install -r requirements.txt

COPY . .

EXPOSE 3001

CMD ["uvicorn", "app.api:app", "--host", "0.0.0.0", "--port", "3001", "--reload"]
EOL
    fi

    # Nginx configuration for frontend
    if [ ! -f "frontend/nginx.conf" ]; then
        echo -e "${GREEN}Creating nginx.conf for frontend...${NC}"
        cat > frontend/nginx.conf << EOL
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files \$uri \$uri/ /index.html;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOL
    fi

    # Start Docker Compose
    echo -e "${GREEN}Starting Docker containers...${NC}"
    docker compose up --build -d

    echo -e "${GREEN}Local development environment is now running!${NC}"
    echo -e "${GREEN}Frontend: http://localhost${NC}"
    echo -e "${GREEN}Backend API: http://localhost:3001/api${NC}"
    echo -e "${GREEN}API Documentation: http://localhost:3001/api/docs${NC}"
    echo -e "${YELLOW}Note: Your Docker containers are using MongoDB Atlas.${NC}"
    echo -e "${YELLOW}To stop the containers, run: docker compose down${NC}"
else
    echo -e "${GREEN}Preparing for serverless production deployment...${NC}"
    
    # Check if AWS CLI is configured
    if [ "$AWS_ACCOUNT_ID" = "not-configured" ]; then
        echo -e "${RED}Error: AWS CLI is not configured. Run 'aws configure'.${NC}"
        exit 1
    fi
    
    # Check for necessary AWS permissions
    echo -e "${YELLOW}Checking AWS permissions...${NC}"
    aws iam get-user --user-name $(aws sts get-caller-identity --query Arn --output text | cut -d/ -f2) &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Cannot get current IAM user. Please ensure your AWS credentials are valid.${NC}"
        exit 1
    fi
    
    # Check S3 permissions
    aws s3 ls &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: You do not have permission to list S3 buckets.${NC}"
        echo -e "${YELLOW}Please ensure your IAM user has the following policies attached:${NC}"
        echo -e "${YELLOW}- AmazonS3FullAccess${NC}"
        echo -e "${YELLOW}- CloudFrontFullAccess${NC}"
        echo -e "${YELLOW}You can do this in the AWS IAM console: https://console.aws.amazon.com/iam/home#/users${NC}"
        exit 1
    fi
    
    # Install serverless framework if needed
    command -v serverless >/dev/null 2>&1 || { 
        echo -e "${YELLOW}Installing Serverless Framework...${NC}"
        npm install -g serverless
    }
    
    # Generate a secure random JWT secret for production
    PROD_JWT_SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 32 | head -n 1)
    
    # Create .env file for backend in production
    echo -e "${GREEN}Creating backend environment file for production deployment...${NC}"
    cat > backend/.env << EOL
MONGO_URI=${MONGO_URI}
JWT_SECRET=${PROD_JWT_SECRET}
ALLOWED_ORIGINS=https://${CLOUDFRONT_DISTRIBUTION_NAME}.cloudfront.net,http://${S3_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com
EOL

    # Install backend dependencies in a virtual environment
    echo -e "${GREEN}Installing backend dependencies in a virtual environment...${NC}"
    cd backend || { echo -e "${RED}Error: Cannot find backend directory.${NC}"; exit 1; }
    
    # Create and activate a virtual environment
    echo -e "${GREEN}Creating Python virtual environment...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    
    # Create a temporary directory for packaging
    TEMP_PKG_DIR=$(mktemp -d)
    echo -e "${GREEN}Created temporary directory for packaging: ${TEMP_PKG_DIR}${NC}"
    
    # Install dependencies in the temporary directory
    echo -e "${GREEN}Installing dependencies...${NC}"
    pip install -r requirements.txt -t "${TEMP_PKG_DIR}"
    
    # Install npm package for serverless-python-requirements
    echo -e "${GREEN}Installing serverless-python-requirements plugin...${NC}"
    npm install --save-dev serverless-python-requirements
    
    # Copy application code to the temp directory
    echo -e "${GREEN}Copying application code to temporary directory...${NC}"
    cp -r app "${TEMP_PKG_DIR}/"
    
    # Create a custom serverless.yml for deployment
    echo -e "${GREEN}Creating deployment serverless.yml...${NC}"
    cat > "${TEMP_PKG_DIR}/serverless.yml" << EOL
service: task-management-api

frameworkVersion: "3"

provider:
  name: aws
  runtime: python3.9
  stage: \${opt:stage, 'dev'}
  region: \${opt:region, 'us-east-1'}
  environment:
    MONGO_URI: \${env:MONGO_URI}
    JWT_SECRET: \${env:JWT_SECRET}
    ALLOWED_ORIGINS: \${env:ALLOWED_ORIGINS, '*'}
  httpApi:
    cors: true

EOL

    # Append the rest of the original file, but skip the provider section which is already included
    # This way we avoid duplicating the httpApi key
    echo -e "${GREEN}Adding functions and plugins configuration...${NC}"
    
    # Try to find package section
    if grep -q "^package:" serverless.yml; then
        grep -A 1000 "^package:" serverless.yml >> "${TEMP_PKG_DIR}/serverless.yml"
    else
        # If package section not found, try to find functions section
        if grep -q "^functions:" serverless.yml; then
            grep -A 1000 "^functions:" serverless.yml >> "${TEMP_PKG_DIR}/serverless.yml"
        else
            # Add default package configuration if neither found
            cat >> "${TEMP_PKG_DIR}/serverless.yml" << EOL
package:
  individually: true
  patterns:
    - '!node_modules/**'
    - '!venv/**'
    - '!__pycache__/**'
    - '!tests/**'
    - '!.pytest_cache/**'

functions:
  health_check:
    handler: app.main.health_check
    events:
      - httpApi:
          path: /health
          method: GET

  get_tasks:
    handler: app.main.get_tasks
    events:
      - httpApi:
          path: /tasks
          method: GET
  
  create_task:
    handler: app.main.create_task
    events:
      - httpApi:
          path: /tasks
          method: POST
  
  update_task:
    handler: app.main.update_task
    events:
      - httpApi:
          path: /tasks/{id}
          method: PUT
  
  delete_task:
    handler: app.main.delete_task
    events:
      - httpApi:
          path: /tasks/{id}
          method: DELETE

  login:
    handler: app.main.login
    events:
      - httpApi:
          path: /auth/login
          method: POST

plugins:
  - serverless-python-requirements

custom:
  pythonRequirements:
    dockerizePip: non-linux
    slim: true
EOL
        fi
    fi

    # Create package.json in the temp directory
    echo -e "${GREEN}Creating package.json in temporary directory...${NC}"
    cp package.json "${TEMP_PKG_DIR}/" 2>/dev/null || cat > "${TEMP_PKG_DIR}/package.json" << EOL
{
  "name": "task-management-backend",
  "version": "1.0.0",
  "description": "Backend API for Task Management System",
  "dependencies": {},
  "devDependencies": {
    "serverless-python-requirements": "^5.4.0"
  }
}
EOL
    
    # Set environment variables for serverless deployment
    echo -e "${GREEN}Exporting environment variables for serverless deployment...${NC}"
    export MONGO_URI
    export JWT_SECRET=$PROD_JWT_SECRET
    export ALLOWED_ORIGINS="https://${CLOUDFRONT_DISTRIBUTION_NAME}.cloudfront.net,http://${S3_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com"
    
    # Deploy backend using Serverless Framework from the temp directory
    echo -e "${GREEN}Deploying backend with Serverless Framework...${NC}"
    cd "${TEMP_PKG_DIR}" || { echo -e "${RED}Error: Cannot access temporary directory.${NC}"; exit 1; }
    
    # Install serverless-python-requirements plugin
    echo -e "${GREEN}Installing serverless-python-requirements plugin...${NC}"
    npm install --save-dev serverless-python-requirements
    
    # Print the generated serverless.yml for debugging
    echo -e "${YELLOW}Displaying generated serverless.yml content for verification:${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
    cat serverless.yml
    echo -e "${YELLOW}----------------------------------------${NC}"
    
    # Try to deploy with serverless
    echo -e "${GREEN}Running serverless deploy...${NC}"
    DEPLOY_OUTPUT=$(serverless deploy --verbose --stage prod 2>&1)
    DEPLOY_STATUS=$?
    
    # Check if deployment was successful
    if [ $DEPLOY_STATUS -ne 0 ]; then
        echo -e "${RED}Error: Serverless deployment failed.${NC}"
        echo -e "${RED}Error details:${NC}"
        echo "$DEPLOY_OUTPUT"
        
        # Attempt to identify and fix common issues
        if echo "$DEPLOY_OUTPUT" | grep -q "duplicated mapping key"; then
            echo -e "${YELLOW}Detected duplicate keys in serverless.yml. This is a known issue.${NC}"
            echo -e "${YELLOW}Please check and edit your original serverless.yml file to remove any duplicate keys.${NC}"
        elif echo "$DEPLOY_OUTPUT" | grep -q "AccessDenied"; then
            echo -e "${YELLOW}Detected AWS permissions issue. Make sure your IAM user has sufficient permissions.${NC}"
        fi
        
        # Save the serverless.yml for inspection
        cp serverless.yml ~/serverless-debug.yml
        echo -e "${YELLOW}Saved problematic serverless.yml to ~/serverless-debug.yml for inspection.${NC}"
        
        API_URL=""
    else
        echo -e "${GREEN}Serverless deployment successful!${NC}"
        echo "$DEPLOY_OUTPUT"
        
        # Get the API Gateway URL (using awk since macOS grep doesn't support -P)
        API_URL=$(echo "$DEPLOY_OUTPUT" | awk '/HttpApiUrl:/ {print $2}')
        
        if [ -z "$API_URL" ]; then
            echo -e "${YELLOW}Warning: Could not automatically extract the API URL.${NC}"
            echo -e "${YELLOW}Please check the serverless info output below for the HttpApiUrl:${NC}"
            serverless info --verbose --stage prod
            
            # Try again with different approach
            API_URL=$(serverless info --verbose --stage prod | grep -A 10 endpoints | head -n 1 | sed -E 's/.*https/https/')
            
            if [ -z "$API_URL" ]; then
                # Prompt the user to enter the URL manually
                echo -e "${YELLOW}Could not detect API URL automatically. Please enter it manually:${NC}"
                read -p "API URL (from the output above): " API_URL
            fi
        fi
        
        echo -e "${GREEN}Backend API deployed to: ${API_URL}${NC}"
    fi
    
    # Deactivate the virtual environment
    deactivate
    
    # Clean up the temporary directory
    echo -e "${YELLOW}Cleaning up temporary deployment directory...${NC}"
    rm -rf "${TEMP_PKG_DIR}"
    
    # Go back to the backend directory
    cd - >/dev/null
    
    # Go back to main directory
    cd ..
    
    # Create environment file for frontend with API URL
    echo -e "${GREEN}Creating frontend environment file...${NC}"
    cat > frontend/.env.production << EOL
REACT_APP_API_URL=${API_URL}
EOL

    # Install and build frontend
    echo -e "${GREEN}Building frontend...${NC}"
    cd frontend || { echo -e "${RED}Error: Cannot find frontend directory.${NC}"; exit 1; }
    npm install
    npm run build
    
    # Check if API_URL is not empty before proceeding with S3/CloudFront deployment
    if [ -z "$API_URL" ]; then
        echo -e "${RED}Error: Failed to get API Gateway URL. S3 and CloudFront deployment will be skipped.${NC}"
        echo -e "${YELLOW}Please check the serverless deployment logs and try again.${NC}"
        exit 1
    fi

    # Create S3 bucket for frontend with additional error handling
    echo -e "${GREEN}Creating S3 bucket for frontend hosting...${NC}"
    aws s3 mb s3://${S3_BUCKET_NAME} --region ${AWS_REGION} || {
        echo -e "${RED}Error: Failed to create S3 bucket. Check your AWS permissions.${NC}"
        echo -e "${YELLOW}Your IAM user needs s3:CreateBucket permission.${NC}"
        exit 1
    }

    # Configure bucket for website hosting
    aws s3 website s3://${S3_BUCKET_NAME} --index-document index.html --error-document index.html || {
        echo -e "${RED}Error: Failed to configure S3 bucket for static website hosting.${NC}"
        exit 1
    }

    # Set bucket policy to allow public read access
    echo -e "${GREEN}Setting bucket policy for public access...${NC}"
    cat > bucket-policy.json << EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*"
    }
  ]
}
EOL

    aws s3api put-bucket-policy --bucket ${S3_BUCKET_NAME} --policy file://bucket-policy.json || {
        echo -e "${RED}Error: Failed to set bucket policy.${NC}"
        exit 1
    }

    # Upload frontend build to S3
    echo -e "${GREEN}Uploading frontend build to S3...${NC}"
    aws s3 sync build/ s3://${S3_BUCKET_NAME}/ --delete || {
        echo -e "${RED}Error: Failed to upload frontend build to S3.${NC}"
        exit 1
    }

    # Create CloudFront distribution for frontend with additional error handling
    echo -e "${GREEN}Creating CloudFront distribution...${NC}"
    DISTRIBUTION_CONFIG=$(cat << EOL
{
  "CallerReference": "${RANDOM_STRING}",
  "Aliases": {
    "Quantity": 0
  },
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-${S3_BUCKET_NAME}",
        "DomainName": "${S3_BUCKET_NAME}.s3.amazonaws.com",
        "OriginPath": "",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-${S3_BUCKET_NAME}",
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "ViewerProtocolPolicy": "redirect-to-https",
    "MinTTL": 0,
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["HEAD", "GET"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["HEAD", "GET"]
      }
    },
    "SmoothStreaming": false,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "Compress": true
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "Comment": "Task Management System Frontend",
  "Enabled": true,
  "PriceClass": "PriceClass_100"
}
EOL
)

    # Create CloudFront distribution using the configuration
    CLOUDFRONT_RESULT=$(aws cloudfront create-distribution --distribution-config "${DISTRIBUTION_CONFIG}" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create CloudFront distribution.${NC}"
        echo -e "${RED}${CLOUDFRONT_RESULT}${NC}"
        echo -e "${YELLOW}Your IAM user needs cloudfront:CreateDistribution permission.${NC}"
        DISTRIBUTION_ID=""
        CLOUDFRONT_DOMAIN=""
        
        echo -e "${YELLOW}Skipping CloudFront setup. You can still access the app via S3 website URL.${NC}"
    else
        DISTRIBUTION_ID=$(echo "$CLOUDFRONT_RESULT" | grep -o '"Id": "[^"]*' | cut -d'"' -f4)
        CLOUDFRONT_DOMAIN=$(echo "$CLOUDFRONT_RESULT" | grep -o '"DomainName": "[^"]*' | cut -d'"' -f4)
    fi

    echo -e "${GREEN}Serverless deployment completed!${NC}"
    if [ -n "$CLOUDFRONT_DOMAIN" ]; then
        echo -e "${GREEN}Frontend: https://${CLOUDFRONT_DOMAIN}${NC}"
    fi
    echo -e "${GREEN}Backend API: ${API_URL}${NC}"
    echo -e "${GREEN}API Documentation: ${API_URL}/docs${NC}"
    echo -e ""
    
    if [ -n "$CLOUDFRONT_DOMAIN" ]; then
        echo -e "${YELLOW}Note: CloudFront distribution may take up to 15 minutes to fully deploy.${NC}"
    fi
    echo -e "${YELLOW}In the meantime, you can also access the app directly via S3: http://${S3_BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com${NC}"
    echo -e ""
    echo -e "${GREEN}Resource IDs (save these for future reference):${NC}"
    echo -e "S3 Bucket: ${S3_BUCKET_NAME}"
    if [ -n "$DISTRIBUTION_ID" ]; then
        echo -e "CloudFront Distribution ID: ${DISTRIBUTION_ID}"
    fi
    echo -e "API Name: ${API_NAME}"
fi 