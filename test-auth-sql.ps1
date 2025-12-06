# Direct SQL Test - Create and Verify Test User

$SUPABASE_URL = "https://supabase.urbanaqura.com"
$SERVICE_KEY = $env:VITE_SUPABASE_SERVICE_KEY

Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host " SQL AUTHENTICATION TEST" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Create test user via SQL
Write-Host "Creating test user via SQL..." -ForegroundColor Yellow

$sql = @"
INSERT INTO users (username, email, password_hash, quick_access_code, role, role_type, user_type, status, created_at, updated_at)
VALUES ('testuser', 'test@aqura.local', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/exa', '123456', 'admin', 'ADMIN', 'EMPLOYEE', 'ACTIVE', NOW(), NOW())
ON CONFLICT (username) DO UPDATE
SET quick_access_code = '123456', status = 'ACTIVE', updated_at = NOW()
RETURNING id, username, email, role_type, status, quick_access_code;
"@

$headers = @{
    "apikey" = $SERVICE_KEY
    "Authorization" = "Bearer $SERVICE_KEY"
    "Content-Type" = "application/json"
}

$body = @{
    query = $sql
} | ConvertTo-Json

try {
    $sqlUrl = "$SUPABASE_URL/rest/v1/rpc/exec_sql"
    
    # Try direct SQL execution if available, otherwise show manual instructions
    Write-Host ""
    Write-Host "Manual Step Required:" -ForegroundColor Yellow
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Go to Supabase Dashboard: https://supabase.urbanaqura.com" -ForegroundColor White
    Write-Host "2. Click 'SQL Editor' in left menu" -ForegroundColor White
    Write-Host "3. Paste this SQL and click 'Run':" -ForegroundColor White
    Write-Host ""
    Write-Host $sql -ForegroundColor Green
    Write-Host ""
    Write-Host "4. Then press Enter here to continue..." -ForegroundColor Yellow
    
    $null = Read-Host
    
    Write-Host ""
    Write-Host "Opening browser for manual test..." -ForegroundColor Yellow
    Start-Process "http://localhost:5173/test/auth-test"
    
    Write-Host ""
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host " BROWSER OPENED" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "In the browser:" -ForegroundColor Yellow
    Write-Host "  1. Click 'Run All Tests' button" -ForegroundColor White
    Write-Host "  2. Watch 5 tests execute" -ForegroundColor White
    Write-Host "  3. All should pass" -ForegroundColor White
    Write-Host ""
    Write-Host "Test Details:" -ForegroundColor Yellow
    Write-Host "  Username: testuser" -ForegroundColor Gray
    Write-Host "  Quick Code: 123456" -ForegroundColor Gray
    Write-Host "  Role: ADMIN" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
