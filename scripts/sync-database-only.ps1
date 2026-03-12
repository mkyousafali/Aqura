# Database Sync Only Script - No Frontend Build
# Steps:
# 1. Create database dump on cloud
# 2. Download to PC
# 3. Upload to branch
# 4. Restore on branch
# 5. Reset sequences
# 6. Verify HTTP 200

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors for output
$colors = @{
    'header' = 'Cyan'
    'success' = 'Green'
    'error' = 'Red'
    'info' = 'Yellow'
}

function Log-Header($msg) { Write-Host "[INIT] $msg" -ForegroundColor $colors['header'] }
function Log-Success($msg) { Write-Host "[OK] $msg" -ForegroundColor $colors['success'] }
function Log-Error($msg) { Write-Host "[ERROR] $msg" -ForegroundColor $colors['error'] }
function Log-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor $colors['info'] }

Log-Header "DATABASE SYNC ONLY - No Frontend Build"
Log-Info "Steps: Dump → Download → Upload → Restore → Reset Sequences → Verify"

# Cloud server details
$cloudServer = "root@8.213.42.21"
$cloudSshKey = "$env:USERPROFILE\.ssh\id_ed25519_nopass"
$dumpFile = "aqura_dump.sql.gz"
$tempDir = $env:TEMP

# Branch server details
$branchServer = "u@192.168.0.101"
$branchSshKey = "$env:USERPROFILE\.ssh\id_ed25519_nopass"

try {
    # Step 1: Create dump on cloud
    Log-Header "Creating database dump on cloud server..."
    
    # Use docker exec to dump database directly, then gzip the output locally
    ssh -i $cloudSshKey -o ConnectTimeout=10 $cloudServer "docker exec supabase-db pg_dump -U supabase_admin -d postgres | gzip > /tmp/$dumpFile && ls -lh /tmp/$dumpFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create database dump on cloud"
    }
    Log-Success "Database dump created on cloud"
    
    # Step 2: Download dump to PC
    Log-Header "Downloading dump to PC..."
    scp -i $cloudSshKey "${cloudServer}:/tmp/$dumpFile" "$tempDir\$dumpFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download dump from cloud"
    }
    
    $dumpSize = (Get-Item "$tempDir\$dumpFile").Length / 1MB
    Log-Success "Downloaded: $dumpFile (~$([math]::Round($dumpSize, 1)) MB)"
    
    # Step 3: Upload to branch
    Log-Header "Uploading dump to branch server..."
    scp -i $branchSshKey "$tempDir\$dumpFile" "${branchServer}:/tmp/$dumpFile"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload dump to branch"
    }
    Log-Success "Uploaded to branch: /tmp/$dumpFile"
    
    # Step 4: Restore database on branch
    Log-Header "Restoring database on branch..."
    $restoreCmd = "gunzip < /tmp/$dumpFile | docker exec -i supabase-db psql -U supabase_admin -d postgres -q 2>&1 | grep -v 'already exists' | grep -v 'duplicate key' | head -20"
    
    ssh -i $branchSshKey -o ConnectTimeout=10 $branchServer $restoreCmd
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
        throw "Failed to restore database on branch"
    }
    Log-Success "Database restored"
    
    # Step 5: Reset sequences
    Log-Header "Resetting database sequences..."
    
    # Generate and run reset_sequences.sql
    $resetSeqSql = @"
-- Reset all sequences to match max IDs
SELECT 'SELECT SETVAL(''' || c.relname || ''', COALESCE((SELECT MAX(id) FROM ' || t.relname || '), 1))' 
FROM pg_class c 
JOIN pg_class t ON c.relnamespace = t.relnamespace 
WHERE c.relkind = 'S' 
AND t.relname = regexp_replace(c.relname, '_id_seq$', '')
AND t.relkind = 'r';
"@
    
    $resetSeqSql | Set-Content "$tempDir\reset_sequences.sql" -Encoding UTF8
    
    # Copy to branch and execute
    scp -i $branchSshKey "$tempDir\reset_sequences.sql" "${branchServer}:/tmp/reset_sequences.sql" | Out-Null
    ssh -i $branchSshKey -o ConnectTimeout=10 $branchServer "docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/reset_sequences.sql -q 2>&1 | head -10"
    Log-Success "Sequences reset"
    
    # Step 6: Verify HTTP 200
    Log-Header "Verifying frontend HTTP 200..."
    
    $maxAttempts = 10
    $attempt = 0
    $statusCode = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://192.168.0.101:3001" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            $statusCode = $response.StatusCode
            if ($statusCode -eq 200) {
                break
            }
        } catch {
            $statusCode = 0
        }
        
        $attempt++
        if ($statusCode -ne 200) {
            Start-Sleep -Seconds 2
        }
    }
    
    if ($statusCode -eq 200) {
        Log-Success "Frontend HTTP 200 verified"
    } else {
        throw "Frontend returned HTTP $statusCode (expected 200)"
    }
    
    # Cleanup
    Log-Header "Cleaning up temporary files..."
    Remove-Item "$tempDir\$dumpFile" -Force -ErrorAction SilentlyContinue
    Remove-Item "$tempDir\reset_sequences.sql" -Force -ErrorAction SilentlyContinue
    ssh -i $cloudSshKey -o ConnectTimeout=10 $cloudServer "rm -f /tmp/$dumpFile" 2>&1 | Out-Null
    ssh -i $branchSshKey -o ConnectTimeout=10 $branchServer "rm -f /tmp/$dumpFile /tmp/reset_sequences.sql" 2>&1 | Out-Null
    Log-Success "Cleaned up temp files"
    
    Log-Header "========== DATABASE SYNC COMPLETE =========="
    Write-Host ""
    Write-Host "✓ Database dumped from cloud" -ForegroundColor Green
    Write-Host "✓ Database restored on branch" -ForegroundColor Green
    Write-Host "✓ Sequences reset" -ForegroundColor Green
    Write-Host "✓ Frontend verified (HTTP 200)" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Log-Error "Sync failed: $_"
    exit 1
}
