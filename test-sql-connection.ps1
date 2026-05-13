# Test SQL Server Connection to ERP Database
$Server = "192.168.0.3"
$Database = "URBAN2_2025"
$User = "sa"
$Password = "Polosys*123"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SQL SERVER CONNECTION TEST" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host "`n[1/4] Loading SQL Client..." -ForegroundColor Yellow
[System.Reflection.Assembly]::LoadWithPartialName("System.Data.SqlClient") | Out-Null

Write-Host "[2/4] Building connection string..." -ForegroundColor Yellow
$connStr = "Server=$Server;Database=$Database;User Id=$User;Password=$Password;Connection Timeout=10;Encrypt=false;TrustServerCertificate=true;"
Write-Host "      Server: $Server"
Write-Host "      Database: $Database"
Write-Host "      User: $User"

Write-Host "`n[3/4] Opening connection..." -ForegroundColor Yellow
$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = $connStr

try {
    $conn.Open()
    Write-Host "      ✅ SUCCESS!" -ForegroundColor Green
    Write-Host "      Connection State: $($conn.State)"
    
    Write-Host "`n[4/4] Querying database..." -ForegroundColor Yellow
    
    # Check tables exist
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = @"
SELECT 
    (SELECT COUNT(*) FROM PrivilegeCards) as PrivilegeCards,
    (SELECT COUNT(*) FROM InvTransactionMaster) as InvTransactions,
    (SELECT COUNT(*) FROM BranchMaster) as Branches
"@
    
    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $pc = $reader["PrivilegeCards"]
        $itm = $reader["InvTransactions"]
        $bm = $reader["Branches"]
        Write-Host "      ✅ PrivilegeCards: $pc records"
        Write-Host "      ✅ InvTransactionMaster: $itm records"
        Write-Host "      ✅ BranchMaster: $bm records"
    }
    $reader.Close()
    
    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "✅ ALL TESTS PASSED - ERP DATABASE CONNECTED!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    
} catch {
    Write-Host "      ❌ ERROR!" -ForegroundColor Red
    Write-Host "      Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n================================================" -ForegroundColor Red
    Write-Host "❌ CONNECTION FAILED" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    exit 1
} finally {
    if ($conn.State -eq "Open") {
        $conn.Close()
    }
}
