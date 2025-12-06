# Test Script: Create Test User and Run Authentication Tests
# This script creates the test user and verifies authentication

$SUPABASE_URL = "https://supabase.urbanaqura.com"
$SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0"

Write-Host "🧪 AUTHENTICATION TEST RUNNER" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create test user
Write-Host "📝 Step 1: Creating test user in database..." -ForegroundColor Yellow

$testUser = @{
    username = "testuser"
    email = "test@aqura.local"
    password_hash = '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/exa'
    quick_access_code = "123456"
    role = "admin"
    role_type = "ADMIN"
    user_type = "EMPLOYEE"
    status = "ACTIVE"
} | ConvertTo-Json

$headers = @{
    "apikey" = $SERVICE_KEY
    "Authorization" = "Bearer $SERVICE_KEY"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

try {
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/users" -Method Post -Headers $headers -Body $testUser -ErrorAction Stop
    Write-Host "✅ Test user created successfully!" -ForegroundColor Green
    Write-Host "   Username: testuser" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "ℹ️  Test user may already exist or error occurred" -ForegroundColor Yellow
    Write-Host "   Continuing with verification..." -ForegroundColor Gray
    Write-Host ""
}

# Step 2: Verify test user exists
Write-Host "📝 Step 2: Verifying test user in database..." -ForegroundColor Yellow

try {
    $verifyHeaders = @{
        "apikey" = $SERVICE_KEY
        "Authorization" = "Bearer $SERVICE_KEY"
    }
    
    $selectFields = "id,username,email,role_type,status,quick_access_code"
    $userUrl = "$SUPABASE_URL/rest/v1/users?username=eq.testuser&select=$selectFields"
    $user = Invoke-RestMethod -Uri $userUrl -Method Get -Headers $verifyHeaders
    
    if ($user -and $user.Count -gt 0) {
        Write-Host "✅ Test user verified in database!" -ForegroundColor Green
        Write-Host "   Username: $($user[0].username)" -ForegroundColor Gray
        Write-Host "   Email: $($user[0].email)" -ForegroundColor Gray
        Write-Host "   Role: $($user[0].role_type)" -ForegroundColor Gray
        Write-Host "   Status: $($user[0].status)" -ForegroundColor Gray
        Write-Host "   Quick Access Code: $($user[0].quick_access_code)" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "❌ Test user not found in database!" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
} catch {
    Write-Host "❌ Failed to verify test user: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# Step 3: Instructions for browser test
Write-Host "📝 Step 3: Next steps for browser testing..." -ForegroundColor Yellow
Write-Host ""
Write-Host "✅ Test user is ready! Now:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Open your browser" -ForegroundColor White
Write-Host "2. Navigate to: http://localhost:5173/test/auth-test" -ForegroundColor Cyan
Write-Host "3. Click: '▶️ Run All Tests' button" -ForegroundColor White
Write-Host "4. Watch the 5 tests execute" -ForegroundColor White
Write-Host ""
Write-Host "Expected Results:" -ForegroundColor Yellow
Write-Host "  ✅ User Table Access      → testuser found" -ForegroundColor Gray
Write-Host "  ✅ Authentication         → Code 123456 validated" -ForegroundColor Gray
Write-Host "  ✅ Session Creation       → User in store" -ForegroundColor Gray
Write-Host "  ✅ RLS Enforcement        → Policies active" -ForegroundColor Gray
Write-Host "  ✅ Data Access            → Protected data accessible" -ForegroundColor Gray
Write-Host ""
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "🎯 Ready to test! Open the browser now." -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Cyan
