<#
.SYNOPSIS
  Aqura Full Branch Deployment - Automated end-to-end pipeline.

.DESCRIPTION
  This script performs ALL deployment steps in one run:
    1. Version bump + changelog update + git commit (via simple-push.js --deploy)
    2. Database dump from cloud -> download to PC -> upload to branch -> restore
    3. Reset sequences on branch database
    4. Build frontend with adapter-node
    5. Compress build output
    6. Upload compressed build to branch server
    7. Stop old frontend process on branch
    8. Deploy new build + install dependencies
    9. Start new frontend on PORT 3001
   10. Verify deployment
   11. Git push
   12. Cleanup temp files

.PARAMETER Interface
  Which interface version to bump: desktop, mobile, cashier, customer, all

.PARAMETER Message
  Commit message describing the changes

.PARAMETER SkipDbSync
  Skip the database sync steps (Steps 2-3)

.PARAMETER SkipVersionBump
  Skip version bump (useful for re-deploying same version)

.PARAMETER SkipGitPush
  Skip the final git push step

.EXAMPLE
  .\scripts\deploy-to-branch.ps1 -Interface desktop -Message "feat(hr): add analysis tool"
  .\scripts\deploy-to-branch.ps1 -Interface all -Message "fix: multiple bug fixes" -SkipDbSync
  .\scripts\deploy-to-branch.ps1 -Interface desktop -Message "hotfix" -SkipVersionBump
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("desktop","mobile","cashier","customer","all")]
    [string]$Interface,

    [Parameter(Mandatory=$true)]
    [string]$Message,

    [switch]$SkipDbSync,
    [switch]$SkipVersionBump,
    [switch]$SkipGitPush
)

# -- Configuration ---------------------------------------------------------
$ErrorActionPreference = "Stop"
$ProjectRoot     = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$FrontendDir     = Join-Path $ProjectRoot "frontend"
$SSHKey          = Join-Path $env:USERPROFILE ".ssh\id_ed25519_nopass"
$SSHOpts         = @("-i", $SSHKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10")
$CloudHost       = "root@8.213.42.21"
$BranchHost      = "u@192.168.0.101"
$BranchDeployDir = "/tmp/build"
$BranchPort      = 3001
$TempDump        = Join-Path $env:TEMP "aqura_dump.sql.gz"
$TempBuild       = Join-Path $env:TEMP "aqura_build.tar.gz"

$startTime = Get-Date

# -- Helper Functions ------------------------------------------------------
function Write-Step { param($n, $total, $msg) Write-Host "`n=== Step ${n}/${total} - ${msg} ===" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  [SKIP] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }

function Invoke-SSH {
    param([string]$Host_, [string]$Cmd)
    $output = & ssh @SSHOpts $Host_ $Cmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed on ${Host_}: $Cmd`nOutput: $($output -join "`n")"
    }
    return $output
}

function Invoke-SCP {
    param([string]$Source, [string]$Dest)
    & scp @SSHOpts $Source $Dest 2>&1
    if ($LASTEXITCODE -ne 0) { throw "SCP failed: $Source -> $Dest" }
}

# -- Preflight Checks ------------------------------------------------------
Write-Host ""
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host "       AQURA BRANCH DEPLOYMENT PIPELINE                 " -ForegroundColor Magenta
Write-Host "========================================================" -ForegroundColor Magenta

$totalSteps = 10
if ($SkipDbSync)       { $totalSteps -= 2 }
if ($SkipVersionBump)  { $totalSteps -= 1 }
if ($SkipGitPush)      { $totalSteps -= 1 }

Write-Host "  Interface : $Interface" -ForegroundColor White
Write-Host "  Message   : $Message" -ForegroundColor White
Write-Host "  DB Sync   : $(if($SkipDbSync){'SKIP'}else{'YES'})" -ForegroundColor White
Write-Host "  Version   : $(if($SkipVersionBump){'SKIP'}else{'YES'})" -ForegroundColor White
Write-Host "  Git Push  : $(if($SkipGitPush){'SKIP'}else{'YES'})" -ForegroundColor White

# Verify SSH connectivity
Write-Host "`nPreflight: testing SSH connections..." -ForegroundColor Gray
try {
    Invoke-SSH $CloudHost  "echo ok" | Out-Null
    Write-OK "Cloud server (8.213.42.21) reachable"
} catch {
    Write-Fail "Cannot reach cloud server! Check SSH key / network."
    exit 1
}
try {
    Invoke-SSH $BranchHost "echo ok" | Out-Null
    Write-OK "Branch server (192.168.0.101) reachable"
} catch {
    Write-Fail "Cannot reach branch server! Check network / VM."
    exit 1
}

$step = 0

# ==========================================================================
# STEP: VERSION BUMP + CHANGELOG + CLOUD DEPLOY
# ==========================================================================
if (-not $SkipVersionBump) {
    $step++
    Write-Step $step $totalSteps "Version bump, changelog, cloud deploy"

    Push-Location $ProjectRoot
    try {
        # simple-push.js handles: version bump -> update displays -> git commit -> build -> upload to cloud storage
        & node "Do not delete/simple-push.js" $Interface $Message --deploy
        if ($LASTEXITCODE -ne 0) { throw "simple-push.js failed" }
        Write-OK "Version bumped, committed, and uploaded to cloud storage"
    } finally {
        Pop-Location
    }
} else {
    Write-Skip "Version bump"
}

# Read current version after potential bump
$pkgJson = Get-Content (Join-Path $FrontendDir "package.json") -Raw | ConvertFrom-Json
$version = $pkgJson.version
Write-Host "  Current version: $version" -ForegroundColor White

# ==========================================================================
# STEP: DATABASE DUMP FROM CLOUD
# ==========================================================================
if (-not $SkipDbSync) {
    $step++
    Write-Step $step $totalSteps "Database dump (cloud -> PC -> branch)"

    # Create dump on cloud
    Write-Host "  Creating dump on cloud..." -ForegroundColor Gray
    Invoke-SSH $CloudHost "docker exec -t supabase-db pg_dump -U supabase_admin postgres | gzip > /tmp/aqura_dump.sql.gz && ls -lh /tmp/aqura_dump.sql.gz" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-OK "Cloud dump created"

    # Download to PC
    Write-Host "  Downloading to PC..." -ForegroundColor Gray
    if (Test-Path $TempDump) { Remove-Item $TempDump -Force }
    Invoke-SCP "${CloudHost}:/tmp/aqura_dump.sql.gz" $TempDump
    $dumpSize = [math]::Round((Get-Item $TempDump).Length / 1MB, 1)
    Write-OK "Downloaded: ${dumpSize} MB"

    # Upload to branch
    Write-Host "  Uploading to branch..." -ForegroundColor Gray
    Invoke-SCP $TempDump "${BranchHost}:/tmp/aqura_dump.sql.gz"
    Write-OK "Uploaded to branch"

    # ==================================================================
    # STEP: RESTORE DATABASE ON BRANCH
    # ==================================================================
    $step++
    Write-Step $step $totalSteps "Restore database + reset sequences"

    Write-Host "  Restoring database (this takes a few minutes)..." -ForegroundColor Gray
    Invoke-SSH $BranchHost "docker cp /tmp/aqura_dump.sql.gz supabase-db:/tmp/aqura_dump.sql.gz && gunzip -c /tmp/aqura_dump.sql.gz | docker exec -i supabase-db psql -U supabase_admin postgres > /dev/null 2>&1 && echo 'RESTORE_OK'" | ForEach-Object {
        if ($_ -match "RESTORE_OK") { Write-OK "Database restored" }
    }

    # Reset sequences
    Write-Host "  Resetting sequences..." -ForegroundColor Gray
    $seqFile = Join-Path $env:TEMP "reset_sequences.sql"
    $seqSQL = @'
DO $$ DECLARE r record; BEGIN FOR r IN (SELECT t.relname as tbl, a.attname as col, pg_get_serial_sequence(t.relname, a.attname) as seq FROM pg_class t JOIN pg_namespace n ON t.relnamespace = n.oid JOIN pg_attribute a ON a.attrelid = t.oid WHERE n.nspname = 'public' AND t.relkind = 'r' AND pg_get_serial_sequence(t.relname, a.attname) IS NOT NULL) LOOP EXECUTE format('SELECT setval(%L, COALESCE((SELECT MAX(%I) FROM %I), 1))', r.seq, r.col, r.tbl); END LOOP; END $$; NOTIFY pgrst, 'reload schema';
'@
    Set-Content -Path $seqFile -Value $seqSQL -Encoding UTF8
    Invoke-SCP $seqFile "${BranchHost}:/tmp/reset_sequences.sql"
    Invoke-SSH $BranchHost "docker cp /tmp/reset_sequences.sql supabase-db:/tmp/reset_sequences.sql && docker exec supabase-db psql -U supabase_admin postgres -f /tmp/reset_sequences.sql" | Out-Null
    Write-OK "Sequences reset"
    Remove-Item $seqFile -Force -ErrorAction SilentlyContinue

    # Verify
    $tableCount = Invoke-SSH $BranchHost "docker exec supabase-db psql -U supabase_admin postgres -t -c `"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';`""
    Write-OK "Branch database: $($tableCount.Trim()) public tables"
} else {
    Write-Skip "Database sync"
}

# ==========================================================================
# STEP: BUILD FRONTEND (skip if simple-push.js --deploy already built it)
# ==========================================================================
$buildDir = Join-Path $FrontendDir "build"
$buildIndexJs = Join-Path $buildDir "index.js"
$needsBuild = $true

# If version bump ran with --deploy, it already built with adapter-node
if ((-not $SkipVersionBump) -and (Test-Path $buildIndexJs)) {
    $buildAge = (Get-Date) - (Get-Item $buildIndexJs).LastWriteTime
    if ($buildAge.TotalMinutes -lt 10) {
        $needsBuild = $false
        $step++
        Write-Step $step $totalSteps "Build frontend (adapter-node)"
        Write-OK "Reusing build from version bump (built $([math]::Round($buildAge.TotalSeconds))s ago)"
    }
}

if ($needsBuild) {
    $step++
    Write-Step $step $totalSteps "Build frontend (adapter-node)"

    Push-Location $FrontendDir
    try {
        $env:BUILD_ADAPTER = "node"
        $env:NODE_OPTIONS  = "--max-old-space-size=8192"
        Write-Host "  Building with 8GB heap..." -ForegroundColor Gray
        & npm run build 2>&1 | ForEach-Object {
            if ($_ -match "built in|error|warning") { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        if ($LASTEXITCODE -ne 0) { throw "Frontend build failed" }
        Write-OK "Frontend built successfully"
    } finally {
        Remove-Item Env:\BUILD_ADAPTER -ErrorAction SilentlyContinue
        Remove-Item Env:\NODE_OPTIONS  -ErrorAction SilentlyContinue
        Pop-Location
    }
}

# ==========================================================================
# STEP: COMPRESS BUILD
# ==========================================================================
$step++
Write-Step $step $totalSteps "Compress build output"

if (Test-Path $TempBuild) { Remove-Item $TempBuild -Force }

# Use tar for better compression and Linux compatibility
Push-Location $FrontendDir
try {
    & tar -czf $TempBuild -C $FrontendDir build package.json pnpm-lock.yaml 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Compression failed" }
} finally {
    Pop-Location
}

$buildSize = [math]::Round((Get-Item $TempBuild).Length / 1MB, 1)
Write-OK "Compressed: ${buildSize} MB ($TempBuild)"

# ==========================================================================
# STEP: UPLOAD BUILD TO BRANCH
# ==========================================================================
$step++
Write-Step $step $totalSteps "Upload build to branch server"

Invoke-SCP $TempBuild "${BranchHost}:/tmp/aqura_build.tar.gz"
Write-OK "Build uploaded to branch"

# ==========================================================================
# STEP: STOP OLD + DEPLOY NEW ON BRANCH
# ==========================================================================
$step++
Write-Step $step $totalSteps "Deploy new build on branch"

# Stop old frontend process
Write-Host "  Stopping old frontend..." -ForegroundColor Gray
Invoke-SSH $BranchHost "pkill -f 'node.*build/index.js' 2>/dev/null; sleep 2; echo 'OLD_STOPPED'" | Out-Null
Write-OK "Old frontend stopped"

# Remove old build and extract new one
Write-Host "  Extracting new build..." -ForegroundColor Gray
$extractCmd = "rm -rf $BranchDeployDir/build $BranchDeployDir/package.json $BranchDeployDir/pnpm-lock.yaml 2>/dev/null; mkdir -p $BranchDeployDir; tar -xzf /tmp/aqura_build.tar.gz -C $BranchDeployDir; echo EXTRACTED"
Invoke-SSH $BranchHost $extractCmd | Out-Null
Write-OK "New build extracted to $BranchDeployDir"

# Install dependencies
Write-Host "  Installing dependencies..." -ForegroundColor Gray
Invoke-SSH $BranchHost "cd $BranchDeployDir && npm install --omit=dev --legacy-peer-deps 2>&1 | tail -3" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
Write-OK "Dependencies installed"

# ==========================================================================
# STEP: START + VERIFY
# ==========================================================================
$step++
Write-Step $step $totalSteps "Start frontend + verify"

# Start the app
$startCmd = "cd $BranchDeployDir && PORT=$BranchPort NODE_OPTIONS='--max-old-space-size=4096' NODE_ENV='production' nohup node build/index.js > /tmp/app.log 2>&1 & sleep 3; echo STARTED"
Invoke-SSH $BranchHost $startCmd | Out-Null

# Verify it is responding
Start-Sleep -Seconds 2
$curlCmd = "curl -s -o /dev/null -w '%{http_code}' http://localhost:${BranchPort}/ 2>/dev/null"
$verifyResult = Invoke-SSH $BranchHost $curlCmd
if ($verifyResult.Trim() -eq "200") {
    Write-OK "Frontend running on port $BranchPort (HTTP 200)"
} else {
    Write-Fail "Frontend returned HTTP $($verifyResult.Trim()) -- check /tmp/app.log on branch"
    Write-Host "  Logs:" -ForegroundColor Yellow
    Invoke-SSH $BranchHost "tail -20 /tmp/app.log" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    exit 1
}

# Show version running
$runningVersion = Invoke-SSH $BranchHost "cat $BranchDeployDir/package.json 2>/dev/null | grep version | head -1"
Write-OK "Deployed: $($runningVersion.Trim())"

# ==========================================================================
# STEP: GIT PUSH
# ==========================================================================
if (-not $SkipGitPush) {
    $step++
    Write-Step $step $totalSteps "Git push"

    Push-Location $ProjectRoot
    try {
        & git push 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -ne 0) { throw "Git push failed" }
        Write-OK "Pushed to remote"
    } finally {
        Pop-Location
    }
} else {
    Write-Skip "Git push"
}

# ==========================================================================
# CLEANUP
# ==========================================================================
Write-Host "`n--- Cleanup ---" -ForegroundColor Cyan
Remove-Item $TempDump  -Force -ErrorAction SilentlyContinue
Remove-Item $TempBuild -Force -ErrorAction SilentlyContinue

# Clean cloud temp files
try { Invoke-SSH $CloudHost "rm -f /tmp/aqura_dump.sql.gz" | Out-Null } catch {}

# Clean branch temp files
try { Invoke-SSH $BranchHost "rm -f /tmp/aqura_build.tar.gz /tmp/aqura_dump.sql.gz /tmp/reset_sequences.sql" | Out-Null } catch {}

Write-OK "Temp files cleaned"

# ==========================================================================
# SUMMARY
# ==========================================================================
$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "              DEPLOYMENT COMPLETE                       " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Version  : $version" -ForegroundColor White
Write-Host "  Frontend : http://192.168.0.101:$BranchPort" -ForegroundColor White
Write-Host "  DB Sync  : $(if($SkipDbSync){'Skipped'}else{'Done'})" -ForegroundColor White
Write-Host "  Git Push : $(if($SkipGitPush){'Skipped'}else{'Done'})" -ForegroundColor White
Write-Host "  Time     : $([math]::Round($elapsed.TotalMinutes, 1)) minutes" -ForegroundColor White
Write-Host ""
