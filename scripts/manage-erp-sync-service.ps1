# Install ERP Sales Sync Service as Windows Service
# Run as Administrator

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status
)

$serviceName = "AquraERPSyncService"
$serviceDisplayName = "Aqura ERP Sales Sync Service"
$serviceDescription = "Syncs ERP sales data to Supabase every minute"
$scriptPath = "D:\Aqura\erp-sales-sync-service.js"
$nodePath = (Get-Command node).Source
$workingDir = "D:\Aqura"

Write-Host "=== Aqura ERP Sales Sync Service Manager ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ This script must be run as Administrator" -ForegroundColor Red
    Write-Host "   Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

if ($Install) {
    Write-Host "📦 Installing service..." -ForegroundColor Green
    
    # Check if NSSM is installed
    $nssmPath = "C:\nssm\nssm.exe"
    
    if (-not (Test-Path $nssmPath)) {
        Write-Host "⚠️  NSSM (Non-Sucking Service Manager) not found" -ForegroundColor Yellow
        Write-Host "   Downloading NSSM..." -ForegroundColor Cyan
        
        $nssmZip = "$env:TEMP\nssm.zip"
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip
        
        Expand-Archive -Path $nssmZip -DestinationPath "C:\" -Force
        Move-Item "C:\nssm-2.24\win64\nssm.exe" "C:\nssm\" -Force
        Remove-Item "C:\nssm-2.24" -Recurse -Force
        Remove-Item $nssmZip -Force
        
        Write-Host "✅ NSSM installed" -ForegroundColor Green
    }
    
    # Install service
    & $nssmPath install $serviceName $nodePath $scriptPath
    & $nssmPath set $serviceName AppDirectory $workingDir
    & $nssmPath set $serviceName DisplayName $serviceDisplayName
    & $nssmPath set $serviceName Description $serviceDescription
    & $nssmPath set $serviceName Start SERVICE_AUTO_START
    & $nssmPath set $serviceName AppStdout "$workingDir\logs\erp-sync.log"
    & $nssmPath set $serviceName AppStderr "$workingDir\logs\erp-sync-error.log"
    & $nssmPath set $serviceName AppRotateFiles 1
    & $nssmPath set $serviceName AppRotateBytes 1048576
    
    Write-Host "✅ Service installed successfully" -ForegroundColor Green
    Write-Host "   Service Name: $serviceName" -ForegroundColor White
    Write-Host "   Use -Start to start the service" -ForegroundColor Yellow
}

if ($Uninstall) {
    Write-Host "🗑️  Uninstalling service..." -ForegroundColor Green
    
    # Stop service if running
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') {
        Stop-Service -Name $serviceName
        Write-Host "⏹️  Service stopped" -ForegroundColor Yellow
    }
    
    # Remove service
    & C:\nssm\nssm.exe remove $serviceName confirm
    Write-Host "✅ Service uninstalled" -ForegroundColor Green
}

if ($Start) {
    Write-Host "▶️  Starting service..." -ForegroundColor Green
    Start-Service -Name $serviceName
    Start-Sleep -Seconds 2
    $service = Get-Service -Name $serviceName
    if ($service.Status -eq 'Running') {
        Write-Host "✅ Service started successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Service failed to start" -ForegroundColor Red
    }
}

if ($Stop) {
    Write-Host "⏹️  Stopping service..." -ForegroundColor Green
    Stop-Service -Name $serviceName
    Write-Host "✅ Service stopped" -ForegroundColor Green
}

if ($Status) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "Service Status:" -ForegroundColor Cyan
        Write-Host "  Name: $($service.Name)" -ForegroundColor White
        Write-Host "  Status: $($service.Status)" -ForegroundColor White
        Write-Host "  Start Type: $($service.StartType)" -ForegroundColor White
        
        if (Test-Path "$workingDir\logs\erp-sync.log") {
            Write-Host "`nLast 10 log lines:" -ForegroundColor Cyan
            Get-Content "$workingDir\logs\erp-sync.log" -Tail 10
        }
    } else {
        Write-Host "❌ Service not installed" -ForegroundColor Red
    }
}

if (-not ($Install -or $Uninstall -or $Start -or $Stop -or $Status)) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\manage-erp-sync-service.ps1 -Install     # Install service" -ForegroundColor White
    Write-Host "  .\manage-erp-sync-service.ps1 -Start       # Start service" -ForegroundColor White
    Write-Host "  .\manage-erp-sync-service.ps1 -Stop        # Stop service" -ForegroundColor White
    Write-Host "  .\manage-erp-sync-service.ps1 -Status      # Check status" -ForegroundColor White
    Write-Host "  .\manage-erp-sync-service.ps1 -Uninstall   # Uninstall service" -ForegroundColor White
}

Write-Host ""
