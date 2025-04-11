# AWS Deployment Guide

This guide explains how to deploy the task management system in AWS, using free or low-cost services.

## Prerequisites

- AWS account
- AWS CLI installed and configured (`aws configure`)
- Docker and Docker Compose installed
- (Optional) ECS CLI for advanced deployment

## Deployment Structure

The system is deployed as a containerized application in AWS ECS (Elastic Container Service) with three main components:

1. **Frontend**: Container with Nginx serving the React application
2. **Backend**: Container with the Python/FastAPI API
3. **Database**: MongoDB container for persistent storage

## Deployment Options

There are two main ways to deploy the application:

### 1. Automated Deployment (Recommended)

Use the `deploy.sh` script included in the project for an automated deployment:

```bash
# Make the script executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

The script:
1. Verifies the prerequisites
2. Builds the Docker images
3. Allows testing the application locally
4. Uploads the images to Amazon ECR
5. Creates an ECS cluster with Fargate
6. Deploys the application and provides the URL

### 2. Manual Deployment

If you prefer a step-by-step approach:

#### Step 1: Build Docker Images

```bash
# Build all images
docker compose build
```

#### Step 2: Test Locally

```bash
# Start the application locally
docker compose up -d

# Verify that everything works at:
# - Frontend: http://localhost
# - Backend: http://localhost:3001
# - API Docs: http://localhost:3001/api/docs

# Stop the application
docker compose down
```

#### Step 3: Create ECR Repositories

```bash
# Create repositories for the images
aws ecr create-repository --repository-name task-management-frontend
aws ecr create-repository --repository-name task-management-backend
aws ecr create-repository --repository-name task-management-mongo
```

#### Step 4: Upload Images to ECR

```bash
# Authenticate to ECR
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com

# Tag images
docker tag task-management-frontend:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/task-management-frontend:latest
docker tag task-management-backend:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/task-management-backend:latest
docker tag mongo:5.0 <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/task-management-mongo:latest

# Push images
docker push <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/task-management-frontend:latest
docker push <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/task-management-backend:latest
docker push <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/task-management-mongo:latest
```

#### Step 5: Create ECS Cluster

You can create an ECS cluster from the AWS console or using the CLI:

```bash
aws ecs create-cluster --cluster-name task-management-cluster
```

#### Step 6: Create Task Definition and Service

Create a `task-definition.json` file and register the task definition:

```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

Then create an ECS service:

```bash
aws ecs create-service \
    --cluster task-management-cluster \
    --service-name task-management-service \
    --task-definition task-management:1 \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678],securityGroups=[sg-12345678],assignPublicIp=ENABLED}"
```

## Data Persistence

The MongoDB container uses a data volume for persistence. In ECS, you can:

1. **Basic Use**: Use an EFS (Elastic File System) volume for persistence
2. **Production**: Consider managed services such as Amazon DocumentDB (MongoDB compatible)

## Scaling and High Availability

For production environments, consider configuring:

1. **Auto-scaling**: Configure scaling policies based on CPU/memory
2. **Multiple zones**: Deploy across multiple availability zones
3. **Load Balancer**: Add an Application Load Balancer to distribute traffic

## Monitoring and Logs

- CloudWatch Logs for containers
- CloudWatch Metrics for performance metrics
- Alarms for notifications

## Cost Estimation (Free Tier)

- ECS with Fargate: 750 free runtime hours per month
- ECR: 500MB of free storage
- CloudWatch: 5GB of free logs and 10 custom metrics

The estimate for an application with moderate usage should stay within or close to the AWS free tier. 