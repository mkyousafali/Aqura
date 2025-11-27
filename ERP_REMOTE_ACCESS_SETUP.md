# ERP SQL Server Remote Access Setup Guide

## Overview
Your SQL Server is currently at `192.168.0.3` (local network). To access it from outside your network (e.g., from Vercel deployment), you need to:
1. Configure SQL Server for remote access
2. Set up router port forwarding
3. Use your public IP address
4. Consider security implications

---

## Option 1: Direct Port Forwarding (Simple but Less Secure)

### Step 1: Configure SQL Server for Remote Access

1. **Enable TCP/IP Protocol**:
   - Open **SQL Server Configuration Manager**
   - Navigate to: `SQL Server Network Configuration` → `Protocols for MSSQLSERVER`
   - Right-click **TCP/IP** → **Enable**
   - Double-click **TCP/IP** → Go to **IP Addresses** tab
   - Scroll to **IPALL** section
   - Set **TCP Port** to `1433` (default SQL Server port)
   - Click **OK** and restart SQL Server service

2. **Configure Windows Firewall**:
   ```powershell
   # Run PowerShell as Administrator
   New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
   ```

3. **Allow Remote Connections in SQL Server**:
   - Open **SQL Server Management Studio (SSMS)**
   - Right-click server name → **Properties**
   - Go to **Connections** page
   - Check **Allow remote connections to this server**
   - Set timeout to appropriate value (e.g., 600 seconds)

### Step 2: Configure Router Port Forwarding

1. **Find Your Public IP**:
   ```powershell
   # Check your public IP
   Invoke-RestMethod -Uri "https://api.ipify.org?format=json" | Select-Object -ExpandProperty ip
   ```

2. **Access Your Router**:
   - Usually at `192.168.1.1` or `192.168.0.1`
   - Login with admin credentials

3. **Set Up Port Forwarding**:
   - Navigate to **Port Forwarding** or **Virtual Server** section
   - Create new rule:
     - **Service Name**: SQL Server
     - **External Port**: 1433 (or custom port like 14330 for security)
     - **Internal IP**: 192.168.0.3
     - **Internal Port**: 1433
     - **Protocol**: TCP
   - Save and apply settings

4. **Test Connection**:
   ```powershell
   # Test from external network (use mobile hotspot to test)
   Test-NetConnection -ComputerName YOUR_PUBLIC_IP -Port 1433
   ```

### Step 3: Update ERP Connection Configuration

Update your `erp_connections` table to use public IP:

```sql
-- Update existing configuration
UPDATE erp_connections 
SET 
    server_ip = 'YOUR_PUBLIC_IP_HERE',  -- e.g., '203.45.67.89'
    server_name = 'YOUR_PUBLIC_IP_HERE,1433'  -- Use comma for port in connection string
WHERE branch_id = 3;
```

---

## Option 2: VPN Tunnel (More Secure - Recommended)

### Why VPN is Better:
- ✅ Encrypted connection
- ✅ No direct database exposure to internet
- ✅ Can access all local resources securely
- ✅ Better for production environments

### Popular VPN Solutions:

#### A. WireGuard VPN (Free, Fast)
1. Install WireGuard on server (192.168.0.3)
2. Install WireGuard on Vercel deployment or use VPN gateway
3. Configure peer-to-peer connection
4. Access database via local IP (192.168.0.3) through tunnel

#### B. Tailscale (Easiest, Free Tier Available)
1. Install Tailscale on server: https://tailscale.com/download/windows
2. Install Tailscale on deployment server or gateway
3. Connect both devices to same Tailscale network
4. Use Tailscale IP (100.x.x.x) to connect to SQL Server
5. No router configuration needed!

**Tailscale Setup Example**:
```powershell
# Install Tailscale on Windows Server
winget install tailscale.tailscale

# Start Tailscale and login
tailscale up

# Get your Tailscale IP
tailscale ip -4
# Example output: 100.64.0.5
```

Then update connection:
```sql
UPDATE erp_connections 
SET server_ip = '100.64.0.5'  -- Use Tailscale IP
WHERE branch_id = 3;
```

#### C. OpenVPN (Traditional, Flexible)
1. Set up OpenVPN server on network
2. Configure client certificates
3. Connect deployment server to VPN
4. Access via local IP through tunnel

---

## Option 3: Database Replication/Sync (Most Robust)

For production systems, consider:

### A. Azure SQL Database Sync
- Replicate data to Azure SQL Database
- Connect Vercel to Azure SQL (no port forwarding needed)
- Automatic sync between on-premise and cloud

### B. AWS RDS SQL Server
- Similar to Azure but on AWS
- Use AWS Database Migration Service

### C. Supabase as Cache Layer
- Store frequently accessed data in Supabase
- Sync from SQL Server on schedule
- Vercel connects to Supabase (already configured)

---

## Security Considerations

### ⚠️ Important Security Measures:

1. **Never Use Port 1433 Directly**:
   ```
   Bad:  PUBLIC_IP:1433
   Good: PUBLIC_IP:14330 (mapped to internal 1433)
   ```

2. **Use Strong Credentials**:
   - Current: `sa/Polosys*123`
   - Consider creating dedicated user with limited permissions

3. **Enable SQL Server Encryption**:
   ```sql
   -- Force encryption on SQL Server
   -- In SSMS → Server Properties → Security
   -- Check "Force Encryption"
   ```

4. **Restrict IP Access**:
   - Configure SQL Server to only accept connections from specific IPs
   - Use Windows Firewall rules to limit access

5. **Monitor Access Logs**:
   ```sql
   -- Enable SQL Server audit logging
   -- Check logs regularly for suspicious activity
   ```

6. **Use VPN for Production**:
   - Direct port forwarding should only be temporary/testing
   - Always use VPN for production deployments

---

## Quick Setup Script for Port Forwarding

```powershell
# Run as Administrator on SQL Server machine (192.168.0.3)

# 1. Enable SQL Server TCP/IP (requires manual SQL Config Manager)
Write-Host "⚠️ Manual Step: Enable TCP/IP in SQL Server Configuration Manager"
Write-Host "   Path: SQL Server Network Configuration → Protocols → TCP/IP"
Write-Host ""

# 2. Configure Windows Firewall
Write-Host "Configuring Windows Firewall..."
New-NetFirewallRule -DisplayName "SQL Server Remote Access" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 1433 `
    -Action Allow `
    -Profile Any

# 3. Check public IP
Write-Host "`nYour public IP address:"
$publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
Write-Host $publicIP
Write-Host ""

# 4. Test local SQL Server
Write-Host "Testing local SQL Server connection..."
$serverIP = "192.168.0.3"
Test-NetConnection -ComputerName $serverIP -Port 1433

Write-Host "`n✅ Next Steps:"
Write-Host "1. Configure router port forwarding: External $publicIP:1433 → Internal 192.168.0.3:1433"
Write-Host "2. Restart SQL Server service"
Write-Host "3. Test connection from external network"
Write-Host "4. Update erp_connections table with public IP: $publicIP"
```

---

## Recommended Approach for Aqura System

### For Development/Testing:
- ✅ Use **Tailscale** (easiest, no router config)
- ✅ Install on server and deployment environment
- ✅ Connect via Tailscale IPs

### For Production:
- ✅ Use **WireGuard VPN** or **OpenVPN**
- ✅ Or consider **Azure SQL Database Sync**
- ✅ Keep on-premise database behind firewall
- ✅ Replicate to cloud database for external access

### Immediate Test Setup:
1. Use port forwarding (Option 1) for quick testing
2. Change SQL port to non-standard (e.g., 14330)
3. Test from external network
4. Implement VPN before production deployment

---

## Testing Connection from Outside Network

### Test Script (run from external network):
```javascript
// test-external-erp.js
import sql from 'mssql';

const config = {
    user: 'sa',
    password: 'Polosys*123',
    server: 'YOUR_PUBLIC_IP',  // or Tailscale IP
    port: 1433,  // or custom port
    database: 'URBAN2_2025',
    options: {
        encrypt: true,  // Use encryption
        trustServerCertificate: true,
        enableArithAbort: true,
        connectionTimeout: 30000,
        requestTimeout: 30000
    }
};

try {
    console.log('Connecting to SQL Server...');
    const pool = await sql.connect(config);
    console.log('✅ Connected successfully!');
    
    const result = await pool.request().query('SELECT @@VERSION');
    console.log('SQL Server version:', result.recordset[0]);
    
    await pool.close();
} catch (err) {
    console.error('❌ Connection failed:', err.message);
}
```

---

## Troubleshooting

### Connection Refused:
- ✅ Check SQL Server is running
- ✅ Verify TCP/IP is enabled
- ✅ Check Windows Firewall rules
- ✅ Verify router port forwarding

### Timeout:
- ✅ Check public IP is correct
- ✅ Verify router has port forwarding rule
- ✅ Test from external network (not same LAN)

### Authentication Failed:
- ✅ Verify SQL Server authentication mode (mixed mode)
- ✅ Check username/password
- ✅ Ensure 'sa' account is enabled

### Can Connect Locally but Not Remotely:
- ✅ Router port forwarding not configured
- ✅ ISP blocking port 1433 (use custom port)
- ✅ Public IP changed (dynamic IP - consider DDNS)

---

## Dynamic IP Solution (DDNS)

If your public IP changes frequently:

1. **Use No-IP or DynDNS Service**:
   - Sign up for free DDNS service
   - Install client on server
   - Get hostname like: `yourserver.ddns.net`
   - Use hostname instead of IP

2. **Update Connection String**:
   ```sql
   UPDATE erp_connections 
   SET server_ip = 'yourserver.ddns.net'
   WHERE branch_id = 3;
   ```

---

## Contact ISP Considerations

Some ISPs block common ports or don't allow inbound connections on residential plans. If connection fails:

1. **Check with ISP** if they block port 1433
2. **Use non-standard port** (e.g., 14330)
3. **Upgrade to business plan** if needed
4. **Consider VPN solution** (works regardless of ISP restrictions)
