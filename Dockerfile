# ---------- Stage 1: Builder ----------
FROM python:3.12-slim AS builder

# Prevent Python from writing .pyc files (reduces image size)
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure Python output is unbuffered (better logging in containers)
ENV PYTHONUNBUFFERED=1

# Set working directory inside container
WORKDIR /app

# Copy dependency file into container
COPY app/requirements.txt .

# Install Python dependencies into a separate directory (/install)
# --root-user-action=ignore suppresses pip warning in Docker build
# --no-cache-dir reduces image size
RUN pip install --no-cache-dir --root-user-action=ignore --prefix=/install -r requirements.txt


# ---------- Stage 2: Runtime ----------
FROM python:3.12-slim

# Prevent Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure Python output is unbuffered
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Create non-root user and group for security best practices
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy installed Python packages from builder stage
# This keeps runtime image smaller and cleaner
COPY --from=builder /install /usr/local

# Copy application source code into container
COPY app/ .

# Set correct ownership for non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port (used by Kubernetes / Docker)
EXPOSE 8080

# Start application using Gunicorn WSGI server
# app:app → module:Flask_app_object
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
