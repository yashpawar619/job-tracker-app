# ============================================================
# build-and-push.ps1 — Build Docker image & push to Artifact Registry
# ============================================================
$ErrorActionPreference = "Stop"

# ===== Config — EDIT THESE =====
$PROJECT_ID = "java-app-prod"       # Your project ID
$REGION     = "asia-south1"
$REPO_NAME  = "java-app-repo"
$IMAGE_NAME = "java-app"
$IMAGE_TAG  = "1.0.0"
# Anchored to this script's own folder via $PSScriptRoot, so the script works no
# matter which directory you invoke it from.
$APP_PATH   = Join-Path $PSScriptRoot "..\..\java-app"

# Full image path — uses ${} braces so the colon parses correctly
$FULL_IMAGE = "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"

# ===== Set project =====
Write-Host "`n[1/6] Setting project" -ForegroundColor Cyan
gcloud config set project $PROJECT_ID

# ===== Ensure Artifact Registry repo exists =====
Write-Host "`n[2/6] Checking Artifact Registry repo: $REPO_NAME" -ForegroundColor Cyan
# gcloud writes status text ("Listing items under project...") to stderr. In Windows
# PowerShell 5.1, redirecting a native command's stderr while $ErrorActionPreference is
# 'Stop' turns that text into a terminating error, so relax it just for this call.
$existingRepo = & { $ErrorActionPreference = 'Continue'
    gcloud artifacts repositories list --location=$REGION --filter="name~$REPO_NAME" --format="value(name)" 2>$null }
if ($existingRepo) {
    Write-Host "  Repo exists, skipping" -ForegroundColor Yellow
} else {
    Write-Host "  Creating repo..." -ForegroundColor Cyan
    gcloud artifacts repositories create $REPO_NAME --repository-format=docker --location=$REGION --description="Docker images for Java app"
    Write-Host "  Repo created" -ForegroundColor Green
}

# ===== Configure Docker auth =====
Write-Host "`n[3/6] Configuring Docker authentication" -ForegroundColor Cyan
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# ===== Build, containerize, push =====
Push-Location $APP_PATH
try {
    Write-Host "`n[4/6] Building Spring Boot app with Maven" -ForegroundColor Cyan
    .\mvnw.cmd clean package -DskipTests
    Write-Host "  JAR built" -ForegroundColor Green

    Write-Host "`n[5/6] Building Docker image: $FULL_IMAGE" -ForegroundColor Cyan
    docker build -t $FULL_IMAGE .
    Write-Host "  Image built" -ForegroundColor Green

    Write-Host "`n[6/6] Pushing image to Artifact Registry" -ForegroundColor Cyan
    docker push $FULL_IMAGE
    Write-Host "  Image pushed" -ForegroundColor Green
}
finally {
    Pop-Location
}

Write-Host "`nDone. Image available at:" -ForegroundColor Green
Write-Host "   $FULL_IMAGE" -ForegroundColor White
Write-Host "`n   Ensure values.yaml image.repository matches:" -ForegroundColor Yellow
Write-Host "   ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}" -ForegroundColor White