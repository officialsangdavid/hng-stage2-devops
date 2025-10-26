# Blue/Green Deployment with Nginx (Auto-Failover + Manual Toggle)

## Overview

This project implements a Blue/Green deployment setup using Nginx as a reverse proxy and Docker Compose for orchestration. Two identical Node.js application containers — `blue` (active) and `green` (backup) — run behind Nginx. Nginx automatically routes requests to the active container and fails over to the backup container when the active one becomes unhealthy.

This setup supports:

* Automatic failover on errors or timeouts
* Manual toggling between Blue and Green
* Health checks and retries
* Transparent header forwarding (`X-App-Pool` and `X-Release-Id`)

## Project Structure

```
.
├── docker-compose.yml
├── .env.example
├── .env
├── nginx/
│   ├── nginx.conf.template
│   └── docker-entrypoint.sh
└── test-loop.sh
```

## 1. Environment Setup

### Step 1: Copy `.env.example` to `.env`

```bash
cp .env.example .env
```

### Step 2: Edit `.env`

Update the values based on your setup. Example:

```bash
BLUE_IMAGE=ghcr.io/hngprojects/blue-app:latest
GREEN_IMAGE=ghcr.io/hngprojects/green-app:latest
ACTIVE_POOL=blue
RELEASE_ID_BLUE=1.0.0-blue
RELEASE_ID_GREEN=1.0.0-green
PORT=8080
```

* `ACTIVE_POOL` defines which version (blue or green) is live initially.
* The other variables are used by Docker Compose and Nginx templates.

## 2. Starting the Application

Start all services in the background:

```bash
docker compose up -d
```

Check that the containers are running:

```bash
docker ps
```

Expected containers:

```
nginx
app_blue
app_green
```

## 3. Verifying Blue (Active) Service

Run the following command to confirm the Blue service is active:

```bash
curl -i http://localhost:8080/version
```

Expected response headers:

```
HTTP/1.1 200 OK
X-App-Pool: blue
X-Release-Id: 1.0.0-blue
```

All requests should return status `200` and reference the Blue pool.

## 4. Testing Automatic Failover

### Step 1: Simulate a Failure on Blue

Trigger a simulated failure on Blue:

```bash
curl -X POST http://localhost:8081/chaos/start?mode=error
```

This causes Blue to start returning 5xx responses or timeouts.

### Step 2: Verify Nginx Failover to Green

Now send requests again via Nginx:

```bash
curl -i http://localhost:8080/version
```

Expected response headers:

```
HTTP/1.1 200 OK
X-App-Pool: green
X-Release-Id: 1.0.0-green
```

If you see this, Nginx has automatically switched traffic to the Green instance.

### Step 3: Verify Stability Under Failure

You can continuously monitor the switch using the test loop script:

```bash
chmod +x test-loop.sh
./test-loop.sh
```

In a separate terminal, trigger the failure again:

```bash
curl -X POST http://localhost:8081/chaos/start?mode=error
```

Observe that most responses (≥95%) come from the Green instance.

## 5. Recovering the Blue Service

Stop the simulated failure:

```bash
curl -X POST http://localhost:8081/chaos/stop
```

To manually switch back to Blue:

1. Edit `.env` and set:

   ```
   ACTIVE_POOL=blue
   ```
2. Reload Nginx:

   ```bash
   docker exec nginx nginx -s reload
   ```

## 6. Checking Direct Access to Blue and Green

You can directly test each container (useful for debugging):

```bash
curl http://localhost:8081/version   # Blue
curl http://localhost:8082/version   # Green
```

Both should return their own `X-App-Pool` and `X-Release-Id` values.

## 7. Stopping the Setup

To bring down the containers and clean up:

```bash
docker compose down
```

To remove volumes and networks completely:

```bash
docker compose down -v --rmi all --remove-orphans
```

## 8. .gitignore Setup

It’s best practice to exclude your `.env` file from version control. Run this command to append it to `.gitignore`:

```bash
echo ".env" >> .gitignore
```

Verify:

```bash
cat .gitignore
```

You should see `.env` listed.

## 9. File Permissions

Ensure the Nginx entrypoint script is executable:

```bash
chmod +x nginx/docker-entrypoint.sh
```

## 10. Useful Commands Summary

| Action                  | Command                                                     |
| ----------------------- | ----------------------------------------------------------- |
| Start all containers    | `docker compose up -d`                                      |
| View logs               | `docker compose logs -f`                                    |
| Stop containers         | `docker compose down`                                       |
| Reload Nginx config     | `docker exec nginx nginx -s reload`                         |
| Trigger chaos (failure) | `curl -X POST http://localhost:8081/chaos/start?mode=error` |
| Stop chaos              | `curl -X POST http://localhost:8081/chaos/stop`             |
| Test version endpoint   | `curl -i http://localhost:8080/version`                     |
| Direct access (Blue)    | `curl -i http://localhost:8081/version`                     |
| Direct access (Green)   | `curl -i http://localhost:8082/version`                     |

## 11. Troubleshooting

**Q: Nginx doesn’t failover to Green?**

* Make sure timeouts and retries are correctly configured in `nginx.conf.template`.
* Check container health with:

  ```bash
  docker inspect --format='{{json .State.Health}}' app_blue
  ```

**Q: Nginx not loading .env changes?**

* Run:

  ```bash
  docker compose down
  docker compose up -d --build
  ```

## 12. Expected Behavior Summary

| Scenario              | Expected Outcome                                         |
| --------------------- | -------------------------------------------------------- |
| Normal operation      | Requests return `200` with `X-App-Pool: blue`            |
| Blue failure          | Automatic switch to `green`                              |
| Green active manually | Set `ACTIVE_POOL=green` and reload Nginx                 |
| Failover recovery     | No failed requests during switch                         |
| Header forwarding     | `X-App-Pool` and `X-Release-Id` visible in all responses |

## 13. Credits

Developed as part of HNG DevOps Intern Stage 2 Task — Blue/Green Deployment with Nginx Auto-Failover.

