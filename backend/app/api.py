from fastapi import FastAPI, Request, Response, HTTPException, Depends, Header, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html
from typing import Optional, Dict, Any, List
import json
import os

from app.db import MongoJSONEncoder, get_collection
from app.main import get_tasks, create_task, update_task, delete_task, login as login_handler
from app.auth import get_current_user
from app.models import TaskCreate, TaskUpdate, Task, LoginRequest, TokenResponse

# Create FastAPI app
app = FastAPI(
    title="Task Management API",
    description="API for managing development team tasks. Allows creating, updating, deleting, and listing tasks with different statuses.",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Configure CORS - Allow all origins or use specific ones from environment
# This works for both local Docker and serverless environments
origins = os.environ.get("ALLOWED_ORIGINS", "*")
if origins == "*":
    # If wildcard is specified, use a list with just the wildcard
    origins_list = ["*"]
else:
    # Otherwise, split the comma-separated list of allowed origins
    origins_list = origins.split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Helper function to convert Lambda response to FastAPI response
def lambda_to_fastapi(lambda_response: Dict[str, Any]) -> Response:
    status_code = lambda_response.get("statusCode", 200)
    body = lambda_response.get("body", "{}")
    
    if isinstance(body, str):
        try:
            body_dict = json.loads(body)
            return Response(
                content=json.dumps(body_dict),
                status_code=status_code,
                media_type="application/json"
            )
        except json.JSONDecodeError:
            return Response(
                content=body,
                status_code=status_code
            )
    
    return Response(
        content=json.dumps(body, cls=MongoJSONEncoder),
        status_code=status_code,
        media_type="application/json"
    )

# Routes with improved documentation
@app.get(
    "/api/tasks", 
    summary="Get all tasks", 
    description="Returns a list of all tasks available in the system",
    response_description="List of existing tasks",
    tags=["Tasks"]
)
async def api_get_tasks(request: Request) -> Response:
    """
    Gets all tasks stored in the database.
    
    Requires authentication via JWT token in the Authorization header.
    """
    lambda_event = {
        "headers": dict(request.headers),
        "queryStringParameters": dict(request.query_params),
    }
    lambda_response = get_tasks(lambda_event, {})
    return lambda_to_fastapi(lambda_response)

@app.post(
    "/api/tasks", 
    summary="Create a new task", 
    description="Creates a new task with the provided data",
    response_description="Task created with its assigned ID",
    tags=["Tasks"],
    status_code=201
)
async def api_create_task(
    request: Request, 
    task_data: TaskCreate = Body(..., description="Data for the task to create")
) -> Response:
    """
    Creates a new task in the system.
    
    Requires authentication via JWT token in the Authorization header.
    """
    body = await request.json()
    lambda_event = {
        "headers": dict(request.headers),
        "body": json.dumps(body)
    }
    lambda_response = create_task(lambda_event, {})
    return lambda_to_fastapi(lambda_response)

@app.put(
    "/api/tasks/{task_id}", 
    summary="Update an existing task",
    description="Updates the data of a specific task by its ID",
    response_description="Task updated with the new data",
    tags=["Tasks"]
)
async def api_update_task(
    task_id: str, 
    request: Request,
    task_data: TaskUpdate = Body(..., description="Data to update for the task")
) -> Response:
    """
    Updates an existing task identified by its ID.
    
    Requires authentication via JWT token in the Authorization header.
    """
    body = await request.json()
    lambda_event = {
        "headers": dict(request.headers),
        "pathParameters": {"id": task_id},
        "body": json.dumps(body)
    }
    lambda_response = update_task(lambda_event, {})
    return lambda_to_fastapi(lambda_response)

@app.delete(
    "/api/tasks/{task_id}", 
    summary="Delete a task",
    description="Permanently deletes a task by its ID",
    response_description="Deletion confirmation",
    tags=["Tasks"]
)
async def api_delete_task(
    task_id: str, 
    request: Request
) -> Response:
    """
    Deletes an existing task identified by its ID.
    
    Requires authentication via JWT token in the Authorization header.
    """
    lambda_event = {
        "headers": dict(request.headers),
        "pathParameters": {"id": task_id}
    }
    lambda_response = delete_task(lambda_event, {})
    return lambda_to_fastapi(lambda_response)

@app.get(
    "/api/tasks/statistics", 
    summary="Get task statistics",
    description="Returns the number of tasks by status",
    response_description="Task statistics by status",
    tags=["Tasks"]
)
async def api_get_task_statistics(request: Request) -> Dict[str, int]:
    """
    Gets statistics of tasks grouped by status.
    """
    try:
        # Get database connection
        tasks_collection = get_collection("tasks")
        
        # Count tasks by status
        todo_count = await tasks_collection.count_documents({"status": "todo"})
        in_progress_count = await tasks_collection.count_documents({"status": "in_progress"})
        completed_count = await tasks_collection.count_documents({"status": "completed"})
        
        # Return statistics
        return {
            "todo": todo_count,
            "inProgress": in_progress_count,
            "completed": completed_count
        }
    except Exception as e:
        # Return empty statistics if there's an error
        return {
            "todo": 0,
            "inProgress": 0,
            "completed": 0
        }

@app.post(
    "/api/auth/login", 
    summary="Login",
    description="Authenticates the user and returns a JWT token",
    response_description="Access token and user data",
    response_model=TokenResponse,
    tags=["Authentication"]
)
async def api_login(
    request: Request,
    credentials: LoginRequest = Body(..., description="User credentials")
) -> Response:
    """
    Authenticates the user with email and password, returning a JWT token.
    """
    body = await request.json()
    lambda_event = {
        "body": json.dumps(body)
    }
    lambda_response = login_handler(lambda_event, {})
    return lambda_to_fastapi(lambda_response)

# Health check endpoint
@app.get(
    "/health",
    summary="Health check",
    description="Verifies that the API is working properly",
    tags=["System"]
)
async def health() -> Dict[str, str]:
    """
    Health check endpoint for monitoring.
    """
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3001) 