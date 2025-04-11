from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, validator

# Task status enum values
TASK_STATUS = ["todo", "in_progress", "completed"]

class TaskBase(BaseModel):
    """Base Task model with common attributes"""
    title: str
    description: str
    status: str = "todo"

    @validator('status')
    def status_must_be_valid(cls, v):
        if v not in TASK_STATUS:
            raise ValueError(f'Status must be one of {TASK_STATUS}')
        return v

class TaskCreate(TaskBase):
    """Model for task creation"""
    pass

class TaskUpdate(BaseModel):
    """Model for task updates, all fields optional"""
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None

    @validator('status')
    def status_must_be_valid(cls, v):
        if v is not None and v not in TASK_STATUS:
            raise ValueError(f'Status must be one of {TASK_STATUS}')
        return v

class Task(TaskBase):
    """Full Task model with MongoDB ID"""
    id: str = Field(..., alias="_id")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True
        allow_population_by_field_name = True

class UserBase(BaseModel):
    """Base User model with common attributes"""
    email: str
    username: str

class UserCreate(UserBase):
    """Model for user creation with password"""
    password: str

class User(UserBase):
    """Full User model with MongoDB ID"""
    id: str = Field(..., alias="_id")
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        orm_mode = True
        allow_population_by_field_name = True

class LoginRequest(BaseModel):
    """Model for login requests"""
    email: str
    password: str

class TokenResponse(BaseModel):
    """Model for token response"""
    token: str
    user: User 