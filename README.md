# User and Post API

A FastAPI service with SQLAlchemy for managing users and posts.

## Features

- Create and retrieve users
- Create and retrieve posts
- Async database operations with SQLAlchemy
- Input validation with Pydantic
- SQLite database (easily configurable to PostgreSQL)
- Prometheus metrics for monitoring

## Installation

1. Install dependencies:

    ```bash
    pip install -r requirements.txt
    ```

## Running the Service

Start the server:

```bash
python -m uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`.

## API Documentation

Once the server is running, visit:

- Swagger UI: [`http://localhost:8000/docs`](http://localhost:8000/docs)
- ReDoc: [`http://localhost:8000/redoc`](http://localhost:8000/redoc)

## API Endpoints

### POST /users

Create a new user.

**Request body:**

```json
{
"name": "John Doe"
}
```

**Response:**

```json
{
"id": 1,
"name": "John Doe",
"created_time": "2025-11-04T10:30:00"
}
```

### POST /posts

Create a new post under a given user.

**Request body:**

```json
{
"user_id": 1,
"content": "This is my first post!"
}
```

**Response:**

```json
{
"post_id": 1,
"content": "This is my first post!",
"user_id": 1,
"created_time": "2025-11-04T10:35:00"
}
```

### GET /user/{id}

Fetch a user by ID.

**Response:**

```json
{
"id": 1,
"name": "John Doe",
"created_time": "2025-11-04T10:30:00"
}
```

GET /posts/{id}

Fetch a post by ID.

**Response:**

```json
{
"post_id": 1,
"content": "This is my first post!",
"user_id": 1,
"created_time": "2025-11-04T10:35:00"
}
```

### GET /metrics

Prometheus metrics endpoint for monitoring.

**Exposed Metrics:**

```bash
- `users_created_total` — Counter tracking the total number of users created
- `posts_created_total` — Counter tracking the total number of posts created
```

**Response:**  

```bash
Prometheus text-based exposition format
```

## Example Usage with curl

Create a user:

```bash
curl -X POST "http://localhost:8000/users" \
-H "Content-Type: application/json" \
-d '{"name": "John Doe"}'
```

Create a post:

```bash
curl -X POST "http://localhost:8000/posts" \
-H "Content-Type: application/json" \
-d '{"user_id": 1, "content": "Hello, World!"}'
```

Get a user:

```bash
curl "http://localhost:8000/user/1"
```

Get a post:

```bash
curl "http://localhost:8000/posts/1"
```

Get Prometheus metrics:

```bash
curl "http://localhost:8000/metrics"
```

## Prometheus Metrics

The service exposes Prometheus metrics at the `/metrics` endpoint. These metrics can be scraped by a Prometheus server for monitoring and alerting.

**Available Metrics:**

```bash
- `users_created_total` — Total count of users created since the service started
- `posts_created_total` — Total count of posts created since the service started
```

**Example Prometheus Configuration:**

```yaml
scrape_configs:
  - job_name: "user_post_api"
    static_configs:
      - targets: ["localhost:8000"]
    metrics_path: "/metrics"
```

## Project Structure

```bash
.
├── app/
│ ├── init.py
│ ├── main.py # FastAPI application and endpoints
│ ├── models.py # SQLAlchemy models
│ ├── schemas.py # Pydantic schemas
│ └── database.py # Database configuration
├── requirements.txt # Python dependencies
└── README.md # This file
```

## Database

The service uses SQLite by default (`app.db` file).
To switch to PostgreSQL or another database:

1. Update `DATABASE_URL` in `app/database.py`
2. Install the appropriate database driver (e.g., `asyncpg` for PostgreSQL)
3. Update `requirements.txt` accordingly


### Start a local Postgres for testing

```bash
docker run --name nebula-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=nebula -p 5432:5432 -d postgres:16
```

### Export DB URL for your app

```bash
export DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/nebula"
```

### Install deps and run

```bash
pip3 install -r requirements.txt 
python -m uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```


## Running application as docker container

```bash
cd wiki-service && docker build -t fastapi:local .
```

**create a network**

```bash
docker network create nebula-net
```

**start postgres on that network**

```bash
docker run -d --name nebula-postgres --network nebula-net -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=nebula -e DATABASE_URL="postgresql+asyncpg://postgres:postgres@nebula:5432/nebula" postgres:15.5
```

**run your fastapi container on same network**

```bash
docker run -it --rm --name wiki --network nebula-net -e DATABASE_URL="postgresql+asyncpg://postgres:postgres@nebula-postgres:5432/nebula" -p 8000:8000 fastapi:local
```

## K8s steps

```bash
kubectl get configmaps -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels --no-headers | grep grafana-dashboards
```

```bash
kubectl get configmap hello-grafana-dashboards -o yaml
```

```bash
kubectl get pods -l app.kubernetes.io/name=grafana -o yaml
```

```bash
kubectl get pod hello-grafana-6cd4b4b6bb-q7vnd -o jsonpath='{.spec.containers[*].name}{"\n"}'
```

```yaml

name: grafana-sc-dashboard
name: grafana-sc-datasources
```
