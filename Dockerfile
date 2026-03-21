FROM python:3.12-slim

# Prevent Python from writing .pyc files (reduces container size)
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure Python output is sent straight to terminal (no buffering)
ENV PYTHONUNBUFFERED=1

# Set working directory inside the container
WORKDIR /app

# Create a non-root user and group for security best practices
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy Python dependencies file into the container
COPY app/requirements.txt .

# Install Python dependencies without caching (reduces image size)
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code into the container
COPY app/ .

# Change ownership of application files to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user for running the application (security)
USER appuser

# Expose application port (used by Kubernetes/containers)
EXPOSE 8080

# Start the application using Gunicorn WSGI server
# Binds to all interfaces on port 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
