import os
import json
from datetime import datetime
import urllib.parse
from typing import Dict, List, Any, Optional
from bson import ObjectId
from pymongo import MongoClient, ReturnDocument
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# MongoDB connection
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017/task-management")

# Parse URI and extract database name or use default
if '/' in MONGO_URI.split('://')[-1]:
    # If URI contains a path (database name)
    client = MongoClient(MONGO_URI)
    # Get the database name from the URI
    db_name = urllib.parse.urlparse(MONGO_URI).path.strip('/')
    if not db_name:
        db_name = "task-management"  # Default database name
    db = client[db_name]
else:
    # If no database specified in URI, add default
    client = MongoClient(MONGO_URI)
    db = client["task-management"]  # Default database name

# Collections
tasks_collection = db.tasks
users_collection = db.users

# Function to get a collection by name
def get_collection(collection_name: str):
    """Get a MongoDB collection by name"""
    return db[collection_name]

# Custom JSON encoder for MongoDB ObjectId and datetime
class MongoJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, ObjectId):
            return str(obj)
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super(MongoJSONEncoder, self).default(obj)

# Database operations for tasks
class TasksRepository:
    @staticmethod
    def get_all() -> List[Dict[str, Any]]:
        """Get all tasks from the database"""
        return list(tasks_collection.find())
    
    @staticmethod
    def get_by_id(task_id: str) -> Optional[Dict[str, Any]]:
        """Get a task by ID"""
        if not ObjectId.is_valid(task_id):
            return None
        return tasks_collection.find_one({"_id": ObjectId(task_id)})
    
    @staticmethod
    def create(task_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new task"""
        # Set timestamps
        task_data["created_at"] = datetime.utcnow()
        task_data["updated_at"] = None
        
        # Insert and get the inserted document
        result = tasks_collection.insert_one(task_data)
        return {**task_data, "_id": result.inserted_id}
    
    @staticmethod
    def update(task_id: str, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update a task by ID"""
        if not ObjectId.is_valid(task_id):
            return None
        
        # Set updated timestamp
        update_data["updated_at"] = datetime.utcnow()
        
        # Update and return the updated document
        return tasks_collection.find_one_and_update(
            {"_id": ObjectId(task_id)},
            {"$set": update_data},
            return_document=ReturnDocument.AFTER
        )
    
    @staticmethod
    def delete(task_id: str) -> bool:
        """Delete a task by ID"""
        if not ObjectId.is_valid(task_id):
            return False
        
        result = tasks_collection.delete_one({"_id": ObjectId(task_id)})
        return result.deleted_count > 0

# Database operations for users
class UsersRepository:
    @staticmethod
    def get_by_email(email: str) -> Optional[Dict[str, Any]]:
        """Get a user by email"""
        return users_collection.find_one({"email": email})
    
    @staticmethod
    def create(user_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new user"""
        # Set timestamp
        user_data["created_at"] = datetime.utcnow()
        
        # Insert and get the inserted document
        result = users_collection.insert_one(user_data)
        return {**user_data, "_id": result.inserted_id}

# Initialize the database with default data if empty
def init_db():
    """Initialize the database with default data if collections are empty"""
    # Create default user if none exists
    if users_collection.count_documents({}) == 0:
        default_user = {
            "email": "admin@example.com",
            "username": "admin",
            "password": "password123",  # In a real app, this would be hashed
            "created_at": datetime.utcnow()
        }
        users_collection.insert_one(default_user)
        
    # Create default tasks if none exist
    if tasks_collection.count_documents({}) == 0:
        default_tasks = [
            {
                "title": "Implementar autenticación",
                "description": "Crear sistema de login y registro para los usuarios",
                "status": "completed",
                "created_at": datetime.utcnow(),
                "updated_at": None
            },
            {
                "title": "Diseñar interfaz de usuario",
                "description": "Crear diseños de UI/UX para la aplicación de gestión de tareas",
                "status": "in_progress",
                "created_at": datetime.utcnow(),
                "updated_at": None
            },
            {
                "title": "Configurar base de datos",
                "description": "Configurar MongoDB y crear schemas necesarios",
                "status": "todo",
                "created_at": datetime.utcnow(),
                "updated_at": None
            }
        ]
        tasks_collection.insert_many(default_tasks)

# Initialize the database when the module is imported
init_db() 