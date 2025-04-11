import json
from typing import Any, Dict, List, Optional, Union
from app.db import MongoJSONEncoder

def format_response(
    status_code: int, 
    body: Union[Dict[str, Any], List[Any], str], 
    headers: Optional[Dict[str, str]] = None
) -> Dict[str, Any]:
    """
    Format the Lambda response for API Gateway
    """
    # Default CORS headers
    default_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Credentials": "true",
        "Content-Type": "application/json"
    }
    
    # Merge with custom headers if provided
    response_headers = {**default_headers, **(headers or {})}
    
    # Convert body to JSON string if it's a dictionary or list
    if isinstance(body, (dict, list)):
        body = json.dumps(body, cls=MongoJSONEncoder)
    
    return {
        "statusCode": status_code,
        "headers": response_headers,
        "body": body
    }

def success_response(data: Any, status_code: int = 200) -> Dict[str, Any]:
    """
    Create a success response
    """
    return format_response(status_code, data)

def error_response(
    message: str, 
    status_code: int = 400, 
    error_code: Optional[str] = None
) -> Dict[str, Any]:
    """
    Create an error response
    """
    body = {
        "error": {
            "message": message
        }
    }
    
    if error_code:
        body["error"]["code"] = error_code
        
    return format_response(status_code, body)

def parse_event_body(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Parse the Lambda event body
    """
    body = event.get("body", "{}")
    
    if isinstance(body, str):
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return {}
    
    return body or {} 