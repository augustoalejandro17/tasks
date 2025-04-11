import json
import pytest
from unittest.mock import patch, MagicMock
from datetime import datetime
from bson import ObjectId

# Import the handlers
from app.main import get_tasks, create_task, update_task, delete_task, login

# Sample data for tests
sample_task = {
    "_id": ObjectId("6093f3d5c2a23a001c1e2d47"),
    "title": "Test Task",
    "description": "This is a test task",
    "status": "todo",
    "created_at": datetime.utcnow(),
    "updated_at": None
}

sample_user = {
    "_id": ObjectId("6093f3d5c2a23a001c1e2d48"),
    "email": "test@example.com",
    "username": "testuser",
    "password": "password123",
    "created_at": datetime.utcnow()
}

valid_token = "Bearer valid.jwt.token"

# Fixtures
@pytest.fixture
def mock_auth():
    """Mock the authentication to always return the sample user"""
    with patch("app.auth.get_current_user") as mock_get_current_user:
        mock_get_current_user.return_value = {
            k: v for k, v in sample_user.items() if k != "password"
        }
        yield mock_get_current_user

@pytest.fixture
def mock_tasks_repo():
    """Mock the TasksRepository for tests"""
    with patch("app.main.TasksRepository") as mock_repo:
        yield mock_repo

# Tests for get_tasks
def test_get_tasks_success(mock_auth, mock_tasks_repo):
    # Setup
    mock_tasks_repo.get_all.return_value = [sample_task]
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        }
    }
    response = get_tasks(event, {})
    
    # Assertions
    assert response["statusCode"] == 200
    assert "task" in response["body"].lower()
    mock_tasks_repo.get_all.assert_called_once()

def test_get_tasks_unauthorized():
    # Call the handler without auth header
    event = {"headers": {}}
    response = get_tasks(event, {})
    
    # Assertions
    assert response["statusCode"] == 401
    assert "unauthorized" in response["body"].lower()

# Tests for create_task
def test_create_task_success(mock_auth, mock_tasks_repo):
    # Setup
    task_data = {
        "title": "New Task",
        "description": "A new task description",
        "status": "todo"
    }
    mock_tasks_repo.create.return_value = {**task_data, "_id": ObjectId()}
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        },
        "body": json.dumps(task_data)
    }
    response = create_task(event, {})
    
    # Assertions
    assert response["statusCode"] == 201
    mock_tasks_repo.create.assert_called_once()

def test_create_task_invalid_data(mock_auth, mock_tasks_repo):
    # Setup - missing required field
    task_data = {
        "description": "Missing title field"
    }
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        },
        "body": json.dumps(task_data)
    }
    response = create_task(event, {})
    
    # Assertions
    assert response["statusCode"] == 422
    assert "invalid" in response["body"].lower()
    mock_tasks_repo.create.assert_not_called()

# Tests for update_task
def test_update_task_success(mock_auth, mock_tasks_repo):
    # Setup
    task_id = str(sample_task["_id"])
    update_data = {
        "status": "in_progress"
    }
    updated_task = {
        **sample_task,
        "status": "in_progress",
        "updated_at": datetime.utcnow()
    }
    mock_tasks_repo.update.return_value = updated_task
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        },
        "pathParameters": {
            "id": task_id
        },
        "body": json.dumps(update_data)
    }
    response = update_task(event, {})
    
    # Assertions
    assert response["statusCode"] == 200
    mock_tasks_repo.update.assert_called_once_with(task_id, update_data)

def test_update_task_not_found(mock_auth, mock_tasks_repo):
    # Setup
    task_id = "nonexistent_id"
    update_data = {
        "status": "in_progress"
    }
    mock_tasks_repo.update.return_value = None
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        },
        "pathParameters": {
            "id": task_id
        },
        "body": json.dumps(update_data)
    }
    response = update_task(event, {})
    
    # Assertions
    assert response["statusCode"] == 404
    assert "not found" in response["body"].lower()

# Tests for delete_task
def test_delete_task_success(mock_auth, mock_tasks_repo):
    # Setup
    task_id = str(sample_task["_id"])
    mock_tasks_repo.delete.return_value = True
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        },
        "pathParameters": {
            "id": task_id
        }
    }
    response = delete_task(event, {})
    
    # Assertions
    assert response["statusCode"] == 200
    assert "deleted" in response["body"].lower()
    mock_tasks_repo.delete.assert_called_once_with(task_id)

def test_delete_task_not_found(mock_auth, mock_tasks_repo):
    # Setup
    task_id = "nonexistent_id"
    mock_tasks_repo.delete.return_value = False
    
    # Call the handler
    event = {
        "headers": {
            "Authorization": valid_token
        },
        "pathParameters": {
            "id": task_id
        }
    }
    response = delete_task(event, {})
    
    # Assertions
    assert response["statusCode"] == 404
    assert "not found" in response["body"].lower()

# Tests for login
def test_login_success():
    # Setup
    with patch("app.main.authenticate_user") as mock_auth:
        with patch("app.main.create_access_token") as mock_token:
            mock_auth.return_value = {k: v for k, v in sample_user.items() if k != "password"}
            mock_token.return_value = "jwt.token.here"
            
            # Call the handler
            event = {
                "body": json.dumps({
                    "email": "test@example.com",
                    "password": "password123"
                })
            }
            response = login(event, {})
            
            # Assertions
            assert response["statusCode"] == 200
            assert "token" in response["body"].lower()
            mock_auth.assert_called_once_with("test@example.com", "password123")

def test_login_invalid_credentials():
    # Setup
    with patch("app.main.authenticate_user") as mock_auth:
        mock_auth.return_value = None
        
        # Call the handler
        event = {
            "body": json.dumps({
                "email": "test@example.com",
                "password": "wrong_password"
            })
        }
        response = login(event, {})
        
        # Assertions
        assert response["statusCode"] == 401
        assert "invalid credentials" in response["body"].lower() 