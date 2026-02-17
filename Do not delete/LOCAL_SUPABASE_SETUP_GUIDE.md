# 🏠 Local Supabase Setup Guide — Aqura LAN Replica

## 📋 Overview

**Goal:** Run a complete local copy of Aqura on the office LAN that:
1. Works exactly like the cloud version (same UI, same features)
2. Is accessible from any device on the local network
3. Has a **Sync button** in the main (cloud) Aqura app that pushes all new data to the local copy
4. Runs as a **read-only replica** — users can view data but not modify it locally

**Architecture:**
```
┌─────────────────────┐         ┌──────────────────────────────┐
│   CLOUD SERVER      │  Sync   │   LOCAL SERVER (192.168.0.3) │
│   8.213.42.21       │ ──────► │   Windows Server 2022        │
│   Main Supabase     │  via    │   ┌────────────────────────┐ │
│   Main Aqura App    │ tunnel  │   │ Hyper-V VM (Ubuntu)    │ │
│                     │         │   │ - Docker               │ │
│                     │         │   │ - Supabase (local)     │ │
│                     │         │   │ - Aqura (read-only)    │ │
│                     │         │   └────────────────────────┘ │
└─────────────────────┘         └──────────────────────────────┘
```

---

## 🖥️ Server Infrastructure

### Cloud Server (Main — Already Working)
| Setting | Value |
|---|---|
| IP | `8.213.42.21` |
| OS | Ubuntu 22.04.5 LTS (Alibaba Cloud ECS) |
| Supabase URL | `https://supabase.urbanaqura.com` |
| SSH | `ssh root@8.213.42.21` (passwordless key) |
| SSH Key | `C:\Users\DELL\.ssh\id_ed25519_nopass` |
| Docker path | `/opt/supabase/supabase/docker/` |
| DB container | `supabase-db` |
| DB user | `supabase_admin` |
| DB password | `<set via env var AQURA_POSTGRES_PASSWORD>` |

### Local Server (Office LAN)
| Setting | Value |
|---|---|
| IP | `192.168.0.3` |
| Hostname | `WIN-D1D6EN8240A` |
| OS | Windows Server 2022 Standard (Build 10.0.20348.169) |
| Credentials | `Administrator` / `admin@123` |
| RAM | 64 GB |
| C: Drive | 342 GB total (~280 GB free) |
| D: Drive | 551 GB total (~157 GB free) |
| ERP DB | SQL Server, `sa` / `Polosys*123`, database `URBAN2_2025` |
| Tunnel | `https://erp-branch3.urbanaqura.com` (Cloudflare) |
| NIC 1 | Broadcom NetXtreme Gigabit Ethernet (main network) |
| NIC 2 | Broadcom NetXtreme Gigabit Ethernet #2 (VM switch) |

### Ubuntu VM (Inside Local Server — Hyper-V)
| Setting | Value |
|---|---|
| VM Name | `Ubuntu-Supabase` |
| OS | Ubuntu 22.04.5 LTS Server |
| RAM | 8 GB (fixed) |
| CPU | 4 cores |
| Disk | 100 GB (VHDX on D:\VMs\) |
| Network | ExternalSwitch (NIC 2) |
| IP | `192.168.0.101` (DHCP — may change, consider static later) |
| Hostname | `supabase-local` |
| Username | `u` |
| Password | `u` |
| SSH | OpenSSH server installed |
| SSH Key Auth | `C:\Users\DELL\.ssh\id_ed25519_nopass` (passwordless, configured) |
| SSH Command | `ssh -i C:\Users\DELL\.ssh\id_ed25519_nopass u@192.168.0.101` |
| Auto-start | Enabled (starts with Windows Server) |

---

## 🛠️ Setup Progress & Steps

### ✅ Phase 1: Server Preparation (COMPLETED)
1. ✅ Enabled RDP on local server (port 3389)
2. ✅ Configured PowerShell remoting from dev PC
   - Started WinRM service on dev PC
   - Set TrustedHosts to `192.168.0.3`
   - Command: `$cred = New-Object PSCredential("Administrator", (ConvertTo-SecureString "admin@123" -AsPlainText -Force)); Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { ... }`
3. ✅ Attempted WSL2 installation (FAILED — build 20348.169 too old for WSL2)
4. ✅ Switched to Hyper-V approach

### ✅ Phase 2: Hyper-V Setup (COMPLETED)
1. ✅ Installed Hyper-V feature: `Install-WindowsFeature -Name Hyper-V -IncludeManagementTools`
2. ✅ Rebooted server
3. ✅ Created External Virtual Switch on NIC 2: `New-VMSwitch -Name "ExternalSwitch" -NetAdapterName "Embedded NIC 2" -AllowManagementOS $true`
4. ✅ Downloaded Ubuntu 22.04 Server ISO (~2 GB) to `C:\ubuntu-22.04.iso`

### ✅ Phase 3: Ubuntu VM Installation (COMPLETED)
1. ✅ Created VM: 8GB RAM, 4 CPU, 100GB disk on D:\VMs\
2. ✅ Attached ISO and booted
3. ✅ Installed Ubuntu 22.04 Server with:
   - Hostname: `supabase-local`
   - Username: `u`
   - Password: `u`
   - OpenSSH server: installed
   - Storage: entire 100GB disk with LVM
4. ✅ Removed ISO from DVD drive after install
5. ✅ VM boots into Ubuntu successfully
6. ✅ VM IP: `192.168.0.101`
7. ✅ Passwordless SSH configured (key: `id_ed25519_nopass`)

### ✅ Phase 4: Docker Installation (COMPLETED)
Docker 29.2.1 and Docker Compose v5.0.2 installed successfully.

```bash
# Commands used:
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker u
```

### ✅ Phase 5: Deploy Local Supabase (COMPLETED)
1. ✅ Cloned Supabase repo to `/opt/supabase/supabase/`
2. ✅ Configured `.env` with cloud-compatible JWT credentials
3. ✅ Disabled IPv6 to fix Docker pull issues (`sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1`)
4. ✅ Pulled all Docker images and started containers
5. ✅ Created `docker-compose.override.yml` to expose Studio port 3000
6. ✅ All 14 containers running and healthy
7. ✅ Verified LAN access from dev PC

**Key .env Settings:**
| Setting | Value |
|---|---|
| POSTGRES_PASSWORD | `<set via env var AQURA_POSTGRES_PASSWORD>` (same as cloud) |
| JWT_SECRET | `<set via env var AQURA_JWT_SECRET>` (same as cloud) |
| ANON_KEY | Same as cloud (for sync compatibility) |
| SERVICE_ROLE_KEY | Same as cloud (for sync compatibility) |
| SITE_URL | `http://192.168.0.101:3000` |
| API_EXTERNAL_URL | `http://192.168.0.101:8000` |
| SUPABASE_PUBLIC_URL | `http://192.168.0.101:8000` |
| DASHBOARD_USERNAME | `supabase` |
| DASHBOARD_PASSWORD | `LocalAdmin2025` |

**Override File:** `/opt/supabase/supabase/docker/docker-compose.override.yml`
```yaml
services:
  studio:
    ports:
      - '3000:3000'
```

**Local Supabase is accessible at:**
- Studio: `http://192.168.0.101:3000` (login: `supabase` / `LocalAdmin2025`)
- API: `http://192.168.0.101:8000`
- DB Pooler: `192.168.0.101:5432` / `192.168.0.101:6543`

**14 Running Containers:**
supabase-db, supabase-kong, supabase-auth, supabase-rest, supabase-storage, supabase-studio, supabase-meta, supabase-edge-functions, supabase-analytics, supabase-vector, supabase-imgproxy, supabase-pooler, realtime-dev.supabase-realtime, supabase-vector

### ❌ Phase 6: Sync Cloud Schema to Local (PENDING)
1. Export schema from cloud Supabase (tables, functions, RLS policies)
2. Import into local Supabase
3. Set up read-only RLS policies on local

```bash
# On cloud server — export schema
docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only > /tmp/schema.sql

# Copy to local
scp root@8.213.42.21:/tmp/schema.sql ./schema.sql

# Import to local
docker cp schema.sql supabase-db:/tmp/schema.sql
docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/schema.sql
```

### ✅ Phase 7: Data Sync System (COMPLETED)
Sync system built into **StorageManager.svelte** → Branch Sync tab:

1. ✅ **Branch Sync tab** in StorageManager with full UI (branch cards, sync progress, table-by-table status)
2. ✅ **RPC functions on cloud:** `get_branch_sync_configs`, `upsert_branch_sync_config`, `delete_branch_sync_config`, `update_branch_sync_status`
3. ✅ **Database table:** `branch_sync_config` with `tunnel_url` column for remote sync
4. ✅ **Full table sync:** Exports all rows from cloud → pushes to local via REST API (XHR for LAN, server proxy for tunnel)
5. ✅ **Tunnel fallback:** Tries local URL first (5s timeout), falls back to tunnel URL via `/api/branch-proxy` server endpoint (avoids CORS)
6. ✅ **Server proxy endpoint:** `frontend/src/routes/api/branch-proxy/+server.ts` — proxies requests server-side to avoid browser CORS
7. ✅ **29 tables synced** in FK-safe order with phase 1 (clear) + phase 2 (import)
8. ✅ **Last successful sync:** 160,426 rows across 29 tables

**Architecture:**
```
Cloud Supabase ──► Export all rows (paginated, 5000/batch)
                        │
        ┌───────────────┴───────────────┐
        │ On LAN?                       │ Outside LAN?
        ▼                               ▼
  XHR direct to                   /api/branch-proxy
  http://192.168.0.101:8000       (server-side fetch)
        │                               │
        ▼                               ▼
  Local Supabase ◄──── REST API ────── Tunnel URL
  (clear + upsert)     (POST)     https://supabase-branch3.urbanaqura.com
```

**Config stored in `branch_sync_config` table:**
| Column | Example |
|---|---|
| `branch_id` | 3 |
| `local_supabase_url` | `http://192.168.0.101:8000` |
| `local_supabase_key` | Service role JWT |
| `tunnel_url` | `https://supabase-branch3.urbanaqura.com` |
| `sync_tables` | Array of 29 table names |
| `last_sync_at` | Timestamp of last sync |
| `last_sync_status` | `success` / `failed` / `in_progress` |

### ❌ Phase 8: Read-Only Aqura Frontend (PENDING)
1. Build Aqura frontend with local Supabase URL
2. Deploy as static files served by nginx in Docker
3. Accessible on LAN at `http://<VM-IP>`
4. Read-only mode: disable all create/edit/delete buttons

### ⚠️ Phase 9: Cloudflare Tunnel for Local (PARTIALLY DONE)
1. ✅ `cloudflared` already running on branch server (installed via ERP setup wizard)
2. ✅ Cloudflare tunnel route added: `supabase-branch3.urbanaqura.com` → `http://localhost:8000`
   - Added via Cloudflare Zero Trust dashboard → Networks → Tunnels → erp-branch3 → Published application routes
3. ❌ **502 Bad Gateway** — tunnel route exists but branch Supabase returns 502
   - **Likely cause:** Supabase containers may not be running on the VM, or VM may be powered off
   - **To fix:** RDP into `192.168.0.3`, check VM status, SSH to `192.168.0.101`, run `docker compose ps` in `/opt/supabase/supabase/docker/`
   - If containers are down: `cd /opt/supabase/supabase/docker && docker compose up -d`
4. ❌ Need to verify tunnel works end-to-end once branch Supabase is confirmed running

---

## 🔑 Key Commands Reference

### PowerShell Remoting to Local Server
```powershell
$cred = New-Object PSCredential("Administrator", (ConvertTo-SecureString "admin@123" -AsPlainText -Force))
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { ... }
```

### Hyper-V VM Management
```powershell
# From dev PC (remote)
$cred = New-Object PSCredential("Administrator", (ConvertTo-SecureString "admin@123" -AsPlainText -Force))

# Start VM
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Start-VM "Ubuntu-Supabase" }

# Stop VM
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Stop-VM "Ubuntu-Supabase" }

# Check VM status
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Get-VM "Ubuntu-Supabase" | Select Name, State, CPUUsage, MemoryAssigned }

# Get VM IP
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Get-VMNetworkAdapter -VMName "Ubuntu-Supabase" | Select IPAddresses }

# Open VM console (from server desktop)
vmconnect.exe localhost Ubuntu-Supabase
```

### SSH to Ubuntu VM
```bash
# Passwordless SSH (preferred)
ssh -i C:\Users\DELL\.ssh\id_ed25519_nopass u@192.168.0.101

# Or with password
ssh u@192.168.0.101
# Password: u
```

### Docker Commands (inside Ubuntu VM)
```bash
# Check Supabase containers
cd /opt/supabase/supabase/docker
docker-compose ps

# Restart Supabase
docker-compose restart

# View logs
docker-compose logs -f --tail 50

# Access PostgreSQL
docker exec -it supabase-db psql -U supabase_admin -d postgres
```

---

## 📁 File Locations

### On Dev PC (D:\Aqura)
| File | Purpose |
|---|---|
| `frontend/` | Main Aqura SvelteKit app |
| `frontend/src/lib/components/desktop-interface/settings/StorageManager.svelte` | Storage manager with sync button (future) |

### On Local Server (192.168.0.3)
| File | Purpose |
|---|---|
| `C:\ubuntu-22.04.iso` | Ubuntu installer ISO (~2 GB) |
| `C:\ubuntu_x64\install.tar.gz` | Ubuntu rootfs (from WSL attempt) |
| `D:\VMs\Ubuntu-Supabase.vhdx` | VM disk image |

### On Ubuntu VM
| Path | Purpose |
|---|---|
| `/opt/supabase/` | Supabase installation (future) |
| `/opt/supabase/supabase/docker/` | Docker compose files |
| `/opt/supabase/supabase/docker/.env` | Supabase configuration |

### On Cloud Server (8.213.42.21)
| Path | Purpose |
|---|---|
| `/opt/supabase/supabase/docker/` | Main Supabase installation |
| `/opt/supabase/supabase-restart-watcher.sh` | Server restart watcher script |

---

## 🔄 How Sync Will Work (Final Design)

```
┌──────────────────────────────────────────────────────────────┐
│                    MAIN AQURA APP (Cloud)                     │
│                                                              │
│  ┌─────────────┐    ┌─────────────────────────────────┐     │
│  │ Sync Button │───►│ 1. Query changed rows since     │     │
│  │ in sidebar  │    │    last_sync_timestamp           │     │
│  └─────────────┘    │ 2. Package as JSON               │     │
│                     │ 3. Send via tunnel to local API   │     │
│                     │ 4. Local upserts all data         │     │
│                     │ 5. Update last_sync_timestamp     │     │
│                     │ 6. Show success/failure           │     │
│                     └─────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼ HTTPS via Cloudflare Tunnel
┌──────────────────────────────────────────────────────────────┐
│                LOCAL SUPABASE (Ubuntu VM)                     │
│                                                              │
│  ┌─────────────┐    ┌─────────────────────────────────┐     │
│  │ Receive API │───►│ 1. Validate service_role key    │     │
│  │ call        │    │ 2. Upsert data into tables       │     │
│  └─────────────┘    │ 3. Return success/error count    │     │
│                     └─────────────────────────────────────┘  │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ LOCAL AQURA FRONTEND (read-only)                     │    │
│  │ Accessible at http://<VM-IP>                         │    │
│  │ Same UI, but all write operations disabled           │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Tables to Sync
All main application tables including:
- `employee_master` — Employee records
- `branches` — Branch information
- `departments` — Departments
- `designations` — Job designations
- `attendance_*` — Attendance data
- `payroll_*` — Payroll data
- `inventory_*` — Inventory data
- `sales_*` — Sales data
- `hr_*` — HR records
- `auth.users` — User accounts (for login)
- All other application tables

### What Gets Synced
- **Full sync (first time):** All data from all tables
- **Incremental sync (subsequent):** Only rows where `updated_at > last_sync_timestamp`
- **Direction:** Cloud → Local only (one-way)
- **Frequency:** Manual (user clicks Sync button)

---

## ⚠️ Important Notes

1. **WSL2 does NOT work** on this Windows Server build (10.0.20348.169) — that's why we use Hyper-V
2. The VM gets its IP via DHCP — it may change after reboot. Consider setting a static IP later
3. The VM is set to **auto-start** with the Windows Server
4. The local Supabase is a **separate instance** — not a PostgreSQL replica
5. Sync is **one-way** (cloud → local) to keep it simple and safe
6. The local Aqura frontend will be **read-only** — no data modification allowed
7. The External Virtual Switch uses NIC 2 — NIC 1 remains for the main server network

---

## 🚨 Troubleshooting

### Can't connect to VM
```powershell
# Check VM is running
$cred = New-Object PSCredential("Administrator", (ConvertTo-SecureString "admin@123" -AsPlainText -Force))
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Get-VM "Ubuntu-Supabase" }

# Start VM if stopped
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Start-VM "Ubuntu-Supabase" }

# Get VM IP
Invoke-Command -ComputerName 192.168.0.3 -Credential $cred -ScriptBlock { Get-VMNetworkAdapter -VMName "Ubuntu-Supabase" | Select IPAddresses }
```

### VM has no network
- Check the ExternalSwitch is connected to NIC 2
- Verify NIC 2 has a cable connected
- Inside VM: `sudo dhclient eth0`

### Can't SSH to VM
- Verify SSH is running: `sudo systemctl status ssh`
- Check firewall: `sudo ufw status` (should be inactive or allow port 22)
- Try from the Hyper-V host: `ssh ubuntu@<VM-IP>`

### Docker containers not starting
```bash
cd /opt/supabase/supabase/docker
docker-compose logs --tail 50
docker-compose down
docker-compose up -d
```

### PowerShell remoting fails
```powershell
# On dev PC
Start-Service WinRM
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.0.3" -Force
```
