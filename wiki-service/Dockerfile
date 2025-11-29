FROM python:3.13-slim

# Set working dir
WORKDIR /app

# Install system deps for building Python pkgs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Install uv
RUN pip install --no-cache-dir uv

# Copy deps
COPY pyproject.toml uv.lock .

# Install deps
RUN uv pip install --system .

# Copy app code
COPY app/ ./app

# Expose port
EXPOSE 8000

# Start app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

