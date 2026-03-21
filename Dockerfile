# ---------- Stage 1: Builder ----------
FROM python:3.12-slim AS builder

# Prevent Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure Python output is unbuffered
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install dependencies into a separate location
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---------- Stage 2: Runtime ----------
FROM python:3.12-slim

# Prevent Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1

# Ensure Python output is unbuffered
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Create non-root user and group
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy installed Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy application source code
COPY app/ .

# Set proper ownership
RUN chown -R appuser:appgroup /app

# Run container as non-root user
USER appuser

# Expose application port
EXPOSE 8080

# Start application with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
