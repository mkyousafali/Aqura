# Comprehensive PWA Cache Clearing Script
Write-Host "Clearing all PWA cache and service worker data..." -ForegroundColor Yellow

# Kill all browser processes
Write-Host "Closing all browser processes..." -ForegroundColor Blue
Get-Process | Where-Object { $_.ProcessName -match "chrome|msedge|firefox|brave|opera" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Clear Chrome/Edge cache directories
$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Application Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Application Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
)

foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        Write-Host "Clearing: $path" -ForegroundColor Green
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clear Firefox cache if exists
$firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxPath) {
    Get-ChildItem $firefoxPath | ForEach-Object {
        $swPath = Join-Path $_.FullName "serviceworker.txt"
        $cachePath = Join-Path $_.FullName "cache2"
        if (Test-Path $swPath) { Remove-Item $swPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $cachePath) { Remove-Item $cachePath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Clear Brave cache if exists  
$bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
if (Test-Path $bravePath) {
    $braveServiceWorker = Join-Path $bravePath "Service Worker"
    $braveCache = Join-Path $bravePath "Cache"
    if (Test-Path $braveServiceWorker) { Remove-Item $braveServiceWorker -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $braveCache) { Remove-Item $braveCache -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "PWA cache clearing completed!" -ForegroundColor Green
Write-Host "Please clear browser data manually:" -ForegroundColor Red
Write-Host "1. Open DevTools (F12)" -ForegroundColor Yellow
Write-Host "2. Go to Application tab" -ForegroundColor Yellow
Write-Host "3. Clear Storage -> Clear site data" -ForegroundColor Yellow
Write-Host "4. Unregister service workers in Service Workers section" -ForegroundColor Yellow