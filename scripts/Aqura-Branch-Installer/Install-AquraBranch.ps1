<#
.SYNOPSIS
    Aqura Branch Installer — Full Automated Setup (VM + Supabase + Schema + Frontend + Cloud Registration)
    
.DESCRIPTION
    This script automatically installs a COMPLETE Aqura branch system on a Windows Server:
      1. Hyper-V VM (pre-built Ubuntu template)
      2. Supabase (configured with cloud-compatible JWT keys)
      3. Database schema sync from cloud
      4. Aqura frontend (Node.js + PM2, served on port 3001)
      5. Import functions for data sync
      6. Register branch on cloud for ongoing sync
      7. Auto-start on boot (VM + PM2)
    
    After running this script, users can open http://<VM-IP>:3001 and use Aqura.
    Data is synced from cloud via the Branch Sync tab in Storage Manager.
    
    Requirements:
    - Windows Server 2019/2022 with 16+ GB RAM
    - At least 2 NICs (one for VM)
    - 50+ GB free disk space
    - Administrator access
    - template\supabase-template.vhdx in same directory
    - template\aqura-frontend-build.zip (pre-built frontend)
    - SSH key access to cloud server (8.213.42.21) for schema sync
    
.EXAMPLE
    .\Install-AquraBranch.ps1
    
.NOTES
    Author: Aqura DevOps
    Version: 2.0.0
    Date: 2026-02-16
#>

#Requires -RunAsAdministrator

param(
    [switch]$SkipHyperV,
    [switch]$SkipVMCreation,
    [switch]$ForceReinstall
)

# ═══════════════════════════════════════════════════════════
# CONFIGURATION — Edit these for each branch or use wizard
# ═══════════════════════════════════════════════════════════

$script:Config = @{
    # VM Settings
    VMName           = ""
    VMRamGB          = 8
    VMCpuCount       = 4
    VMDiskPath       = ""
    VMSwitchName     = "ExternalSwitch"
    VMSwitchNIC      = ""
    
    # Network
    StaticIP         = ""
    Gateway          = "192.168.0.1"
    DNS              = "8.8.8.8"
    SubnetMask       = "255.255.255.0"
    SubnetPrefix     = 24
    
    # Branch Info
    BranchName       = ""
    BranchID         = 0
    
    # Supabase
    DashboardPassword = "LocalAdmin2025"
    
    # Cloud Server (for schema sync)
    CloudServerIP    = "8.213.42.21"
    CloudSSHKey      = "$env:USERPROFILE\.ssh\id_ed25519_nopass"
    CloudJWTSecret   = $env:AQURA_JWT_SECRET
    CloudAnonKey     = $env:AQURA_ANON_KEY
    CloudServiceKey  = $env:AQURA_SERVICE_KEY
    CloudPostgresPass = $env:AQURA_POSTGRES_PASSWORD
    CloudSupabaseURL = "https://supabase.urbanaqura.com"
    
    # Template
    TemplatePath     = ""
    FrontendBuildPath = ""
}

# ═══════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════

function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $border = "═" * ($Text.Length + 4)
    Write-Host ""
    Write-Host "╔$border╗" -ForegroundColor $Color
    Write-Host "║  $Text  ║" -ForegroundColor $Color
    Write-Host "╚$border╝" -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "  ► $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "  ✓ $Text" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  ✗ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  ℹ $Text" -ForegroundColor Gray
}

function Confirm-Continue {
    param([string]$Message = "Continue?")
    $response = Read-Host "$Message (Y/n)"
    if ($response -eq 'n' -or $response -eq 'N') {
        Write-Fail "Aborted by user."
        exit 1
    }
}

function Wait-ForSSH {
    param(
        [string]$IP,
        [int]$TimeoutSeconds = 300
    )
    Write-Step "Waiting for VM to be reachable via SSH at $IP..."
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
        $result = Test-NetConnection -ComputerName $IP -Port 22 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Success "SSH is reachable at $IP"
            return $true
        }
        Start-Sleep -Seconds 5
    }
    Write-Fail "Timeout waiting for SSH at $IP after $TimeoutSeconds seconds"
    return $false
}

# ═══════════════════════════════════════════════════════════
# WIZARD — Interactive Branch Configuration
# ═══════════════════════════════════════════════════════════

function Show-Wizard {
    Write-Banner "AQURA BRANCH INSTALLER — Setup Wizard" "Magenta"
    Write-Host "  This wizard will configure the local Supabase instance for your branch." -ForegroundColor White
    Write-Host ""

    # Validate required environment variables
    $missingEnv = @()
    if ([string]::IsNullOrWhiteSpace($script:Config.CloudJWTSecret)) { $missingEnv += 'AQURA_JWT_SECRET' }
    if ([string]::IsNullOrWhiteSpace($script:Config.CloudAnonKey)) { $missingEnv += 'AQURA_ANON_KEY' }
    if ([string]::IsNullOrWhiteSpace($script:Config.CloudServiceKey)) { $missingEnv += 'AQURA_SERVICE_KEY' }
    if ([string]::IsNullOrWhiteSpace($script:Config.CloudPostgresPass)) { $missingEnv += 'AQURA_POSTGRES_PASSWORD' }
    if ($missingEnv.Count -gt 0) {
        Write-Fail "Missing required environment variables: $($missingEnv -join ', ')"
        Write-Host '  Set them before running: $env:AQURA_JWT_SECRET = "your-jwt-secret"' -ForegroundColor Yellow
        exit 1
    }
    
    # Branch Name
    $script:Config.BranchName = Read-Host "  Enter branch name (e.g., 'Branch 3 - Warehouse')"
    if ([string]::IsNullOrWhiteSpace($script:Config.BranchName)) {
        Write-Fail "Branch name is required."
        exit 1
    }
    
    # Branch ID
    $branchId = Read-Host "  Enter branch ID number (e.g., 3, 4, 5)"
    $script:Config.BranchID = [int]$branchId
    
    # VM Name
    $defaultVMName = "Aqura-Supabase-Branch$($script:Config.BranchID)"
    $vmName = Read-Host "  VM name [$defaultVMName]"
    $script:Config.VMName = if ([string]::IsNullOrWhiteSpace($vmName)) { $defaultVMName } else { $vmName }
    
    # Static IP
    $defaultIP = "192.168.0.1$($script:Config.BranchID)1"
    if ($script:Config.BranchID -ge 10) { $defaultIP = "192.168.0.$([int]$script:Config.BranchID * 10 + 1)" }
    $ip = Read-Host "  Static IP for VM [$defaultIP]"
    $script:Config.StaticIP = if ([string]::IsNullOrWhiteSpace($ip)) { $defaultIP } else { $ip }
    
    # Gateway
    $gw = Read-Host "  Gateway [$($script:Config.Gateway)]"
    if (-not [string]::IsNullOrWhiteSpace($gw)) { $script:Config.Gateway = $gw }
    
    # DNS
    $dns = Read-Host "  DNS Server [$($script:Config.DNS)]"
    if (-not [string]::IsNullOrWhiteSpace($dns)) { $script:Config.DNS = $dns }
    
    # Dashboard Password
    $dashPwd = Read-Host "  Supabase Studio password [$($script:Config.DashboardPassword)]"
    if (-not [string]::IsNullOrWhiteSpace($dashPwd)) { $script:Config.DashboardPassword = $dashPwd }
    
    # RAM
    $ram = Read-Host "  VM RAM in GB [$($script:Config.VMRamGB)]"
    if (-not [string]::IsNullOrWhiteSpace($ram)) { $script:Config.VMRamGB = [int]$ram }
    
    # CPU
    $cpu = Read-Host "  VM CPU cores [$($script:Config.VMCpuCount)]"
    if (-not [string]::IsNullOrWhiteSpace($cpu)) { $script:Config.VMCpuCount = [int]$cpu }
    
    # Disk Path
    $defaultDisk = "D:\VMs\$($script:Config.VMName).vhdx"
    $disk = Read-Host "  VM disk path [$defaultDisk]"
    $script:Config.VMDiskPath = if ([string]::IsNullOrWhiteSpace($disk)) { $defaultDisk } else { $disk }
    
    # NIC for VM Switch
    Write-Host ""
    Write-Step "Available network adapters:"
    $nics = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object Name, InterfaceDescription, MacAddress
    $nics | Format-Table -AutoSize
    
    $existingSwitches = Get-VMSwitch -ErrorAction SilentlyContinue
    if ($existingSwitches | Where-Object { $_.SwitchType -eq 'External' }) {
        $extSwitch = $existingSwitches | Where-Object { $_.SwitchType -eq 'External' } | Select-Object -First 1
        Write-Success "Found existing external switch: $($extSwitch.Name)"
        $script:Config.VMSwitchName = $extSwitch.Name
        $useExisting = Read-Host "  Use existing switch '$($extSwitch.Name)'? (Y/n)"
        if ($useExisting -eq 'n' -or $useExisting -eq 'N') {
            $script:Config.VMSwitchNIC = Read-Host "  Enter NIC name for new VM switch"
            $newSwitchName = Read-Host "  Switch name [ExternalSwitch]"
            if (-not [string]::IsNullOrWhiteSpace($newSwitchName)) { $script:Config.VMSwitchName = $newSwitchName }
        }
    } else {
        $script:Config.VMSwitchNIC = Read-Host "  Enter NIC name for VM switch (use a secondary NIC)"
        $switchName = Read-Host "  Switch name [ExternalSwitch]"
        if (-not [string]::IsNullOrWhiteSpace($switchName)) { $script:Config.VMSwitchName = $switchName }
    }
    
    # Template location
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = $PSScriptRoot }
    if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = (Get-Location).Path }
    
    $defaultTemplate = Join-Path $scriptDir "template\supabase-template.vhdx"
    if (-not (Test-Path $defaultTemplate)) {
        $defaultTemplate = "D:\Aqura-Branch-Installer\template\supabase-template.vhdx"
    }
    $tmpl = Read-Host "  Template VHDX path [$defaultTemplate]"
    $script:Config.TemplatePath = if ([string]::IsNullOrWhiteSpace($tmpl)) { $defaultTemplate } else { $tmpl }
    
    # Frontend build location
    $defaultFrontend = Join-Path $scriptDir "template\aqura-frontend-build.zip"
    if (-not (Test-Path $defaultFrontend)) {
        $defaultFrontend = "D:\Aqura-Branch-Installer\template\aqura-frontend-build.zip"
    }
    $fe = Read-Host "  Frontend build ZIP path [$defaultFrontend]"
    $script:Config.FrontendBuildPath = if ([string]::IsNullOrWhiteSpace($fe)) { $defaultFrontend } else { $fe }
    
    # Cloud SSH key
    $defaultKey = "$env:USERPROFILE\.ssh\id_ed25519_nopass"
    if (-not (Test-Path $defaultKey)) { $defaultKey = "$env:USERPROFILE\.ssh\id_ed25519" }
    $key = Read-Host "  Cloud SSH key path [$defaultKey]"
    $script:Config.CloudSSHKey = if ([string]::IsNullOrWhiteSpace($key)) { $defaultKey } else { $key }
    
    # Summary
    Write-Host ""
    Write-Banner "Configuration Summary" "Cyan"
    Write-Host "  Branch:           $($script:Config.BranchName) (ID: $($script:Config.BranchID))" -ForegroundColor White
    Write-Host "  VM Name:          $($script:Config.VMName)" -ForegroundColor White
    Write-Host "  VM RAM/CPU:       $($script:Config.VMRamGB) GB / $($script:Config.VMCpuCount) cores" -ForegroundColor White
    Write-Host "  VM Disk:          $($script:Config.VMDiskPath)" -ForegroundColor White
    Write-Host "  VM Switch:        $($script:Config.VMSwitchName)" -ForegroundColor White
    Write-Host "  Static IP:        $($script:Config.StaticIP)" -ForegroundColor White
    Write-Host "  Gateway:          $($script:Config.Gateway)" -ForegroundColor White
    Write-Host "  DNS:              $($script:Config.DNS)" -ForegroundColor White
    Write-Host "  Studio Password:  $($script:Config.DashboardPassword)" -ForegroundColor White
    Write-Host "  Template:         $($script:Config.TemplatePath)" -ForegroundColor White
    Write-Host "  Frontend Build:   $($script:Config.FrontendBuildPath)" -ForegroundColor White
    Write-Host "  Cloud SSH Key:    $($script:Config.CloudSSHKey)" -ForegroundColor White
    Write-Host ""
    
    Confirm-Continue "  Proceed with installation?"
}

# ═══════════════════════════════════════════════════════════
# PHASE 1: PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════

function Test-Prerequisites {
    Write-Banner "Phase 1: Pre-flight Checks"
    
    # Check admin
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Fail "This script must be run as Administrator!"
        exit 1
    }
    Write-Success "Running as Administrator"
    
    # Check template exists
    if (-not (Test-Path $script:Config.TemplatePath)) {
        Write-Fail "Template VHDX not found at: $($script:Config.TemplatePath)"
        Write-Info "Please copy supabase-template.vhdx to the template\ folder"
        exit 1
    }
    $templateSize = [math]::Round((Get-Item $script:Config.TemplatePath).Length / 1GB, 2)
    Write-Success "Template found: $templateSize GB"
    
    # Check frontend build exists
    if (-not (Test-Path $script:Config.FrontendBuildPath)) {
        Write-Fail "Frontend build not found at: $($script:Config.FrontendBuildPath)"
        Write-Info "Run Build-Frontend.ps1 first to create aqura-frontend-build.zip"
        exit 1
    }
    $feSize = [math]::Round((Get-Item $script:Config.FrontendBuildPath).Length / 1MB, 1)
    Write-Success "Frontend build found: $feSize MB"
    
    # Check cloud SSH key
    if (-not (Test-Path $script:Config.CloudSSHKey)) {
        Write-Fail "Cloud SSH key not found at: $($script:Config.CloudSSHKey)"
        Write-Info "Need SSH key for schema sync from cloud server"
        exit 1
    }
    Write-Success "Cloud SSH key found"
    
    # Check disk space
    $diskLetter = $script:Config.VMDiskPath.Substring(0, 1)
    $disk = Get-PSDrive $diskLetter -ErrorAction SilentlyContinue
    if ($disk) {
        $freeGB = [math]::Round($disk.Free / 1GB, 1)
        if ($freeGB -lt 30) {
            Write-Fail "Not enough disk space on ${diskLetter}: drive. Need 30+ GB, have $freeGB GB"
            exit 1
        }
        Write-Success "Disk space OK: $freeGB GB free on ${diskLetter}:"
    }
    
    # Check RAM
    $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    if ($totalRAM -lt ($script:Config.VMRamGB + 4)) {
        Write-Fail "Not enough RAM. Need $($script:Config.VMRamGB + 4)+ GB, have $totalRAM GB"
        exit 1
    }
    Write-Success "RAM OK: $totalRAM GB total"
    
    # Check if VM already exists
    $existingVM = Get-VM -Name $script:Config.VMName -ErrorAction SilentlyContinue
    if ($existingVM -and -not $ForceReinstall) {
        Write-Fail "VM '$($script:Config.VMName)' already exists! Use -ForceReinstall to overwrite."
        exit 1
    }
    if ($existingVM -and $ForceReinstall) {
        Write-Step "Removing existing VM '$($script:Config.VMName)'..."
        Stop-VM -Name $script:Config.VMName -Force -TurnOff -ErrorAction SilentlyContinue
        Remove-VM -Name $script:Config.VMName -Force
        Remove-Item $script:Config.VMDiskPath -Force -ErrorAction SilentlyContinue
        Write-Success "Old VM removed"
    }
    
    Write-Success "All pre-flight checks passed!"
}

# ═══════════════════════════════════════════════════════════
# PHASE 2: HYPER-V SETUP
# ═══════════════════════════════════════════════════════════

function Install-HyperV {
    Write-Banner "Phase 2: Hyper-V Setup"
    
    if ($SkipHyperV) {
        Write-Info "Skipping Hyper-V installation (--SkipHyperV)"
        return
    }
    
    # Check if Hyper-V is installed
    $hyperv = Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue
    if ($hyperv -and $hyperv.Installed) {
        Write-Success "Hyper-V already installed"
    } else {
        Write-Step "Installing Hyper-V..."
        $result = Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart:$false
        if ($result.RestartNeeded -eq 'Yes') {
            Write-Fail "Server needs a REBOOT to complete Hyper-V installation!"
            Write-Info "Please reboot the server and re-run this script with -SkipHyperV"
            exit 2
        }
        Write-Success "Hyper-V installed"
    }
    
    # Check/Create External Switch
    $existingSwitch = Get-VMSwitch -Name $script:Config.VMSwitchName -ErrorAction SilentlyContinue
    if ($existingSwitch) {
        Write-Success "VM Switch '$($script:Config.VMSwitchName)' already exists"
    } else {
        if ([string]::IsNullOrWhiteSpace($script:Config.VMSwitchNIC)) {
            Write-Fail "No NIC specified for VM switch creation!"
            exit 1
        }
        Write-Step "Creating External Switch on '$($script:Config.VMSwitchNIC)'..."
        New-VMSwitch -Name $script:Config.VMSwitchName -NetAdapterName $script:Config.VMSwitchNIC -AllowManagementOS $true
        Write-Success "VM Switch created"
    }
}

# ═══════════════════════════════════════════════════════════
# PHASE 3: VM CREATION FROM TEMPLATE
# ═══════════════════════════════════════════════════════════

function New-SupabaseVM {
    Write-Banner "Phase 3: Creating VM from Template"
    
    if ($SkipVMCreation) {
        Write-Info "Skipping VM creation (--SkipVMCreation)"
        return
    }
    
    # Create VM directory
    $vmDir = Split-Path $script:Config.VMDiskPath
    if (-not (Test-Path $vmDir)) {
        New-Item -Path $vmDir -ItemType Directory -Force | Out-Null
        Write-Success "Created VM directory: $vmDir"
    }
    
    # Copy template VHDX
    Write-Step "Copying template VHDX (~19 GB, this takes a few minutes)..."
    $copyStart = Get-Date
    Copy-Item $script:Config.TemplatePath $script:Config.VMDiskPath -Force
    $copyTime = [math]::Round(((Get-Date) - $copyStart).TotalSeconds, 0)
    Write-Success "Template copied in $copyTime seconds"
    
    # Create VM
    Write-Step "Creating Hyper-V VM: $($script:Config.VMName)..."
    $vm = New-VM -Name $script:Config.VMName `
        -MemoryStartupBytes ($script:Config.VMRamGB * 1GB) `
        -VHDPath $script:Config.VMDiskPath `
        -SwitchName $script:Config.VMSwitchName `
        -Generation 2
    
    # Configure VM
    Set-VM -Name $script:Config.VMName `
        -ProcessorCount $script:Config.VMCpuCount `
        -AutomaticStartAction Start `
        -AutomaticStopAction ShutDown `
        -AutomaticStartDelay 30
    
    # Disable Secure Boot for Linux
    Set-VMFirmware -VMName $script:Config.VMName -EnableSecureBoot Off
    
    # Disable checkpoints to save space
    Set-VM -Name $script:Config.VMName -CheckpointType Disabled
    
    Write-Success "VM created: $($script:Config.VMName)"
    Write-Info "  RAM: $($script:Config.VMRamGB) GB | CPU: $($script:Config.VMCpuCount) cores"
    Write-Info "  Disk: $($script:Config.VMDiskPath)"
    Write-Info "  Auto-start: Enabled"
    
    # Start VM
    Write-Step "Starting VM..."
    Start-VM -Name $script:Config.VMName
    Write-Success "VM started"
}

# ═══════════════════════════════════════════════════════════
# PHASE 4: NETWORK CONFIGURATION
# ═══════════════════════════════════════════════════════════

function Set-VMNetwork {
    Write-Banner "Phase 4: Network Configuration"
    
    # Wait for VM to get a DHCP IP first
    Write-Step "Waiting for VM to boot and get a DHCP IP..."
    $attempts = 0
    $dhcpIP = ""
    while ($attempts -lt 60) {
        $vmNet = Get-VMNetworkAdapter -VMName $script:Config.VMName
        $ips = $vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }
        if ($ips) {
            $dhcpIP = $ips[0]
            Write-Success "VM got DHCP IP: $dhcpIP"
            break
        }
        $attempts++
        Start-Sleep -Seconds 5
    }
    
    if ([string]::IsNullOrWhiteSpace($dhcpIP)) {
        Write-Fail "VM did not get an IP address after 5 minutes!"
        Write-Info "Check the VM console via: vmconnect.exe localhost $($script:Config.VMName)"
        exit 1
    }
    
    # Wait for SSH to be ready
    if (-not (Wait-ForSSH -IP $dhcpIP -TimeoutSeconds 120)) {
        Write-Fail "Cannot connect to VM via SSH!"
        exit 1
    }
    
    # Set up SSH key for passwordless access
    Write-Step "Setting up SSH key authentication..."
    $sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"
    if (-not (Test-Path $sshKeyPath)) {
        $sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
    }
    if (-not (Test-Path $sshKeyPath)) {
        Write-Step "Generating SSH key pair..."
        ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""' -q
        $sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
    }
    
    if (Test-Path $sshKeyPath) {
        $pubKey = Get-Content $sshKeyPath -Raw
        $pubKey = $pubKey.Trim()
        # Use sshpass or expect password 'u' for initial connection
        Write-Info "Copying SSH key to VM (password: u)..."
        echo "u" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "u@$dhcpIP" "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'SSH key added'"
    }
    
    # Configure static IP via SSH
    Write-Step "Configuring static IP: $($script:Config.StaticIP)..."
    
    $netplanConfig = @"
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - $($script:Config.StaticIP)/$($script:Config.SubnetPrefix)
      routes:
        - to: default
          via: $($script:Config.Gateway)
      nameservers:
        addresses:
          - $($script:Config.DNS)
          - 8.8.4.4
"@
    
    # Write netplan config via SSH
    $escapedConfig = $netplanConfig -replace "'", "'\''"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "u@$dhcpIP" "echo 'u' | sudo -S bash -c 'cat > /etc/netplan/00-installer-config.yaml << NETPLANEOF
$netplanConfig
NETPLANEOF
sudo netplan apply'"
    
    Start-Sleep -Seconds 5
    
    # Verify static IP
    if (Wait-ForSSH -IP $script:Config.StaticIP -TimeoutSeconds 60) {
        Write-Success "Static IP configured: $($script:Config.StaticIP)"
    } else {
        Write-Fail "Cannot reach VM at static IP $($script:Config.StaticIP)"
        Write-Info "VM may still be reachable at DHCP IP: $dhcpIP"
        Write-Info "You may need to configure the static IP manually"
        $script:Config.StaticIP = $dhcpIP
    }
    
    # Set hostname
    Write-Step "Setting hostname..."
    $hostname = "supabase-branch$($script:Config.BranchID)"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "u@$($script:Config.StaticIP)" "echo 'u' | sudo -S hostnamectl set-hostname $hostname && echo 'Hostname set to $hostname'"
    Write-Success "Hostname: $hostname"
}

# ═══════════════════════════════════════════════════════════
# PHASE 5: SUPABASE CONFIGURATION
# ═══════════════════════════════════════════════════════════

function Set-SupabaseConfig {
    Write-Banner "Phase 5: Supabase Configuration"
    
    $ip = $script:Config.StaticIP
    $sshTarget = "u@$ip"
    $sshOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL"
    
    # Create .env configuration script
    Write-Step "Configuring Supabase .env..."
    
    $envScript = @"
#!/bin/bash
ENV_FILE="/opt/supabase/supabase/docker/.env"
cp /opt/supabase/supabase/docker/.env.example `$ENV_FILE

# JWT and API keys (same as cloud for sync compatibility)
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$($script:Config.CloudJWTSecret)|" "`$ENV_FILE"
sed -i "s|^ANON_KEY=.*|ANON_KEY=$($script:Config.CloudAnonKey)|" "`$ENV_FILE"
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$($script:Config.CloudServiceKey)|" "`$ENV_FILE"

# Dashboard credentials
sed -i "s|^DASHBOARD_USERNAME=.*|DASHBOARD_USERNAME=supabase|" "`$ENV_FILE"
sed -i "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=$($script:Config.DashboardPassword)|" "`$ENV_FILE"

# Encryption keys
sed -i "s|^VAULT_ENC_KEY=.*|VAULT_ENC_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6|" "`$ENV_FILE"
sed -i "s|^PG_META_CRYPTO_KEY=.*|PG_META_CRYPTO_KEY=x9y8z7w6v5u4t3s2r1q0p9o8n7m6l5k4|" "`$ENV_FILE"
sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=LocalSupabaseSecretKeyBase2025ForAquraReplicaSystem1234567890abcdef|" "`$ENV_FILE"

# URLs
sed -i "s|^SITE_URL=.*|SITE_URL=http://$ip:3000|" "`$ENV_FILE"
sed -i "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=http://$ip:8000|" "`$ENV_FILE"
sed -i "s|^SUPABASE_PUBLIC_URL=.*|SUPABASE_PUBLIC_URL=http://$ip:8000|" "`$ENV_FILE"

# Same postgres password as cloud
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$($script:Config.CloudPostgresPass)|" "`$ENV_FILE"

echo "=== .env configured ==="
"@

    # Write script to temp file and send to VM
    $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
    $envScript | Set-Content -Path $tempScript -Encoding UTF8 -NoNewline
    
    scp $sshOpts.Split(' ') $tempScript "${sshTarget}:/tmp/configure_env.sh" 2>$null
    ssh $sshOpts.Split(' ') $sshTarget "chmod +x /tmp/configure_env.sh && bash /tmp/configure_env.sh"
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    
    Write-Success ".env configured"
    
    # Create docker-compose.override.yml to expose Studio port
    Write-Step "Creating docker-compose.override.yml..."
    ssh $sshOpts.Split(' ') $sshTarget "cat > /opt/supabase/supabase/docker/docker-compose.override.yml << 'EOF'
services:
  studio:
    ports:
      - '3000:3000'
EOF
echo 'Override created'"
    
    Write-Success "Studio port 3000 will be exposed"
    
    # Start Supabase
    Write-Step "Starting Supabase containers (first start takes ~2 minutes)..."
    ssh $sshOpts.Split(' ') $sshTarget "cd /opt/supabase/supabase/docker && docker compose up -d 2>&1 | tail -5"
    
    Write-Step "Waiting for containers to become healthy..."
    Start-Sleep -Seconds 30
    
    # Check containers
    $attempts = 0
    while ($attempts -lt 24) {
        $result = ssh $sshOpts.Split(' ') $sshTarget "docker ps --format '{{.Names}} {{.Status}}' | grep -c healthy"
        if ([int]$result -ge 8) {
            Write-Success "All containers healthy ($result services)"
            break
        }
        Write-Info "  $result/14 containers healthy, waiting..."
        $attempts++
        Start-Sleep -Seconds 10
    }
    
    # Final container status
    Write-Host ""
    ssh $sshOpts.Split(' ') $sshTarget "docker ps --format 'table {{.Names}}\t{{.Status}}'"
}

# ═══════════════════════════════════════════════════════════
# PHASE 6: SCHEMA SYNC FROM CLOUD
# ═══════════════════════════════════════════════════════════

function Sync-SchemaFromCloud {
    Write-Banner "Phase 6: Schema Sync from Cloud"
    
    $ip = $script:Config.StaticIP
    $cloudIP = $script:Config.CloudServerIP
    $sshKey = $script:Config.CloudSSHKey
    $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL")
    
    # Step 1: Export schema from cloud
    Write-Step "Exporting schema from cloud server ($cloudIP)..."
    $exportCmd = "docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only --no-owner --no-acl -N _analytics -N _realtime -N supabase_migrations -N supabase_functions > /tmp/cloud_schema.sql && wc -l /tmp/cloud_schema.sql"
    $result = ssh -i $sshKey "root@$cloudIP" $exportCmd
    Write-Success "Schema exported: $result"
    
    # Step 2: Download to local machine
    Write-Step "Downloading schema from cloud..."
    $tempSchema = "$env:TEMP\cloud_schema.sql"
    scp -i $sshKey "root@${cloudIP}:/tmp/cloud_schema.sql" $tempSchema
    $schemaSize = [math]::Round((Get-Item $tempSchema).Length / 1KB, 1)
    Write-Success "Schema downloaded: $schemaSize KB"
    
    # Step 3: Upload to local VM
    Write-Step "Uploading schema to VM ($ip)..."
    scp $sshOpts "u@${ip}:/tmp/" < $tempSchema 2>$null
    scp $sshOpts $tempSchema "u@${ip}:/tmp/cloud_schema.sql"
    Write-Success "Schema uploaded"
    
    # Step 4: Import schema
    Write-Step "Importing schema into local Supabase (this may take a minute)..."
    ssh $sshOpts "u@$ip" "docker cp /tmp/cloud_schema.sql supabase-db:/tmp/cloud_schema.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/cloud_schema.sql 2>&1 | tail -5"
    Write-Success "Schema imported"
    
    # Step 5: Verify
    Write-Step "Verifying tables..."
    $tableCount = ssh $sshOpts "u@$ip" "docker exec supabase-db psql -U supabase_admin -d postgres -t -c `"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';`""
    Write-Success "Public tables: $($tableCount.Trim())"
    
    $funcCount = ssh $sshOpts "u@$ip" "docker exec supabase-db psql -U supabase_admin -d postgres -t -c `"SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace;`""
    Write-Success "Public functions: $($funcCount.Trim())"
    
    # Cleanup
    Remove-Item $tempSchema -Force -ErrorAction SilentlyContinue
    ssh -i $sshKey "root@$cloudIP" "rm -f /tmp/cloud_schema.sql" 2>$null
    
    Write-Success "Schema sync complete!"
}

# ═══════════════════════════════════════════════════════════
# PHASE 7: DEPLOY IMPORT FUNCTIONS (for data sync)
# ═══════════════════════════════════════════════════════════

function Install-ImportFunctions {
    Write-Banner "Phase 7: Deploy Import Functions"
    
    $ip = $script:Config.StaticIP
    $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL")
    
    Write-Step "Deploying sync import functions to local database..."
    
    $importSQL = @"
-- clear_sync_tables: Bulk delete with FK checks disabled
CREATE OR REPLACE FUNCTION public.clear_sync_tables(p_tables text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS \$\$
DECLARE v_table text;
    v_allowed text[] := ARRAY[
        'ai_chat_guide','approval_permissions','asset_main_categories','asset_sub_categories','assets',
        'bank_reconciliations','biometric_connections','bogo_offer_rules','box_operations',
        'branch_default_delivery_receivers','branch_default_positions','branch_sync_config','branches',
        'break_reasons','break_register','break_security_seed',
        'button_main_sections','button_permissions','button_sub_sections',
        'coupon_campaigns','coupon_claims','coupon_eligible_customers','coupon_products',
        'customer_access_code_history','customer_app_media','customer_product_requests','customer_recovery_requests','customers',
        'day_off','day_off_reasons','day_off_weekday','default_incident_users','deleted_bundle_offers',
        'delivery_fee_tiers','delivery_service_settings',
        'denomination_audit_log','denomination_records','denomination_transactions','denomination_types','denomination_user_preferences',
        'desktop_themes','edge_functions_cache',
        'employee_checklist_assignments','employee_fine_payments','employee_official_holidays',
        'erp_connections','erp_daily_sales','erp_sync_logs','erp_synced_products',
        'expense_parent_categories','expense_requisitions','expense_scheduler','expense_sub_categories',
        'flyer_offer_products','flyer_offers','flyer_templates','frontend_builds',
        'hr_analysed_attendance_data','hr_basic_salary','hr_checklist_operations','hr_checklist_questions','hr_checklists',
        'hr_departments','hr_employee_master','hr_employees','hr_fingerprint_transactions',
        'hr_insurance_companies','hr_levels','hr_position_assignments','hr_position_reporting_template','hr_positions',
        'incident_actions','incident_types','incidents','interface_permissions',
        'lease_rent_lease_parties','lease_rent_payment_entries','lease_rent_payments',
        'lease_rent_properties','lease_rent_property_spaces','lease_rent_rent_parties','lease_rent_special_changes',
        'nationalities','near_expiry_reports','non_approved_payment_scheduler',
        'notification_attachments','notification_read_states','notification_recipients','notifications',
        'offer_bundles','offer_cart_tiers','offer_names','offer_products','offer_usage_logs','offers',
        'official_holidays','order_audit_logs','order_items','orders','overtime_registrations',
        'pos_deduction_transfers','privilege_cards_branch','privilege_cards_master',
        'processed_fingerprint_transactions','product_categories','product_request_bt','product_request_po','product_request_st',
        'product_units','products','purchase_voucher_issue_types','purchase_voucher_items','purchase_vouchers',
        'push_subscriptions',
        'quick_task_assignments','quick_task_comments','quick_task_completions','quick_task_files','quick_task_user_preferences','quick_tasks',
        'receiving_records','receiving_task_templates','receiving_tasks','receiving_user_defaults',
        'recurring_assignment_schedules','recurring_schedule_check_log','regular_shift','requesters',
        'shelf_paper_fonts','shelf_paper_templates','sidebar_buttons','social_links',
        'special_shift_date_wise','special_shift_weekday','system_api_keys',
        'task_assignments','task_completions','task_images','task_reminder_logs','tasks',
        'user_audit_logs','user_device_sessions','user_favorite_buttons','user_password_history',
        'user_sessions','user_theme_assignments','user_voice_preferences','users',
        'variation_audit_log','vendor_payment_schedule','vendors','view_offer',
        'wa_accounts','wa_ai_bot_config','wa_auto_reply_triggers','wa_bot_flows',
        'wa_broadcast_recipients','wa_broadcasts','wa_catalog_orders','wa_catalog_products','wa_catalogs',
        'wa_contact_group_members','wa_contact_groups','wa_conversations','wa_messages','wa_settings','wa_templates',
        'warning_main_category','warning_sub_category','warning_violation','whatsapp_message_log'];
BEGIN
    PERFORM set_config('session_replication_role','replica',true);
    FOREACH v_table IN ARRAY p_tables LOOP
        IF v_table = ANY(v_allowed) THEN EXECUTE format('DELETE FROM %I',v_table); END IF;
    END LOOP;
    PERFORM set_config('session_replication_role','origin',true);
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('session_replication_role','origin',true); RAISE;
END;\$\$;
GRANT EXECUTE ON FUNCTION public.clear_sync_tables(text[]) TO authenticated, anon, service_role;

-- import_sync_batch: Insert data with identity override
CREATE OR REPLACE FUNCTION public.import_sync_batch(p_table_name text, p_data jsonb)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS \$\$
DECLARE v_count integer := 0;
    v_allowed text[] := ARRAY[
        'ai_chat_guide','approval_permissions','asset_main_categories','asset_sub_categories','assets',
        'bank_reconciliations','biometric_connections','bogo_offer_rules','box_operations',
        'branch_default_delivery_receivers','branch_default_positions','branch_sync_config','branches',
        'break_reasons','break_register','break_security_seed',
        'button_main_sections','button_permissions','button_sub_sections',
        'coupon_campaigns','coupon_claims','coupon_eligible_customers','coupon_products',
        'customer_access_code_history','customer_app_media','customer_product_requests','customer_recovery_requests','customers',
        'day_off','day_off_reasons','day_off_weekday','default_incident_users','deleted_bundle_offers',
        'delivery_fee_tiers','delivery_service_settings',
        'denomination_audit_log','denomination_records','denomination_transactions','denomination_types','denomination_user_preferences',
        'desktop_themes','edge_functions_cache',
        'employee_checklist_assignments','employee_fine_payments','employee_official_holidays',
        'erp_connections','erp_daily_sales','erp_sync_logs','erp_synced_products',
        'expense_parent_categories','expense_requisitions','expense_scheduler','expense_sub_categories',
        'flyer_offer_products','flyer_offers','flyer_templates','frontend_builds',
        'hr_analysed_attendance_data','hr_basic_salary','hr_checklist_operations','hr_checklist_questions','hr_checklists',
        'hr_departments','hr_employee_master','hr_employees','hr_fingerprint_transactions',
        'hr_insurance_companies','hr_levels','hr_position_assignments','hr_position_reporting_template','hr_positions',
        'incident_actions','incident_types','incidents','interface_permissions',
        'lease_rent_lease_parties','lease_rent_payment_entries','lease_rent_payments',
        'lease_rent_properties','lease_rent_property_spaces','lease_rent_rent_parties','lease_rent_special_changes',
        'nationalities','near_expiry_reports','non_approved_payment_scheduler',
        'notification_attachments','notification_read_states','notification_recipients','notifications',
        'offer_bundles','offer_cart_tiers','offer_names','offer_products','offer_usage_logs','offers',
        'official_holidays','order_audit_logs','order_items','orders','overtime_registrations',
        'pos_deduction_transfers','privilege_cards_branch','privilege_cards_master',
        'processed_fingerprint_transactions','product_categories','product_request_bt','product_request_po','product_request_st',
        'product_units','products','purchase_voucher_issue_types','purchase_voucher_items','purchase_vouchers',
        'push_subscriptions',
        'quick_task_assignments','quick_task_comments','quick_task_completions','quick_task_files','quick_task_user_preferences','quick_tasks',
        'receiving_records','receiving_task_templates','receiving_tasks','receiving_user_defaults',
        'recurring_assignment_schedules','recurring_schedule_check_log','regular_shift','requesters',
        'shelf_paper_fonts','shelf_paper_templates','sidebar_buttons','social_links',
        'special_shift_date_wise','special_shift_weekday','system_api_keys',
        'task_assignments','task_completions','task_images','task_reminder_logs','tasks',
        'user_audit_logs','user_device_sessions','user_favorite_buttons','user_password_history',
        'user_sessions','user_theme_assignments','user_voice_preferences','users',
        'variation_audit_log','vendor_payment_schedule','vendors','view_offer',
        'wa_accounts','wa_ai_bot_config','wa_auto_reply_triggers','wa_bot_flows',
        'wa_broadcast_recipients','wa_broadcasts','wa_catalog_orders','wa_catalog_products','wa_catalogs',
        'wa_contact_group_members','wa_contact_groups','wa_conversations','wa_messages','wa_settings','wa_templates',
        'warning_main_category','warning_sub_category','warning_violation','whatsapp_message_log'];
BEGIN
    IF NOT (p_table_name = ANY(v_allowed)) THEN RAISE EXCEPTION 'Table % not allowed',p_table_name; END IF;
    IF p_data IS NULL OR jsonb_array_length(p_data) = 0 THEN RETURN 0; END IF;
    PERFORM set_config('session_replication_role','replica',true);
    EXECUTE format('INSERT INTO %I OVERRIDING SYSTEM VALUE SELECT * FROM jsonb_populate_recordset(null::%I,\$1)',p_table_name,p_table_name) USING p_data;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('session_replication_role','origin',true);
    RETURN v_count;
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('session_replication_role','origin',true); RAISE;
END;\$\$;
GRANT EXECUTE ON FUNCTION public.import_sync_batch(text,jsonb) TO authenticated, anon, service_role;

SELECT 'Import functions deployed' as result;
"@

    $tempSQL = "$env:TEMP\import_functions.sql"
    $importSQL | Set-Content -Path $tempSQL -Encoding UTF8
    
    scp $sshOpts $tempSQL "u@${ip}:/tmp/import_functions.sql"
    ssh $sshOpts "u@$ip" "docker cp /tmp/import_functions.sql supabase-db:/tmp/import_functions.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/import_functions.sql 2>&1 | tail -3"
    
    Remove-Item $tempSQL -Force -ErrorAction SilentlyContinue
    Write-Success "Import functions deployed to local database"
}

# ═══════════════════════════════════════════════════════════
# PHASE 8: DEPLOY AQURA FRONTEND
# ═══════════════════════════════════════════════════════════

function Install-AquraFrontend {
    Write-Banner "Phase 8: Deploy Aqura Frontend"
    
    $ip = $script:Config.StaticIP
    $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL")
    
    # Step 1: Upload frontend build
    Write-Step "Uploading frontend build to VM..."
    scp $sshOpts $script:Config.FrontendBuildPath "u@${ip}:/tmp/aqura-frontend-build.zip"
    Write-Success "Frontend build uploaded"
    
    # Step 2: Extract and set up
    Write-Step "Extracting and configuring frontend..."
    ssh $sshOpts "u@$ip" @"
sudo mkdir -p /opt/aqura && sudo chown u:u /opt/aqura
cd /opt/aqura && rm -rf build
unzip -q /tmp/aqura-frontend-build.zip -d build
chmod -R 755 /opt/aqura/build
rm -f /tmp/aqura-frontend-build.zip
echo 'Frontend extracted to /opt/aqura/build'
"@
    Write-Success "Frontend extracted"
    
    # Step 3: Create .env for frontend (all keys needed)
    Write-Step "Creating frontend .env..."
    $envContent = @"
# Supabase Configuration (local VM)
VITE_SUPABASE_URL=http://${ip}:8000
VITE_SUPABASE_ANON_KEY=$($script:Config.CloudAnonKey)
VITE_SUPABASE_SERVICE_KEY=$($script:Config.CloudServiceKey)

# Server Settings
PORT=3001
HOST=0.0.0.0
ORIGIN=http://${ip}:3001

# JWT Secret
JWT_SECRET=$($script:Config.CloudJWTSecret)

# Google API (copy from cloud frontend/.env)
VITE_GOOGLE_API_KEY=YOUR_GOOGLE_API_KEY
VITE_GOOGLE_SEARCH_ENGINE_ID=YOUR_SEARCH_ENGINE_ID
VITE_GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY

# OpenAI API (copy from cloud frontend/.env)
VITE_OPENAI_API_KEY=YOUR_OPENAI_API_KEY
OPENAI_API_KEY=YOUR_OPENAI_API_KEY

# Web Push Notifications (copy from cloud frontend/.env)
VITE_VAPID_PUBLIC_KEY=YOUR_VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY=YOUR_VAPID_PRIVATE_KEY

# Google Text-to-Speech API (copy from cloud frontend/.env)
VITE_GOOGLE_TTS_API_KEY=YOUR_GOOGLE_TTS_KEY

# Google Cloud Vision API (OCR) (copy from cloud frontend/.env)
VITE_GOOGLE_VISION_API_KEY=YOUR_GOOGLE_VISION_KEY

# Remove Background API (copy from cloud frontend/.env)
REMOVE_BG_API_KEY=YOUR_REMOVE_BG_KEY
"@
    $tempEnv = "$env:TEMP\aqura_frontend.env"
    $envContent | Set-Content -Path $tempEnv -Encoding UTF8
    scp $sshOpts $tempEnv "u@${ip}:/opt/aqura/.env"
    Remove-Item $tempEnv -Force -ErrorAction SilentlyContinue
    Write-Success ".env created with local Supabase URL"
    
    # Step 4: Copy package.json and install production dependencies
    Write-Step "Installing Node.js dependencies..."
    ssh $sshOpts "u@$ip" @"
cd /opt/aqura
# Create minimal package.json if not present in build
if [ ! -f package.json ]; then
    echo '{"name":"aqura-local","type":"module","dependencies":{}}' > package.json
fi
# Check if node_modules has dependencies, install if not
npm install --omit=dev --legacy-peer-deps 2>&1 | tail -3
echo 'Dependencies installed'
"@
    Write-Success "Dependencies installed"
    
    # Step 5: Install PM2 and start frontend
    Write-Step "Starting frontend with PM2..."
    ssh $sshOpts "u@$ip" @"
sudo npm install -g pm2 2>/dev/null
cd /opt/aqura
pm2 delete aqura 2>/dev/null
pm2 start build/index.js --name aqura --node-args='--env-file=.env'
pm2 save
echo 'PM2 started'
"@
    Write-Success "Frontend running on port 3001"
    
    # Step 6: Set up PM2 auto-start on boot
    Write-Step "Configuring PM2 auto-start..."
    ssh $sshOpts "u@$ip" @"
PM2_CMD=\$(pm2 startup 2>&1 | grep 'sudo env')
if [ -n "\$PM2_CMD" ]; then
    eval \$PM2_CMD 2>/dev/null
fi
pm2 save
echo 'PM2 auto-start configured'
"@
    Write-Success "PM2 will auto-start on reboot"
    
    # Wait for it to be ready
    Start-Sleep -Seconds 3
    
    # Verify
    Write-Step "Verifying frontend..."
    try {
        $response = Invoke-WebRequest -Uri "http://${ip}:3001" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Success "Aqura frontend is running at http://${ip}:3001"
        } else {
            Write-Fail "Frontend returned HTTP $($response.StatusCode)"
        }
    } catch {
        Write-Fail "Frontend not reachable yet (may need a few more seconds to start)"
        Write-Info "Try: http://${ip}:3001 in a browser"
    }
}

# ═══════════════════════════════════════════════════════════
# PHASE 9: REGISTER BRANCH ON CLOUD
# ═══════════════════════════════════════════════════════════

function Register-BranchOnCloud {
    Write-Banner "Phase 9: Register Branch on Cloud"
    
    $ip = $script:Config.StaticIP
    $branchId = $script:Config.BranchID
    $localUrl = "http://${ip}:8000"
    $serviceKey = $script:Config.CloudServiceKey
    $cloudUrl = $script:Config.CloudSupabaseURL
    
    Write-Step "Registering branch sync config on cloud Supabase..."
    
    # Use cloud Supabase REST API to call the RPC
    $headers = @{
        "apikey" = $serviceKey
        "Authorization" = "Bearer $serviceKey"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        p_branch_id = $branchId
        p_local_supabase_url = $localUrl
        p_local_supabase_key = $serviceKey
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$cloudUrl/rest/v1/rpc/upsert_branch_sync_config" -Method POST -Headers $headers -Body $body -ContentType "application/json"
        Write-Success "Branch registered on cloud (config ID: $response)"
        Write-Info "You can now sync data from Cloud Aqura > Storage Manager > Branch Sync tab"
    } catch {
        Write-Fail "Could not register on cloud: $_"
        Write-Info "You can manually add this branch in Cloud Aqura > Storage Manager > Branch Sync"
        Write-Info "  URL: $localUrl"
        Write-Info "  Branch ID: $branchId"
    }
}

# ═══════════════════════════════════════════════════════════
# PHASE 10: VERIFICATION
# ═══════════════════════════════════════════════════════════

function Test-Installation {
    Write-Banner "Phase 10: Final Verification"
    
    $ip = $script:Config.StaticIP
    $allGood = $true
    
    # Test Studio
    Write-Step "Testing Studio (http://${ip}:3000)..."
    try {
        $response = Invoke-WebRequest -Uri "http://${ip}:3000" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Success "Studio is accessible"
        } else {
            Write-Fail "Studio returned HTTP $($response.StatusCode)"
            $allGood = $false
        }
    } catch {
        Write-Fail "Studio not reachable: $_"
        $allGood = $false
    }
    
    # Test API
    Write-Step "Testing API (http://${ip}:8000)..."
    try {
        $headers = @{ apikey = $script:Config.CloudAnonKey }
        $response = Invoke-WebRequest -Uri "http://${ip}:8000/rest/v1/" -UseBasicParsing -TimeoutSec 10 -Headers $headers
        if ($response.StatusCode -eq 200) {
            Write-Success "API is accessible"
        } else {
            Write-Fail "API returned HTTP $($response.StatusCode)"
            $allGood = $false
        }
    } catch {
        Write-Fail "API not reachable: $_"
        $allGood = $false
    }
    
    # Test DB
    Write-Step "Testing Database..."
    $sshOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL"
    $dbResult = ssh $sshOpts.Split(' ') "u@$ip" "docker exec supabase-db psql -U supabase_admin -d postgres -c 'SELECT version();' 2>/dev/null | head -3"
    if ($dbResult -match "PostgreSQL") {
        Write-Success "Database is running"
    } else {
        Write-Fail "Database check failed"
        $allGood = $false
    }
    
    # Test Frontend (Aqura App)
    Write-Step "Testing Aqura Frontend (http://${ip}:3001)..."
    try {
        $response = Invoke-WebRequest -Uri "http://${ip}:3001" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Success "Aqura frontend is running"
        } else {
            Write-Fail "Frontend returned HTTP $($response.StatusCode)"
            $allGood = $false
        }
    } catch {
        Write-Fail "Frontend not reachable: $_"
        $allGood = $false
    }
    
    return $allGood
}

# ═══════════════════════════════════════════════════════════
# PHASE 11: SAVE BRANCH CONFIG
# ═══════════════════════════════════════════════════════════

function Save-BranchConfig {
    Write-Banner "Phase 11: Saving Branch Configuration"
    
    $configDir = Split-Path $script:Config.VMDiskPath
    $configFile = Join-Path $configDir "branch-config.json"
    
    $branchConfig = @{
        branchName       = $script:Config.BranchName
        branchID         = $script:Config.BranchID
        vmName           = $script:Config.VMName
        vmIP             = $script:Config.StaticIP
        vmUser           = "u"
        vmPassword       = "u"
        aquraURL         = "http://$($script:Config.StaticIP):3001"
        studioURL        = "http://$($script:Config.StaticIP):3000"
        apiURL           = "http://$($script:Config.StaticIP):8000"
        dashboardUser    = "supabase"
        dashboardPass    = $script:Config.DashboardPassword
        installedDate    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        installerVersion = "2.0.0"
    } | ConvertTo-Json -Depth 3
    
    $branchConfig | Set-Content -Path $configFile -Encoding UTF8
    Write-Success "Config saved to: $configFile"
    
    # Also save to the VM
    $sshOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL"
    ssh $sshOpts.Split(' ') "u@$($script:Config.StaticIP)" "cat > /opt/supabase/branch-config.json << 'CFGEOF'
$branchConfig
CFGEOF
echo 'Branch config saved on VM'"
    
    Write-Success "Config also saved on VM"
}

# ═══════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════

Clear-Host
Write-Banner "AQURA BRANCH INSTALLER v2.0" "Green"
Write-Host "  Fully automated installer for Aqura branch locations." -ForegroundColor White
Write-Host "  Sets up VM + Supabase + Schema + Frontend — zero manual work." -ForegroundColor White
Write-Host ""
Write-Host "  Phases:" -ForegroundColor White
Write-Host "     1. Pre-flight checks           6. Schema sync from cloud" -ForegroundColor Gray
Write-Host "     2. Hyper-V setup                7. Import functions deploy" -ForegroundColor Gray
Write-Host "     3. VM creation                  8. Aqura frontend deploy" -ForegroundColor Gray
Write-Host "     4. Network configuration        9. Cloud branch registration" -ForegroundColor Gray
Write-Host "     5. Supabase configuration      10. Final verification" -ForegroundColor Gray
Write-Host "                                    11. Save branch config" -ForegroundColor Gray
Write-Host ""
Write-Host "  Template: Ubuntu 22.04 + Docker 29.2.1 + Supabase images" -ForegroundColor Gray
Write-Host ""

# Run wizard
Show-Wizard

# Execute all phases
Test-Prerequisites       # Phase 1
Install-HyperV           # Phase 2
New-SupabaseVM           # Phase 3
Set-VMNetwork            # Phase 4
Set-SupabaseConfig       # Phase 5
Sync-SchemaFromCloud     # Phase 6
Install-ImportFunctions  # Phase 7
Install-AquraFrontend    # Phase 8
Register-BranchOnCloud   # Phase 9
$success = Test-Installation  # Phase 10
Save-BranchConfig        # Phase 11

# Final summary
Write-Host ""
if ($success) {
    Write-Banner "INSTALLATION COMPLETE!" "Green"
} else {
    Write-Banner "INSTALLATION COMPLETED WITH WARNINGS" "Yellow"
}

Write-Host "  Branch:        $($script:Config.BranchName)" -ForegroundColor White
Write-Host "  VM Name:       $($script:Config.VMName)" -ForegroundColor White
Write-Host "  VM IP:         $($script:Config.StaticIP)" -ForegroundColor White
Write-Host "  SSH:           ssh u@$($script:Config.StaticIP) (password: u)" -ForegroundColor White
Write-Host ""
Write-Host "  ╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║                                                        ║" -ForegroundColor Green
Write-Host "  ║   AQURA LOGIN URL:  http://$($script:Config.StaticIP):3001       ║" -ForegroundColor Green
Write-Host "  ║                                                        ║" -ForegroundColor Green
Write-Host "  ╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Supabase Studio:  http://$($script:Config.StaticIP):3000" -ForegroundColor Cyan
Write-Host "    Login:          supabase / $($script:Config.DashboardPassword)" -ForegroundColor Gray
Write-Host "  Supabase API:     http://$($script:Config.StaticIP):8000" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next step: Sync data from Cloud Aqura > Storage Manager > Branch Sync" -ForegroundColor Yellow
Write-Host "  Config saved to: $(Split-Path $script:Config.VMDiskPath)\branch-config.json" -ForegroundColor Gray
Write-Host ""
