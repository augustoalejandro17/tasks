import json
import os
from typing import Dict, Any, Optional
import uuid
from datetime import datetime
from app.db import TasksRepository, get_collection, MongoJSONEncoder
from app.models import TaskCreate, TaskUpdate
from app.auth import authenticate_user, create_access_token, get_current_user, decode_access_token, get_password_hash, verify_password
from app.utils import success_response, error_response, parse_event_body

def require_auth(func):
    """
    Decorator to require authentication for a Lambda function
    """
    def wrapper(event, context):
        # Get Authorization header from the event
        headers = event.get("headers", {})
        authorization = headers.get("Authorization") or headers.get("authorization")
        
        if not authorization:
            return error_response("Unauthorized: Missing authorization header", 401)
        
        # Get the current user
        user = get_current_user(authorization)
        if not user:
            return error_response("Unauthorized: Invalid token", 401)
        
        # Add the user to the event
        event["user"] = user
        
        # Call the original function
        return func(event, context)
    
    return wrapper

@require_auth
def get_tasks(event, context):
    """
    Get all tasks
    """
    try:
        tasks = TasksRepository.get_all()
        return success_response(tasks)
    except Exception as e:
        return error_response(f"Error retrieving tasks: {str(e)}", 500)

@require_auth
def create_task(event, context):
    """
    Create a new task
    """
    try:
        # Parse the request body
        body = parse_event_body(event)
        
        # Validate the task data
        try:
            task_data = TaskCreate(**body)
        except Exception as e:
            return error_response(f"Invalid task data: {str(e)}", 422)
        
        # Create the task
        task = TasksRepository.create(task_data.dict())
        
        return success_response(task, 201)
    except Exception as e:
        return error_response(f"Error creating task: {str(e)}", 500)

@require_auth
def update_task(event, context):
    """
    Update a task by ID
    """
    try:
        # Get the task ID from the path parameters
        path_parameters = event.get("pathParameters", {})
        task_id = path_parameters.get("id")
        
        if not task_id:
            return error_response("Task ID is required", 400)
        
        # Parse the request body
        body = parse_event_body(event)
        
        # Validate the update data
        try:
            update_data = TaskUpdate(**body)
        except Exception as e:
            return error_response(f"Invalid task data: {str(e)}", 422)
        
        # Remove None values from the update data
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        
        # Update the task
        task = TasksRepository.update(task_id, update_dict)
        
        if not task:
            return error_response(f"Task with ID {task_id} not found", 404)
        
        return success_response(task)
    except Exception as e:
        return error_response(f"Error updating task: {str(e)}", 500)

@require_auth
def delete_task(event, context):
    """
    Delete a task by ID
    """
    try:
        # Get the task ID from the path parameters
        path_parameters = event.get("pathParameters", {})
        task_id = path_parameters.get("id")
        
        if not task_id:
            return error_response("Task ID is required", 400)
        
        # Delete the task
        success = TasksRepository.delete(task_id)
        
        if not success:
            return error_response(f"Task with ID {task_id} not found", 404)
        
        return success_response({"message": "Task deleted successfully"})
    except Exception as e:
        return error_response(f"Error deleting task: {str(e)}", 500)

def login(event, context):
    """
    Authenticate a user and return a JWT token
    """
    try:
        # Parse the request body
        body = parse_event_body(event)
        
        # Get the email and password
        email = body.get("email")
        password = body.get("password")
        
        if not email or not password:
            return error_response("Email and password are required", 400)
        
        # Authenticate the user
        user = authenticate_user(email, password)
        
        if not user:
            return error_response("Invalid credentials", 401)
        
        # Create access token
        token = create_access_token({"sub": user["email"]})
        
        return success_response({
            "token": token,
            "user": user
        })
    except Exception as e:
        return error_response(f"Error during login: {str(e)}", 500)

# Add health check handler for API connectivity testing
def health_check(event, context) -> Dict[str, Any]:
    """
    Health check endpoint to verify API connectivity
    """
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Credentials': True,
        },
        'body': json.dumps({
            'status': 'healthy',
            'environment': os.environ.get('STAGE', 'development'),
            'timestamp': datetime.utcnow().isoformat()
        }, cls=MongoJSONEncoder)
    } 