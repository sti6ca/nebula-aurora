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
curl -X POST "http://localhost:8000/users"
-H "Content-Type: application/json"
-d '{"name": "John Doe"}'
```

Create a post:

```bash
curl -X POST "http://localhost:8000/posts"
-H "Content-Type: application/json"
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

```json
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