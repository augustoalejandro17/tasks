import os
import jwt
import json
from datetime import datetime, timedelta
from typing import Dict, Optional, Any
import hashlib

from app.db import UsersRepository

# Environment variables
JWT_SECRET = os.environ.get("JWT_SECRET", "your-secret-key-for-development")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION = 24  # hours

def create_access_token(data: Dict[str, Any]) -> str:
    """
    Create a JWT access token
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Verify a JWT token and return payload if valid
    """
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.PyJWTError:
        return None

def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode a JWT token and return the payload
    """
    return verify_token(token)

def get_password_hash(password: str) -> str:
    """
    Create a simple password hash (for demo purposes)
    In a real application, use a proper hashing library like bcrypt
    """
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a password against a hash (for demo purposes)
    In a real application, use a proper hashing library like bcrypt
    """
    return get_password_hash(plain_password) == hashed_password

def authenticate_user(email: str, password: str) -> Optional[Dict[str, Any]]:
    """
    Authenticate a user with email and password
    
    Note: In a production system, you would hash passwords
    """
    # Bypass authentication - create a user object for any input
    # The email includes '@backend' as requested
    return {
        "_id": "bypass_auth_user",
        "email": email if '@' in email else email + "@backend",
        "username": email.split('@')[0] if '@' in email else email,
        "role": "user"
    }

def get_current_user(authorization: str) -> Optional[Dict[str, Any]]:
    """
    Get the current user from the authorization header
    """
    # Bypass authorization validation - return a default user
    # This ensures any token will work
    return {
        "_id": "bypass_auth_user",
        "email": "user@backend",
        "username": "user",
        "role": "user"
    } 