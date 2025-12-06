# Test Script: Create Test User and Run Authentication Tests

$SUPABASE_URL = "https://supabase.urbanaqura.com"
$SERVICE_KEY = $env:VITE_SUPABASE_SERVICE_KEY

Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host " AUTHENTICATION TEST RUNNER" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create test user
Write-Host "Step 1: Creating test user..." -ForegroundColor Yellow

$testUser = @{
    username = "testuser"
    email = "test@aqura.local"
    password_hash = '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/exa'
    quick_access_code = "123456"
    role = "admin"
    role_type = "ADMIN"
    user_type = "EMPLOYEE"
    status = "ACTIVE"
}

$jsonBody = $testUser | ConvertTo-Json

$headers = @{
    "apikey" = $SERVICE_KEY
    "Authorization" = "Bearer $SERVICE_KEY"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

try {
    $createUrl = "$SUPABASE_URL/rest/v1/users"
    $response = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $headers -Body $jsonBody -ErrorAction Stop
    Write-Host "  Test user created!" -ForegroundColor Green
}
catch {
    Write-Host "  Test user may already exist (continuing...)" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Verify test user exists
Write-Host "Step 2: Verifying test user..." -ForegroundColor Yellow

$verifyHeaders = @{
    "apikey" = $SERVICE_KEY
    "Authorization" = "Bearer $SERVICE_KEY"
}

try {
    $verifyUrl = "$SUPABASE_URL/rest/v1/users?username=eq.testuser"
    $user = Invoke-RestMethod -Uri $verifyUrl -Method Get -Headers $verifyHeaders
    
    if ($user -and $user.Count -gt 0) {
        Write-Host "  Test user verified!" -ForegroundColor Green
        Write-Host "    Username: $($user[0].username)" -ForegroundColor Gray
        Write-Host "    Email: $($user[0].email)" -ForegroundColor Gray
        Write-Host "    Role: $($user[0].role_type)" -ForegroundColor Gray
        Write-Host "    Status: $($user[0].status)" -ForegroundColor Gray
        Write-Host "    Quick Code: $($user[0].quick_access_code)" -ForegroundColor Gray
    }
    else {
        Write-Host "  ERROR: Test user not found!" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ERROR: Cannot verify user - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Open browser test page
Write-Host "Step 3: Opening browser test page..." -ForegroundColor Yellow

$testUrl = "http://localhost:5173/test/auth-test"

try {
    Start-Process $testUrl
    Write-Host "  Browser opened!" -ForegroundColor Green
}
catch {
    Write-Host "  Could not open browser automatically" -ForegroundColor Yellow
    Write-Host "  Please open manually: $testUrl" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host " TEST USER READY!" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Browser should open automatically" -ForegroundColor White
Write-Host "  2. If not, visit: $testUrl" -ForegroundColor Cyan
Write-Host "  3. Click 'Run All Tests' button" -ForegroundColor White
Write-Host "  4. All 5 tests should pass" -ForegroundColor White
Write-Host ""
Write-Host "Expected:" -ForegroundColor Yellow
Write-Host "   User Table Access" -ForegroundColor Gray
Write-Host "   Authentication" -ForegroundColor Gray
Write-Host "   Session Creation" -ForegroundColor Gray
Write-Host "   RLS Enforcement" -ForegroundColor Gray
Write-Host "   Data Access" -ForegroundColor Gray
Write-Host ""
