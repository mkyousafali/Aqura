Write-Host "Creating test notification for user b658eca1-3cc1-48b2-bd3c-33b81fab5a0f..." -ForegroundColor Cyan

# Load environment variables from frontend/.env
$envPath = "frontend\.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

$supabaseUrl = $env:VITE_SUPABASE_URL
$supabaseKey = $env:VITE_SUPABASE_ANON_KEY

if (-not $supabaseUrl -or -not $supabaseKey) {
    Write-Host "Error: Could not load Supabase credentials from frontend/.env" -ForegroundColor Red
    exit 1
}

Write-Host "Using Supabase URL: $supabaseUrl" -ForegroundColor Gray

# Create notification payload as JSON string
$timestamp = Get-Date -Format "o"
$notificationPayload = @"
{
  "title": "Test Push Notification",
  "body": "This is a test notification to verify push notifications are working correctly.",
  "created_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "target_type": "specific_users",
  "target_users": ["b658eca1-3cc1-48b2-bd3c-33b81fab5a0f"],
  "icon": "/icons/icon-192x192.png",
  "data": {
    "url": "/notifications",
    "test": true,
    "timestamp": "$timestamp"
  }
}
"@

# Insert notification via Supabase REST API
$headers = @{
    "apikey" = $supabaseKey
    "Authorization" = "Bearer $supabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

try {
    Write-Host "Inserting notification..." -ForegroundColor Yellow
    Write-Host "Payload: $notificationPayload" -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/notifications" -Method Post -Headers $headers -Body $notificationPayload -ContentType "application/json"
    
    Write-Host "✅ Notification created successfully!" -ForegroundColor Green
    Write-Host "   ID: $($response.id)" -ForegroundColor Cyan
    Write-Host "   Title: $($response.title)" -ForegroundColor Cyan
    Write-Host "   Created: $($response.created_at)" -ForegroundColor Cyan
    
    Write-Host "`n✅ The notification should now be queued automatically!" -ForegroundColor Green
    Write-Host "   Next: Start the dev server and log in as the user to test." -ForegroundColor Yellow
    
} catch {
    Write-Host "❌ Error creating notification: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
    exit 1
}
