# Check hr_positions table structure using PowerShell and curl

Write-Host "=== Checking hr_positions table structure ===" -ForegroundColor Green

# Supabase configuration
$SUPABASE_URL = "https://vmypotfsyrvuublyddyt.supabase.co"
$SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs"

# Check hr_positions table structure
Write-Host "`n1. Checking hr_positions table structure..." -ForegroundColor Yellow

$headers = @{
    "apikey" = $SUPABASE_ANON_KEY
    "Authorization" = "Bearer $SUPABASE_ANON_KEY"
    "Content-Type" = "application/json"
}

try {
    # Get table structure from information_schema
    $structureQuery = "column_name,data_type,is_nullable"
    $structureUrl = "$SUPABASE_URL/rest/v1/rpc/exec_sql"
    
    $structureBody = @{
        sql = "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'hr_positions' ORDER BY ordinal_position"
    } | ConvertTo-Json

    Write-Host "Executing SQL query for hr_positions structure..." -ForegroundColor Cyan
    $structureResponse = Invoke-RestMethod -Uri $structureUrl -Method POST -Headers $headers -Body $structureBody
    
    if ($structureResponse) {
        Write-Host "hr_positions table columns:" -ForegroundColor Green
        $structureResponse | Format-Table -AutoSize
    }
} catch {
    Write-Host "Error checking table structure: $_" -ForegroundColor Red
    Write-Host "Trying alternative method..." -ForegroundColor Yellow
    
    # Alternative: Try to get sample data to see column names
    try {
        $sampleUrl = "$SUPABASE_URL/rest/v1/hr_positions?limit=1"
        Write-Host "Getting sample data from hr_positions..." -ForegroundColor Cyan
        $sampleResponse = Invoke-RestMethod -Uri $sampleUrl -Method GET -Headers $headers
        
        if ($sampleResponse -and $sampleResponse.Count -gt 0) {
            Write-Host "Sample hr_positions record:" -ForegroundColor Green
            $sampleResponse[0] | Format-List
            
            Write-Host "Available columns in hr_positions:" -ForegroundColor Green
            $sampleResponse[0].PSObject.Properties.Name | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
        } else {
            Write-Host "No data found in hr_positions table" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error getting sample data: $_" -ForegroundColor Red
    }
}

# Check hr_departments table as well (might be related)
Write-Host "`n2. Checking hr_departments table..." -ForegroundColor Yellow
try {
    $deptUrl = "$SUPABASE_URL/rest/v1/hr_departments?limit=1"
    $deptResponse = Invoke-RestMethod -Uri $deptUrl -Method GET -Headers $headers
    
    if ($deptResponse -and $deptResponse.Count -gt 0) {
        Write-Host "Sample hr_departments record:" -ForegroundColor Green
        $deptResponse[0] | Format-List
    }
} catch {
    Write-Host "Error checking hr_departments: $_" -ForegroundColor Red
}

# Check hr_levels table as well
Write-Host "`n3. Checking hr_levels table..." -ForegroundColor Yellow
try {
    $levelsUrl = "$SUPABASE_URL/rest/v1/hr_levels?limit=1"
    $levelsResponse = Invoke-RestMethod -Uri $levelsUrl -Method GET -Headers $headers
    
    if ($levelsResponse -and $levelsResponse.Count -gt 0) {
        Write-Host "Sample hr_levels record:" -ForegroundColor Green
        $levelsResponse[0] | Format-List
    }
} catch {
    Write-Host "Error checking hr_levels: $_" -ForegroundColor Red
}

Write-Host "`n=== Analysis Complete ===" -ForegroundColor Green