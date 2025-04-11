FROM python:3.9-alpine

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    python3-dev

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt && \
    apk del .build-deps

# Copy application code
COPY . .

# Create non-root user
RUN adduser -D appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 3001

# Command to run the application
CMD ["python", "-m", "uvicorn", "app.api:app", "--host", "0.0.0.0", "--port", "3001"] 