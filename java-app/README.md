# Job Application Tracker

A production-leaning three-tier Spring Boot REST API for tracking job applications.
Built with GKE + Helm as the eventual deployment target.

## Stack

- Java 21, Spring Boot 3.3
- PostgreSQL 16 + Flyway migrations
- Spring Security + JWT (JJWT 0.12)
- Spring Data JPA
- OpenAPI / Swagger UI (`/swagger-ui.html`)
- Spring Boot Actuator (health, readiness, liveness, prometheus)
- Structured JSON logs in prod (logstash-logback-encoder)
- Testcontainers for integration tests
- Docker + docker-compose for local dev

## Architecture (three-tier)

```
Controller layer  →  Service layer  →  Repository layer  →  PostgreSQL
   (REST + DTOs)     (business rules)   (Spring Data JPA)
```

- **Presentation**: `job/JobApplicationController`, `user/AuthController`
- **Business**: `job/JobApplicationService`, `user/AuthService`
- **Data**: `job/JobApplicationRepository`, `user/UserRepository` + Flyway-managed schema

DTOs (records) sit at the controller boundary; entities never leak out.

## Run it locally

### Option A — Docker Compose (recommended)

```bash
docker compose up --build
```

App: <http://localhost:8080> · Swagger UI: <http://localhost:8080/swagger-ui.html>

### Option B — App locally, Postgres in Docker

```bash
docker compose up -d postgres
./mvnw spring-boot:run
```

### Try the API

```bash
# Register
curl -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"me@example.com","password":"hunter2hunter","displayName":"Me"}'
# → { "accessToken": "eyJ...", "tokenType": "Bearer", "expiresInSeconds": 3600 }

TOKEN="paste-token-here"

# Create an application
curl -X POST http://localhost:8080/api/applications \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"company":"Google","role":"SWE","status":"APPLIED","applicationDate":"2025-01-15"}'

# List / filter / search
curl -H "Authorization: Bearer $TOKEN" 'http://localhost:8080/api/applications?status=APPLIED'
curl -H "Authorization: Bearer $TOKEN" 'http://localhost:8080/api/applications?q=google'

# Stats
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/applications/stats
```

## Tests

```bash
./mvnw test
```

Integration tests spin up a real PostgreSQL container via Testcontainers, so Docker must be running.

## Environment variables

| Var | Default | Notes |
| --- | --- | --- |
| `SPRING_PROFILES_ACTIVE` | `dev` | Use `prod` for JSON logs |
| `DB_URL` | `jdbc:postgresql://localhost:5432/jobtracker` | |
| `DB_USERNAME` / `DB_PASSWORD` | `jobtracker` / `jobtracker` | |
| `JWT_SECRET` | (dev-only default) | **Must** be overridden in prod. Base64-encoded, ≥ 32 bytes. |
| `JWT_EXPIRATION_SECONDS` | `3600` | |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:8080` | Comma-separated |
| `SERVER_PORT` | `8080` | |
| `DB_POOL_MAX` / `DB_POOL_MIN` | `10` / `2` | HikariCP |

Generate a strong JWT secret:
```bash
openssl rand -base64 48
```

## Endpoints

- `POST /api/auth/register`, `POST /api/auth/login`
- `GET/POST /api/applications`, `GET/PUT/DELETE /api/applications/{id}`
- `GET /api/applications?status=INTERVIEW&q=google&page=0&size=20&sort=applicationDate,desc`
- `GET /api/applications/follow-ups`
- `GET /api/applications/stats`
- `GET /actuator/health/liveness`, `/actuator/health/readiness`, `/actuator/prometheus`

## What's production-quality here

Auth (BCrypt + JWT), per-user data isolation, Flyway migrations, validation on all inputs,
RFC 7807 problem-detail errors, pagination + sorting, JPA auditing, structured JSON logs,
Actuator liveness/readiness probes, graceful shutdown, connection-pool tuning, container-aware
JVM flags, non-root Docker user, multi-stage image, integration tests against real Postgres,
env-var config with no committed secrets.

## What's still missing for real production

Rate limiting, refresh tokens, email verification, password reset, CI/CD, HTTPS (handled by
ingress in k8s), secrets manager integration, real monitoring stack, backups. Straightforward
to bolt on when you need them.

## Next steps toward GKE + Helm

Suggested learning path:

1. **Push the image** to Artifact Registry: `gcloud builds submit --tag REGION-docker.pkg.dev/PROJECT/repo/job-tracker:0.1.0 .`
2. **Provision Postgres**: Cloud SQL for Postgres (production) or a Bitnami Helm chart (learning).
3. **Create a GKE Autopilot cluster**: cheapest way to start.
4. **Write the Helm chart**:
   - `templates/deployment.yaml` — image, resource requests/limits, env from `Secret` + `ConfigMap`, `livenessProbe: /actuator/health/liveness`, `readinessProbe: /actuator/health/readiness`
   - `templates/service.yaml` — ClusterIP
   - `templates/ingress.yaml` — GKE Ingress + managed cert
   - `templates/secret.yaml` — for `JWT_SECRET`, `DB_PASSWORD` (or better: External Secrets + Secret Manager)
   - `templates/hpa.yaml` — horizontal pod autoscaler on CPU + memory
5. **Wire up Cloud SQL** via Cloud SQL Auth Proxy sidecar or private-IP + VPC connector.
6. **Prometheus + Grafana** via `kube-prometheus-stack` Helm chart to scrape `/actuator/prometheus`.
7. **CI/CD**: GitHub Actions → build image → push → `helm upgrade`.

The app is already set up for all of this: liveness/readiness endpoints are separate, config is
env-driven, logs are JSON, metrics are on `/actuator/prometheus`, shutdown is graceful.
