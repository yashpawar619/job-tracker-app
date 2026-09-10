# ============================================================
# deploy.ps1 — Deploy Java app to GKE via Helm
# ============================================================
# Runs helm upgrade --install (idempotent — install or upgrade).
# ⚠️ Pods + LoadBalancer start billing once deployed.
# ============================================================

$ErrorActionPreference = "Stop"

# ===== Config =====
$RELEASE_NAME = "java-app"
$NAMESPACE    = "production"                 # MVP: single namespace
# Anchored to this script's own folder via $PSScriptRoot, so the script works no
# matter which directory you invoke it from.
$CHART_PATH   = Join-Path $PSScriptRoot "..\helm\java-app"
$VALUES_FILE  = Join-Path $PSScriptRoot "..\helm\java-app\values.yaml"

# ===== Verify cluster connection =====
Write-Host "`n[1/4] Verifying cluster connection" -ForegroundColor Cyan
# kubectl writes progress/errors to stderr. In Windows PowerShell 5.1, redirecting a
# native command's stderr while $ErrorActionPreference is 'Stop' turns that text into a
# terminating error, which would bypass the $LASTEXITCODE check below.
& { $ErrorActionPreference = 'Continue'; kubectl cluster-info 2>$null }
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Not connected to a cluster. Run create-cluster.ps1 first." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Connected" -ForegroundColor Green

# ===== Create namespace if missing (idempotent) =====
Write-Host "`n[2/4] Ensuring namespace: $NAMESPACE" -ForegroundColor Cyan
& { $ErrorActionPreference = 'Continue'; kubectl get namespace $NAMESPACE 2>$null }
if ($LASTEXITCODE -ne 0) {
    kubectl create namespace $NAMESPACE
    Write-Host "  ✓ Namespace created" -ForegroundColor Green
} else {
    Write-Host "  ✓ Namespace exists" -ForegroundColor Yellow
}

# ===== Lint chart before deploying =====
Write-Host "`n[3/4] Linting chart" -ForegroundColor Cyan
helm lint $CHART_PATH
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Chart has errors. Fix before deploying." -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Chart valid" -ForegroundColor Green

# ===== Deploy =====
Write-Host "`n[4/4] Deploying release: $RELEASE_NAME" -ForegroundColor Cyan
# Secrets come from the environment so they never land in git.
# Set them once per shell before deploying:
#   $env:DB_PASSWORD = "..."
#   $env:JWT_SECRET  = "..."
if (-not $env:DB_PASSWORD) {
    Write-Host "  DB_PASSWORD env var not set." -ForegroundColor Red
    exit 1
}
if (-not $env:JWT_SECRET) {
    Write-Host "  JWT_SECRET env var not set." -ForegroundColor Red
    exit 1
}

# timeout 10m, not 5m: the startupProbe alone allows 300s (30 x 10s), and a
# cold image pull plus Autopilot scale-up runs past a 5m budget every time.
helm upgrade --install $RELEASE_NAME $CHART_PATH `
    --namespace $NAMESPACE `
    --values $VALUES_FILE `
    --set-string secrets.dbPassword=$env:DB_PASSWORD `
    --set-string secrets.jwtSecret=$env:JWT_SECRET `
    --wait `
    --timeout 10m

# helm's exit code must be checked explicitly: a failed release still leaves the
# script running, which previously printed "Deployed" over a failed install.
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n✗ Deploy failed (helm exit $LASTEXITCODE). Nothing is running." -ForegroundColor Red
    Write-Host "   helm list -n $NAMESPACE --all" -ForegroundColor White
    Write-Host "   kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp" -ForegroundColor White
    exit 1
}

Write-Host "`n✅ Deployed. Check status:" -ForegroundColor Green
Write-Host "   kubectl get pods -n $NAMESPACE" -ForegroundColor White
Write-Host "   kubectl get svc -n $NAMESPACE -w   (wait for EXTERNAL-IP)" -ForegroundColor White
Write-Host "`n   Once IP appears, test with:" -ForegroundColor Yellow
Write-Host "   curl http://<EXTERNAL-IP>/actuator/health" -ForegroundColor White