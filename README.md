# Job Application Tracker

A Spring Boot REST API for tracking job applications — register, log in, record applications, track follow-ups, and view stats — packaged for deployment to Google Kubernetes Engine via Helm.

The repository is in two halves: **`java-app/`** is the application, **`java-app-infra/`** is everything needed to run it on GKE.

---

## Stack

| Layer | Choice |
|---|---|
| Language | Java 21 |
| Framework | Spring Boot 3.3.5 |
| Database | PostgreSQL 16, schema managed by Flyway |
| Auth | JWT (jjwt 0.12.6) over Spring Security |
| API docs | springdoc-openapi 2.6.0 (Swagger UI) |
| Observability | Actuator + Micrometer/Prometheus, JSON logs via logstash-logback |
| Tests | JUnit 5 + Testcontainers |
| Packaging | Multi-stage Docker build on Alpine |
| Deployment | Helm chart → GKE Autopilot |

---

## Repository layout

```
job-tracker-app/
├── java-app/                     Spring Boot application
│   ├── src/main/java/com/example/jobtracker/
│   │   ├── user/                 registration, login, JWT issuing
│   │   ├── job/                  job application CRUD, follow-ups, stats
│   │   ├── security/             JWT filter, Spring Security config
│   │   └── exception/            global exception handling
│   ├── src/main/resources/
│   │   ├── application.yml       base config, all values env-overridable
│   │   ├── application-dev.yml   local profile
│   │   ├── application-prod.yml  deployed profile
│   │   └── db/migration/         Flyway migrations (V1, V2)
│   ├── Dockerfile                multi-stage; runtime stage runs as non-root
│   └── docker-compose.yml        app + Postgres for local development
│
└── java-app-infra/
    ├── helm/java-app/            Helm chart
    │   ├── values.yaml           all configuration
    │   └── templates/            app, Postgres, Service, Ingress, PDB, cert
    └── scripts/                  PowerShell operational scripts
        ├── build-and-push.ps1    build image → Artifact Registry
        ├── create-cluster.ps1    provision GKE Autopilot cluster
        ├── deploy.ps1            helm upgrade --install
        └── teardown-cluster.ps1  delete everything, stop billing
```

---

## Part 1 — Run locally

### Prerequisites

- JDK 21
- Docker Desktop running

### Fastest path: Docker Compose

Brings up PostgreSQL and the app together, with the database health-gated so the app waits for it.

```bash
cd java-app
docker compose up --build
```

The API is at `http://localhost:8080`.

```bash
curl http://localhost:8080/actuator/health
```

Stop and reset, including the database volume:

```bash
docker compose down -v
```

### Running from your IDE

Start only the database:

```bash
cd java-app
docker compose up -d postgres
```

Then run the app with the `dev` profile:

```bash
./mvnw spring-boot:run              # macOS / Linux
.\mvnw.cmd spring-boot:run          # Windows
```

The defaults in `application.yml` point at `localhost:5432` with the credentials from `docker-compose.yml`, so no environment variables are needed for local work.

### Tests

```bash
./mvnw test
```

Integration tests use Testcontainers, which starts a real PostgreSQL container — Docker must be running.

---

## API

Interactive documentation at `http://localhost:8080/swagger-ui.html`.

### Public

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/auth/register` | Create an account, returns a JWT |
| `POST` | `/api/auth/login` | Authenticate, returns a JWT |

### Authenticated

All require `Authorization: Bearer <token>`.

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/applications` | Create an application |
| `GET` | `/api/applications` | List — paged, filterable |
| `GET` | `/api/applications/{id}` | Fetch one |
| `PUT` | `/api/applications/{id}` | Update |
| `DELETE` | `/api/applications/{id}` | Delete |
| `GET` | `/api/applications/follow-ups` | Follow-ups due today or earlier |
| `GET` | `/api/applications/stats` | Aggregate stats for the current user |

### Operational

| Path | Purpose |
|---|---|
| `/actuator/health` | Overall health |
| `/actuator/health/liveness` | Kubernetes liveness probe |
| `/actuator/health/readiness` | Readiness probe — includes a DB check |
| `/actuator/prometheus` | Metrics |

### Example

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"me@example.com","password":"correct-horse-battery"}' \
  | jq -r .token)

curl -X POST http://localhost:8080/api/applications \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"company":"Acme","position":"Backend Engineer","status":"APPLIED"}'
```

---

## Part 2 — Deploy to GKE

The chart deploys the app plus an in-cluster PostgreSQL StatefulSet backed by a PersistentVolumeClaim. It is self-contained — no managed database required.

> **Cost warning.** A GKE cluster with a LoadBalancer bills continuously. Tear down when you are done; see [Teardown](#teardown).

### Prerequisites

- `gcloud`, `kubectl`, `helm`
- `gke-gcloud-auth-plugin` — required since GKE 1.26:
  ```bash
  gcloud components install gke-gcloud-auth-plugin
  ```
- A GCP project with billing enabled
- Docker Desktop running (for the image build)

### 1. One-time GCP setup

```bash
gcloud init

gcloud services enable \
  container.googleapis.com artifactregistry.googleapis.com \
  compute.googleapis.com iam.googleapis.com

gcloud artifacts repositories create java-app-repo \
  --repository-format=docker --location=asia-south1
```

Grant the node service account permission to pull images. **This is required** — new projects no longer auto-grant `roles/editor` to the default compute service account, so without it every pod fails with `ImagePullBackOff` / 403:

```bash
PROJECT_NUMBER=$(gcloud projects describe <PROJECT_ID> --format='value(projectNumber)')

gcloud artifacts repositories add-iam-policy-binding java-app-repo \
  --location=asia-south1 \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

This binding is repo-level and survives cluster deletion — do it once.

### 2. Point the config at your project

Edit the project ID, region and repository in `java-app-infra/scripts/*.ps1`, and `image.repository` in `java-app-infra/helm/java-app/values.yaml`.

### 3. Build and push the image

```powershell
cd java-app-infra\scripts
.\build-and-push.ps1
```

### 4. Create the cluster

```powershell
.\create-cluster.ps1     # 5-10 minutes
kubectl get nodes        # must succeed before continuing
```

### 5. Deploy

Secrets are supplied at deploy time and are never committed. The chart **refuses to render** without them, so a deployment cannot silently fall back to the development JWT key in `application.yml`.

Set them and deploy **in the same shell** — environment variables do not cross terminal windows:

```powershell
$env:DB_PASSWORD = "<alphanumeric password>"
$env:JWT_SECRET  = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 48 | % {[char]$_})

.\deploy.ps1
```

Two constraints:

- **Alphanumeric only** — commas and braces break Helm's `--set` parser.
- **`JWT_SECRET` must be at least 32 characters** — HS256 requires a 256-bit key.

### 6. Verify

```powershell
kubectl get pods -n production
kubectl get svc  -n production     # wait for EXTERNAL-IP
```

```bash
curl http://<EXTERNAL-IP>/actuator/health
# {"status":"UP","groups":["liveness","readiness"]}
```

### Teardown

Order matters: `helm uninstall` releases the load balancer cleanly. Deleting the cluster first orphans forwarding rules that keep billing.

```powershell
helm uninstall java-app -n production
kubectl delete pvc -n production -l app.kubernetes.io/name=java-app-postgres
.\teardown-cluster.ps1
```

Helm does not delete volumes created from a `volumeClaimTemplate`, so the PVC step is required — the underlying disk otherwise survives cluster deletion and continues to bill.

Confirm nothing is left:

```bash
gcloud compute forwarding-rules list
gcloud compute addresses list
gcloud compute disks list
```

---

## Configuration

Every value is environment-overridable. Defaults are in `application.yml`; deployed values come from the Helm ConfigMap and Secret.

| Variable | Default | Notes |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `dev` | `prod` when deployed |
| `SERVER_PORT` | `8080` | |
| `DB_URL` | `jdbc:postgresql://localhost:5432/jobtracker` | ConfigMap in-cluster |
| `DB_USERNAME` | `jobtracker` | ConfigMap — not a secret on its own |
| `DB_PASSWORD` | `jobtracker` | **Secret.** Override in any shared environment |
| `JWT_SECRET` | dev-only key | **Secret.** Minimum 32 characters |
| `JWT_EXPIRATION_SECONDS` | `3600` | |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:8080` | |
| `DB_POOL_MAX` / `DB_POOL_MIN` | `10` / `2` | Hikari pool sizing |

The JWT default is a published placeholder and is safe only for local development.

### Helm values worth knowing

| Value | Default | Effect |
|---|---|---|
| `postgres.enabled` | `true` | Set `false` to use an external database |
| `service.type` | `LoadBalancer` | Set `ClusterIP` when using the Ingress |
| `ingress.enabled` | `false` | GCE HTTP(S) load balancer instead of a LoadBalancer Service |
| `managedCert.enabled` | `false` | Google-managed TLS; requires a real domain |
| `pdb.enabled` | `false` | Requires `replicaCount >= 2` |

The chart fails fast on misconfiguration — enabling the Ingress while `service.type` is still `LoadBalancer`, or a PodDisruptionBudget at one replica, produces an explanatory error at render time rather than a broken or double-billed deployment.

---

## Notes and limitations

This is a learning project deployed in a production-*leaning* shape, not a production system.

- **PostgreSQL runs in the cluster** with no backups and a single replica. A managed database is the right answer for real workloads.
- **Secrets are Kubernetes Secrets**, which are base64-encoded rather than encrypted, and Helm keeps a copy in its release history. Google Secret Manager with the Secrets Store CSI driver is the production pattern.
- **The database password is fixed at first startup.** PostgreSQL sets its superuser password when it initialises an empty volume, so changing it later requires deleting the PVC.
- **No TLS by default.** The Ingress and managed-certificate templates are written and validated but disabled; the default path serves plain HTTP.
- **Single replica**, no autoscaling.

---

## Licence

Unlicensed personal project.
