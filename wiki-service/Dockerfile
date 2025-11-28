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
# Install deps
RUN pip install .
# Copy app code
COPY . .
# Expose port
EXPOSE 80000
# Start app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

