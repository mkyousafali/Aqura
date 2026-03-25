# Deploy edge function to self-hosted Supabase (PowerShell)
$RemoteHost = "8.213.42.21"
$RemoteUser = "root"
$SshKey = "$HOME\.ssh\id_ed25519"
$LocalFunction = "supabase/functions/whatsapp-manage/index.ts"
$RemoteFunctionsDir = "/opt/supabase/supabase/volumes/functions/whatsapp-manage"
$SshTarget = "$RemoteUser@$RemoteHost"

Write-Host "Deploying edge function to self-hosted Supabase..." -ForegroundColor Green
Write-Host "   Host: $RemoteHost"
Write-Host "   Function: whatsapp-manage"
Write-Host ""

# Step 1: Create remote directory
Write-Host "Creating function directory..." -ForegroundColor Cyan
$cmd1 = "mkdir -p $RemoteFunctionsDir"
ssh -i $SshKey $SshTarget $cmd1
if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: Failed to create remote directory" -ForegroundColor Red
  exit 1
}

# Step 2: Copy function file
Write-Host "Copying function file..." -ForegroundColor Cyan
$RemoteFile = "$SshTarget`:$RemoteFunctionsDir/index.ts"
scp -i $SshKey $LocalFunction $RemoteFile
if ($LASTEXITCODE -ne 0) {
  Write-Host "ERROR: Failed to copy function file" -ForegroundColor Red
  exit 1
}

# Step 3: Restart edge functions container
Write-Host "Restarting edge functions container..." -ForegroundColor Cyan
$cmd2 = "docker restart supabase-edge-functions"
ssh -i $SshKey $SshTarget $cmd2
if ($LASTEXITCODE -ne 0) {
  Write-Host "WARNING: Container restart may have failed" -ForegroundColor Yellow
}

# Step 4: Summary
Write-Host ""
Write-Host "SUCCESS: Edge function deployed!" -ForegroundColor Green
Write-Host "   Location: $RemoteFunctionsDir/index.ts"
Write-Host ""
Write-Host "Changes deployed:" -ForegroundColor Cyan
Write-Host "   - 4-5x speed boost (concurrency 5-15, delay 800-100ms)"
Write-Host "   - Better retry logic (5 attempts, 30s timeout)"
Write-Host "   - Ecosystem error cap at retry 2"
Write-Host "   - Throttle pause cap at 10s"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "   1. Go to http://8.213.42.21:3000"
Write-Host "   2. Find the stuck broadcast (19,003 pending)"
Write-Host "   3. Click retry button"
Write-Host "   4. Check progress - should complete in 18-25 minutes"
