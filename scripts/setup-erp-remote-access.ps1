# ERP SQL Server Remote Access Setup Script
# Run this on the SQL Server machine (192.168.0.3) as Administrator

param(
    [switch]$CheckOnly = $false,
    [switch]$ConfigureFirewall = $false,
    [int]$CustomPort = 1433
)

Write-Host "=== ERP SQL Server Remote Access Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  Warning: Not running as Administrator. Some operations may fail." -ForegroundColor Yellow
    Write-Host "   Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
}

# 1. Check public IP
Write-Host "1. Checking Public IP Address..." -ForegroundColor Green
try {
    $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 10).ip
    Write-Host "   Public IP: $publicIP" -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "   ❌ Could not retrieve public IP" -ForegroundColor Red
    $publicIP = "UNKNOWN"
}

# 2. Check local SQL Server connectivity
Write-Host "2. Testing Local SQL Server Connection..." -ForegroundColor Green
$serverIP = "192.168.0.3"
$testConnection = Test-NetConnection -ComputerName $serverIP -Port $CustomPort -WarningAction SilentlyContinue

if ($testConnection.TcpTestSucceeded) {
    Write-Host "   ✅ SQL Server is accessible on $serverIP`:$CustomPort" -ForegroundColor White
} else {
    Write-Host "   ❌ Cannot connect to SQL Server on $serverIP`:$CustomPort" -ForegroundColor Red
    Write-Host "   Check if SQL Server is running and TCP/IP is enabled" -ForegroundColor Yellow
}
Write-Host ""

# 3. Check Windows Firewall
Write-Host "3. Checking Windows Firewall Rules..." -ForegroundColor Green
$firewallRule = Get-NetFirewallRule -DisplayName "SQL Server*" -ErrorAction SilentlyContinue

if ($firewallRule) {
    Write-Host "   ✅ SQL Server firewall rule exists" -ForegroundColor White
    $firewallRule | Select-Object DisplayName, Enabled, Direction, Action | Format-Table
} else {
    Write-Host "   ⚠️  No SQL Server firewall rule found" -ForegroundColor Yellow
    
    if ($ConfigureFirewall -and $isAdmin) {
        Write-Host "   Creating firewall rule..." -ForegroundColor Cyan
        try {
            New-NetFirewallRule -DisplayName "SQL Server Remote Access" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort $CustomPort `
                -Action Allow `
                -Profile Any `
                -ErrorAction Stop
            Write-Host "   ✅ Firewall rule created successfully" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ Failed to create firewall rule: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "   Run with -ConfigureFirewall switch to create firewall rule" -ForegroundColor Yellow
    }
}
Write-Host ""

# 4. Check SQL Server services
Write-Host "4. Checking SQL Server Services..." -ForegroundColor Green
$sqlServices = Get-Service -Name "MSSQL*" -ErrorAction SilentlyContinue

if ($sqlServices) {
    $sqlServices | Select-Object Name, Status, StartType | Format-Table
} else {
    Write-Host "   ⚠️  No SQL Server services found" -ForegroundColor Yellow
    Write-Host "   This script may not be running on the SQL Server machine" -ForegroundColor Yellow
}
Write-Host ""

# 5. Check network interfaces
Write-Host "5. Network Interface Information..." -ForegroundColor Green
$networkAdapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" }
$networkAdapters | Select-Object IPAddress, InterfaceAlias, PrefixLength | Format-Table
Write-Host ""

# 6. Generate connection string
Write-Host "6. Connection String for External Access..." -ForegroundColor Green
Write-Host "   Server: $publicIP,$CustomPort" -ForegroundColor White
Write-Host "   Database: URBAN2_2025" -ForegroundColor White
Write-Host "   User: sa" -ForegroundColor White
Write-Host "   Password: Polosys*123" -ForegroundColor White
Write-Host ""

# 7. SQL Connection String for Node.js
Write-Host "7. Node.js (mssql) Connection Config..." -ForegroundColor Green
$nodeConfig = @"
const config = {
    user: 'sa',
    password: 'Polosys*123',
    server: '$publicIP',
    port: $CustomPort,
    database: 'URBAN2_2025',
    options: {
        encrypt: true,
        trustServerCertificate: true,
        enableArithAbort: true,
        connectionTimeout: 30000,
        requestTimeout: 30000
    }
};
"@
Write-Host $nodeConfig -ForegroundColor White
Write-Host ""

# 8. Instructions
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""

if (-not $testConnection.TcpTestSucceeded) {
    Write-Host "❌ SQL Server is not accessible locally. Fix this first:" -ForegroundColor Red
    Write-Host "   1. Open 'SQL Server Configuration Manager'" -ForegroundColor Yellow
    Write-Host "   2. Go to 'SQL Server Network Configuration' → 'Protocols for MSSQLSERVER'" -ForegroundColor Yellow
    Write-Host "   3. Right-click 'TCP/IP' → Enable" -ForegroundColor Yellow
    Write-Host "   4. Double-click 'TCP/IP' → IP Addresses tab → Set IPALL TCP Port to $CustomPort" -ForegroundColor Yellow
    Write-Host "   5. Restart SQL Server service" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "📋 Router Port Forwarding Configuration:" -ForegroundColor Cyan
Write-Host "   1. Access your router (usually 192.168.1.1 or 192.168.0.1)" -ForegroundColor White
Write-Host "   2. Navigate to Port Forwarding / Virtual Server section" -ForegroundColor White
Write-Host "   3. Create new rule:" -ForegroundColor White
Write-Host "      - Service Name: SQL Server" -ForegroundColor Gray
Write-Host "      - External Port: $CustomPort" -ForegroundColor Gray
Write-Host "      - Internal IP: $serverIP" -ForegroundColor Gray
Write-Host "      - Internal Port: $CustomPort" -ForegroundColor Gray
Write-Host "      - Protocol: TCP" -ForegroundColor Gray
Write-Host "   4. Save and apply changes" -ForegroundColor White
Write-Host ""

Write-Host "🔒 Security Recommendations:" -ForegroundColor Cyan
Write-Host "   1. Use a non-standard port (e.g., 14330) instead of 1433" -ForegroundColor Yellow
Write-Host "   2. Change default 'sa' password to something stronger" -ForegroundColor Yellow
Write-Host "   3. Consider using VPN (Tailscale) for production" -ForegroundColor Yellow
Write-Host "   4. Enable SQL Server encryption" -ForegroundColor Yellow
Write-Host "   5. Set up IP whitelisting if possible" -ForegroundColor Yellow
Write-Host ""

Write-Host "🧪 Testing from External Network:" -ForegroundColor Cyan
Write-Host "   1. Disconnect from local network (use mobile hotspot)" -ForegroundColor White
Write-Host "   2. Run: Test-NetConnection -ComputerName $publicIP -Port $CustomPort" -ForegroundColor White
Write-Host "   3. Or use the test-external-erp.js script" -ForegroundColor White
Write-Host ""

Write-Host "📝 Update ERP Connection in Database:" -ForegroundColor Cyan
$updateSQL = "UPDATE erp_connections SET server_ip = '$publicIP', server_name = '$publicIP,$CustomPort' WHERE branch_id = 3;"
Write-Host "   $updateSQL" -ForegroundColor White
Write-Host ""

Write-Host "=== Script Complete ===" -ForegroundColor Cyan
