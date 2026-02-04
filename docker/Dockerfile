# =============================================================================
# DevOps Testing App - Production Dockerfile
# =============================================================================
# Multi-stage build for minimal image size and security
# Image: danielmazh/devops-testing-app
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Builder - Install dependencies
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------------------------------
# Stage 2: Production - Minimal runtime image
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS production

# Build arguments for labeling
ARG BUILD_DATE
ARG VERSION
ARG GIT_COMMIT

# Labels
LABEL maintainer="daniel.mazhbits@gmail.com" \
      version="${VERSION}" \
      build-date="${BUILD_DATE}" \
      git-commit="${GIT_COMMIT}" \
      description="DevOps Testing Application - Flask REST API"

# Security: Create non-root user
RUN groupadd --gid 1000 appgroup && \
    useradd --uid 1000 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY --chown=appuser:appgroup app/ ./app/
COPY --chown=appuser:appgroup main.py .
COPY --chown=appuser:appgroup calc.py .

# Environment configuration
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=main.py \
    FLASK_ENV=production \
    PORT=5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Switch to non-root user
USER appuser

# Expose port
EXPOSE ${PORT}

# Production server command (gunicorn with factory pattern)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--threads", "2", "--timeout", "120", "--access-logfile", "-", "--error-logfile", "-", "app:create_app()"]

# -----------------------------------------------------------------------------
# Stage 3: Development - Includes dev tools
# -----------------------------------------------------------------------------
FROM production AS development

USER root

# Install dev/test dependencies
RUN pip install --no-cache-dir \
    pytest \
    pytest-cov \
    pytest-html \
    flake8 \
    pylint

# Create directories for reports
RUN mkdir -p /app/reports /app/htmlcov && \
    chown -R appuser:appgroup /app/reports /app/htmlcov

USER appuser

ENV FLASK_ENV=development \
    FLASK_DEBUG=1

# Development runs Flask dev server
CMD ["python", "main.py"]

# -----------------------------------------------------------------------------
# Stage 4: Testing - For CI/CD pipeline
# -----------------------------------------------------------------------------
FROM development AS testing

USER root

# Copy test files
COPY --chown=appuser:appgroup tests/ ./tests/
COPY --chown=appuser:appgroup pytest.ini .

# Install additional test dependencies
RUN pip install --no-cache-dir \
    selenium \
    webdriver-manager \
    locust \
    requests

USER appuser

# Default command runs tests
CMD ["pytest", "tests/", "-v", "--cov=app", "--cov-report=html:htmlcov", "--cov-report=term-missing"]
