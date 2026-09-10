# ============================================================
# create-cluster.ps1 — Provision GKE Autopilot cluster
# ============================================================
# ⚠️  RUNNING THIS STARTS BILLING (pods billed when deployed).
#     The cluster control plane is FREE on Autopilot.
# Docs: https://cloud.google.com/kubernetes-engine/docs/how-to/creating-an-autopilot-cluster
# ============================================================

$ErrorActionPreference = "Stop"   # Stop on first error

# ===== Config — EDIT PROJECT_ID =====
$PROJECT_ID   = "java-app-prod"   # ⚠️ Replace with your project ID
$CLUSTER_NAME = "java-app-cluster"
$REGION       = "asia-south1"
$CHANNEL      = "regular"

# ===== Set active project =====
Write-Host "`n[1/3] Setting project to $PROJECT_ID" -ForegroundColor Cyan
gcloud config set project $PROJECT_ID

# ===== Check if cluster already exists (idempotent) =====
Write-Host "`n[2/3] Checking for existing cluster: $CLUSTER_NAME" -ForegroundColor Cyan

# gcloud writes status text to stderr. In Windows PowerShell 5.1, redirecting a native
# command's stderr while $ErrorActionPreference is 'Stop' turns that text into a
# terminating error, so relax it just for this call.
$existing = & { $ErrorActionPreference = 'Continue'
    gcloud container clusters list `
        --filter="name=$CLUSTER_NAME AND location=$REGION" `
        --format="value(name)" 2>$null }

if ($existing) {
    Write-Host "  ✓ Cluster '$CLUSTER_NAME' already exists in $REGION" -ForegroundColor Yellow
    Write-Host "  Skipping creation. To recreate, delete it first." -ForegroundColor Yellow
} else {
    Write-Host "  Creating Autopilot cluster (takes 5-10 min)..." -ForegroundColor Cyan

    gcloud container clusters create-auto $CLUSTER_NAME `
        --project=$PROJECT_ID `
        --region=$REGION `
        --release-channel=$CHANNEL `
        --network="default" `
        --subnetwork="default"

    Write-Host "  ✓ Cluster created" -ForegroundColor Green
}

# ===== Connect kubectl to the cluster =====
Write-Host "`n[3/3] Configuring kubectl credentials" -ForegroundColor Cyan

gcloud container clusters get-credentials $CLUSTER_NAME `
    --region=$REGION `
    --project=$PROJECT_ID

Write-Host "`n✅ Done. Verify with:" -ForegroundColor Green
Write-Host "   kubectl cluster-info" -ForegroundColor White
Write-Host "   kubectl get nodes" -ForegroundColor White
Write-Host "   kubectl get namespaces" -ForegroundColor White