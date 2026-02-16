# ═══════════════════════════════════════════════════════════════
# Build-Frontend.ps1 — Build Aqura Frontend for Branch Deployment
# ═══════════════════════════════════════════════════════════════
# 
# Builds the SvelteKit frontend using adapter-node and creates
# a ZIP file (aqura-frontend-build.zip) for the branch installer.
#
# Run from any directory:
#   .\Build-Frontend.ps1
#   .\Build-Frontend.ps1 -FrontendPath "D:\Aqura\frontend"
#   .\Build-Frontend.ps1 -OutputPath "D:\Aqura-Branch-Installer\template"
#
# Requirements:
#   - Node.js 20+ installed
#   - npm available in PATH
#   - Frontend source at specified path
# ═══════════════════════════════════════════════════════════════

param(
    [string]$FrontendPath = "D:\Aqura\frontend",
    [string]$OutputPath = (Split-Path $PSScriptRoot),
    [string]$OutputFile = "aqura-frontend-build.zip"
)

$ErrorActionPreference = "Stop"

function Write-Step ($msg) { Write-Host "  ► $msg" -ForegroundColor Cyan }
function Write-Success ($msg) { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail ($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   BUILD AQURA FRONTEND FOR BRANCH DEPLOYMENT     ║" -ForegroundColor Cyan
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Validate frontend path
if (-not (Test-Path "$FrontendPath\package.json")) {
    Write-Fail "Frontend not found at: $FrontendPath"
    Write-Fail "Make sure the path points to the frontend/ directory with package.json"
    exit 1
}

# Check for svelte.config.local.js (adapter-node config)
$localConfig = "$FrontendPath\svelte.config.local.js"
$mainConfig = "$FrontendPath\svelte.config.js"
$backupConfig = "$FrontendPath\svelte.config.js.bak"

if (-not (Test-Path $localConfig)) {
    Write-Fail "svelte.config.local.js not found!"
    Write-Fail "This file should contain the adapter-node configuration."
    exit 1
}

Write-Step "Frontend path: $FrontendPath"
Write-Step "Output: $OutputPath\$OutputFile"
Write-Host ""

# Step 1: Swap svelte.config.js → adapter-node version
Write-Step "Swapping svelte.config.js to adapter-node..."
Copy-Item $mainConfig $backupConfig -Force
Copy-Item $localConfig $mainConfig -Force
Write-Success "Config swapped"

try {
    # Step 2: Install dependencies
    Write-Step "Installing dependencies..."
    Push-Location $FrontendPath
    npm install --legacy-peer-deps 2>&1 | Select-Object -Last 3
    Write-Success "Dependencies installed"

    # Step 3: Build
    Write-Step "Building frontend (this may take 1-2 minutes)..."
    npm run build 2>&1 | Select-Object -Last 5
    
    if (-not (Test-Path "$FrontendPath\build\index.js")) {
        Write-Fail "Build failed — build/index.js not found"
        exit 1
    }
    Write-Success "Build complete"

    # Step 4: Write version.txt into build
    Write-Step "Writing version info..."
    $pkgJson = Get-Content "$FrontendPath\package.json" -Raw | ConvertFrom-Json
    $versionInfo = @"
$($pkgJson.version)
Built: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
    $versionInfo | Set-Content -Path "$FrontendPath\build\version.txt" -Encoding UTF8
    Write-Success "Version: $($pkgJson.version)"

    # Step 5: Create ZIP
    Write-Step "Creating ZIP archive..."
    $buildDir = "$FrontendPath\build"
    $zipPath = Join-Path $OutputPath $OutputFile
    
    # Remove old ZIP if exists
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    Compress-Archive -Path "$buildDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Success "ZIP created: $zipPath ($zipSize MB)"

} finally {
    # Step 5: Restore original config
    Pop-Location
    Write-Step "Restoring original svelte.config.js..."
    if (Test-Path $backupConfig) {
        Copy-Item $backupConfig $mainConfig -Force
        Remove-Item $backupConfig -Force
    }
    Write-Success "Config restored"
}

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║   BUILD COMPLETE!                                ║" -ForegroundColor Green
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Output: $zipPath" -ForegroundColor White
Write-Host "  Size:   $zipSize MB" -ForegroundColor White
Write-Host ""
Write-Host "  Use with installer:" -ForegroundColor Yellow
Write-Host "    Point 'Frontend Build ZIP' to this file during setup wizard." -ForegroundColor Gray
Write-Host ""
