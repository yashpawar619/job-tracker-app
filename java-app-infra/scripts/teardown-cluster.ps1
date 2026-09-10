# ============================================================
# teardown-cluster.ps1 — Remove resources to stop billing
# ============================================================
# Uninstalls the app, then deletes the cluster.
# Run at the END of every test session to save cost.
# ============================================================

$ErrorActionPreference = "Continue"   # Keep going even if a step fails

# ===== Config =====
$PROJECT_ID   = "java-app-prod"   # ⚠️ Your project ID
$CLUSTER_NAME = "java-app-cluster"
$REGION       = "asia-south1"
$RELEASE_NAME = "java-app"
$NAMESPACE    = "production"

Write-Host "`n⚠️  TEARDOWN — this will delete your deployment and cluster" -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to continue"
if ($confirm -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Red
    exit 0
}

# ===== Step 1: Uninstall Helm release (removes pods + LoadBalancer) =====
Write-Host "`n[1/3] Uninstalling Helm release: $RELEASE_NAME" -ForegroundColor Cyan
helm uninstall $RELEASE_NAME --namespace $NAMESPACE 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Release uninstalled (LoadBalancer being removed)" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Release not found or already removed" -ForegroundColor Yellow
}

# Give GCP time to release the LoadBalancer (avoids orphaned IP charges)
Write-Host "  Waiting 30s for LoadBalancer cleanup..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# ===== Step 2: Delete the cluster =====
Write-Host "`n[2/3] Deleting cluster: $CLUSTER_NAME" -ForegroundColor Cyan
Write-Host "  This takes 3-5 min..." -ForegroundColor Cyan

gcloud container clusters delete $CLUSTER_NAME `
    --region=$REGION `
    --project=$PROJECT_ID `
    --quiet

Write-Host "  ✓ Cluster deleted" -ForegroundColor Green

# ===== Step 3: Verify no orphaned LoadBalancers =====
Write-Host "`n[3/3] Checking for orphaned load balancers" -ForegroundColor Cyan
$orphans = gcloud compute forwarding-rules list `
    --project=$PROJECT_ID `
    --format="value(name)" 2>$null

if ($orphans) {
    Write-Host "  ⚠ Found forwarding rules — review these manually:" -ForegroundColor Yellow
    Write-Host $orphans -ForegroundColor White
    Write-Host "  Delete with: gcloud compute forwarding-rules delete <name> --region=$REGION" -ForegroundColor White
} else {
    Write-Host "  ✓ No orphaned load balancers" -ForegroundColor Green
}

Write-Host "`n✅ Teardown complete. Billing stopped." -ForegroundColor Green
Write-Host "   Artifact Registry images are preserved (negligible cost)." -ForegroundColor White
Write-Host "   Recreate anytime with: create-cluster.ps1" -ForegroundColor White