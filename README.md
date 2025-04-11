# Task Management System

A complete system for managing tasks with a React frontend and Python serverless backend.

## Project Structure

```
├── frontend/          # React application with Material UI
│   ├── src/           # React source code
│   ├── Dockerfile     # Docker configuration for frontend
│   └── nginx.conf     # Nginx configuration
│
├── backend/           # Python serverless API
│   ├── app/           # Application code
│   ├── tests/         # Unit tests
│   ├── Dockerfile     # Docker configuration for backend
│   └── serverless.yml # Configuration for AWS deployment
│
└── docker-compose.yml # Configuration for local execution
```

## Features

### Frontend (React)
- Modern and responsive user interface with Material UI
- User authentication
- Task listing, creation, updating, and deletion
- Statistics visualization with charts
- Unit tests with Testing Library

### Backend (Python Serverless)
- RESTful API developed with lambdas
- JWT Authentication
- CRUD operations for tasks
- MongoDB database
- Unit tests with Pytest

## Requirements

- Docker and Docker Compose
- Node.js 14+ (for development)
- Python 3.9+ (for development)
- MongoDB (for local development without Docker)
- AWS CLI (for deployment)

## Running locally

1. Clone the repository:
```bash
git clone https://github.com/your-username/task-management-system.git
cd task-management-system
```

2. Start the application with Docker Compose:
```bash
docker compose up -d
```

3. Access the application:
   - Frontend: http://localhost
   - Backend API: http://localhost:3001/api
   - API Docs: http://localhost:3001/docs

## Development

### Frontend

```bash
cd frontend
npm install
npm start
```

### Backend

```bash
cd backend
pip install -r requirements.txt
python -m uvicorn app.api:app --host 0.0.0.0 --port 3001 --reload
```

## AWS Deployment

### Using the deployment script

```bash
chmod +x deploy.sh
./deploy.sh
```

For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Tests

### Frontend
```bash
cd frontend
npm test
```

### Backend
```bash
cd backend
pytest
```

## Test User

- Email: admin@example.com
- Password: password123

## License

MIT 