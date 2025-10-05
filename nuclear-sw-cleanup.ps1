# Enhanced Service Worker Killer Script
Write-Host "🔥 NUCLEAR SERVICE WORKER CLEANUP SCRIPT 🔥" -ForegroundColor Red
Write-Host "This will completely obliterate all service workers and PWA data" -ForegroundColor Yellow

# Kill all browser processes first
Write-Host "`n1. Killing all browser processes..." -ForegroundColor Cyan
$browsers = @("chrome", "msedge", "firefox", "brave", "opera", "vivaldi")
foreach ($browser in $browsers) {
    Get-Process | Where-Object { $_.ProcessName -match $browser } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "   Killed: $browser" -ForegroundColor Green
}

Start-Sleep -Seconds 2

# Clear Chrome/Chromium-based browsers
Write-Host "`n2. Clearing Chrome/Edge service workers..." -ForegroundColor Cyan
$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Application Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Application Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Service Worker",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
)

foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        Write-Host "   🗑️  Removing: $path" -ForegroundColor Red
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clear Firefox
Write-Host "`n3. Clearing Firefox service workers..." -ForegroundColor Cyan
$firefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxPath) {
    Get-ChildItem $firefoxPath | ForEach-Object {
        $swPath = Join-Path $_.FullName "serviceworker.txt"
        $cachePath = Join-Path $_.FullName "cache2"
        $offlineCache = Join-Path $_.FullName "OfflineCache"
        
        if (Test-Path $swPath) { 
            Remove-Item $swPath -Force -ErrorAction SilentlyContinue
            Write-Host "   🗑️  Removed Firefox SW: $swPath" -ForegroundColor Red
        }
        if (Test-Path $cachePath) { 
            Remove-Item $cachePath -Recurse -Force -ErrorAction SilentlyContinue 
            Write-Host "   🗑️  Removed Firefox Cache: $cachePath" -ForegroundColor Red
        }
        if (Test-Path $offlineCache) { 
            Remove-Item $offlineCache -Recurse -Force -ErrorAction SilentlyContinue 
            Write-Host "   🗑️  Removed Firefox Offline Cache: $offlineCache" -ForegroundColor Red
        }
    }
}

# Clear development files
Write-Host "`n4. Clearing development service workers..." -ForegroundColor Cyan
$devPaths = @(
    "f:\Aqura\frontend\.svelte-kit",
    "f:\Aqura\frontend\dev-dist",
    "f:\Aqura\frontend\dist",
    "f:\Aqura\frontend\build",
    "f:\Aqura\frontend\static\sw.js",
    "f:\Aqura\frontend\static\workbox-*.js"
)

foreach ($path in $devPaths) {
    if (Test-Path $path) {
        Write-Host "   🗑️  Removing dev file: $path" -ForegroundColor Red
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clear npm/pnpm cache
Write-Host "`n5. Clearing package manager caches..." -ForegroundColor Cyan
try {
    pnpm store prune --force 2>$null
    Write-Host "   ✅ PNPM store pruned" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  PNPM not found or error" -ForegroundColor Yellow
}

try {
    npm cache clean --force 2>$null
    Write-Host "   ✅ NPM cache cleaned" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  NPM not found or error" -ForegroundColor Yellow
}

# Final message
Write-Host "`n🎉 COMPLETE ANNIHILATION FINISHED! 🎉" -ForegroundColor Green
Write-Host "All service workers have been obliterated from existence!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Start your development server" -ForegroundColor White
Write-Host "2. Open browser and navigate to your app" -ForegroundColor White
Write-Host "3. Open DevTools -> Application -> Service Workers to verify they're gone" -ForegroundColor White
Write-Host "4. Your PWA will register a fresh, clean service worker" -ForegroundColor White