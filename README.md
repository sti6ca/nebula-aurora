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
docker run --name nebula-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=nebula -p 5432:5432 -d postgres:15.5
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

1. **Build container image**
```bash
cd wiki-service && docker build -t fastapi:local .
```

2. **Create a network**

```bash
docker network create nebula-net
```

3. **Start postgres on that network**

```bash
docker run -d --name nebula-postgres --network nebula-net -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=nebula -e DATABASE_URL="postgresql+asyncpg://postgres:postgres@nebula:5432/nebula" postgres:15.5
```

5. **run your fastapi container on same network**

```bash
docker run -it --rm --name wiki --network nebula-net -e DATABASE_URL="postgresql+asyncpg://postgres:postgres@nebula-postgres:5432/nebula" -p 8000:8000 fastapi:local
```

## Helm steps

1. **Add repo for postgreSQL

```bash
helm repo add my-repo https://charts.bitnami.com/bitnami
```

2. **Install chart**

```bash
helm install postgresql-15.5.0 my-repo/postgresql
```

3. **To get the password for "postgres" run:**

```bash
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default postgresql-15-5-0 -o jsonpath="{.data.postgres-password}" | base64 -d)
```

4. **To connect to your database run the following command:**

```bash
kubectl run postgresql-15-5-0-client --rm --tty -i --restart='Never' --namespace default --image registry-1.docker.io/bitnami/postgresql:latest --env="PGPASSWORD=$POSTGRES_PASSWORD" \
 --command -- psql --host postgresql-15-5-0 -U postgres -d postgres -p 5432
```

**To connect to your database from outside the cluster execute the following commands:**

```bash
kubectl port-forward --namespace default svc/postgresql-15-5-0 5432:5432 &     PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```



## K8s Testing

1. **Check fastpi pod's logs**
```bash
kubectl logs pod/wiki-fastapi-<pod-id>
# Outputs below are good:
INFO:     10.1.0.1:49676 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.1:49692 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.1:33842 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.1:33852 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.1:33856 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.193:47302 - "GET /metrics HTTP/1.1" 200 OK
INFO:     10.1.0.1:57238 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.1:57246 - "GET / HTTP/1.1" 200 OK
INFO:     10.1.0.1:57252 - "GET / HTTP/1.1" 200 OK
```

2. **Port forward fastapi service**

```bash
kubectl port-forward svc/wiki-fastapi 8000:8000 > /tmp/wiki-pf.log 2>&1 & echo $! > /tmp/wiki-pf.pid
```

3. **Test the API**

```bash
sed 's|BASE_URL="http://localhost:8080"|BASE_URL="http://127.0.0.1:8000"|' wiki-service/test_api.sh | bash
```

Once the server is running, visit:

- Swagger UI: [`http://localhost:8000/docs`](http://localhost:8000/docs)
- ReDoc: [`http://localhost:8000/redoc`](http://localhost:8000/redoc)

4. **Access Grafana**
   
```bash
   kubectl port-forward svc/wiki-grafana 3000:3000
```

Then open: [`http://localhost:3000/grafana/d/creation-dashboard-678/creation`](http://localhost:3000/grafana/d/creation-dashboard-678/creation)

Login: admin / admin

5. Access Prometheus:
   ```bash
   kubectl port-forward svc/wiki-prometheus 9090:9090
   ```

Then open: [`http://localhost:9090`](http://localhost:9090)


## Uninstallation

To uninstall the chart:

```bash
helm uninstall wiki
```
