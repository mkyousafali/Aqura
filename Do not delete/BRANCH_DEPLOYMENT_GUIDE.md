# 🚀 Aqura Branch Deployment Guide (Fully Automated)

> **This guide replaces both the old Manual Sync Guide and the Version Push & Deploy Guide.**
> A single PowerShell script handles everything end-to-end with zero manual steps.

---

## ⚡ Quick Start (One Command)

```powershell
# From project root (D:\Aqura):
.\scripts\deploy-to-branch.ps1 -Interface desktop -Message "feat(hr): add analysis tool"
```

That's it. The script does **everything** automatically:
1. Bumps version numbers + updates all UI displays + creates git commit
2. Builds the frontend and uploads to cloud storage (for other branches)
3. Creates database dump on cloud → downloads → uploads to branch → restores
4. Resets database sequences
5. Builds frontend with `adapter-node` (8GB heap)
6. Compresses build output (`tar.gz`)
7. Uploads compressed build to branch server
8. Stops old frontend process on branch
9. Extracts new build + installs dependencies
10. Starts frontend on port 3001
11. Verifies HTTP 200 response
12. Pushes to git
13. Cleans up all temp files

---

## 📋 Prerequisites (One-Time Setup)

### SSH Key Setup
The script uses passwordless SSH. Ensure you have:
- `~/.ssh/id_ed25519_nopass` — SSH key without passphrase
- Cloud server `root@8.213.42.21` accepts this key
- Branch server `u@192.168.0.101` accepts this key

**Set up branch passwordless auth (one time):**
```powershell
$PublicKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519_nopass.pub"
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" u@192.168.0.101 `
  "mkdir -p ~/.ssh && echo '$PublicKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Verify — should NOT ask for password:
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_nopass" u@192.168.0.101 "echo 'SUCCESS'"
```

### Server Details
| Role | IP | User | Purpose |
|------|----|----|---------|
| **Cloud** | `8.213.42.21` | `root` | Supabase backend, database source |
| **Branch** | `192.168.0.101` | `u` | Local server, frontend on port 3001 |
| **Your PC** | `192.168.0.163` | (local) | Runs the deployment script |

### Software Required on PC
- **Node.js** (v20+) + **npm**
- **Git**
- **SSH** (built into Windows)
- **tar** (built into Windows 10+)

---

## 🔧 Command Reference

### Basic Usage
```powershell
.\scripts\deploy-to-branch.ps1 -Interface <type> -Message "<description>"
```

### Interface Types
| Type | What it bumps | Example |
|------|--------------|---------|
| `desktop` | Desktop version (1st number) | `AQ2.1.1.1` |
| `mobile` | Mobile version (2nd number) | `AQ1.2.1.1` |
| `cashier` | Cashier version (3rd number) | `AQ1.1.2.1` |
| `customer` | Customer version (4th number) | `AQ1.1.1.2` |
| `all` | All four versions | `AQ2.2.2.2` |

### Examples
```powershell
# Full deployment (most common)
.\scripts\deploy-to-branch.ps1 -Interface desktop -Message "feat(hr): add analysis tool"

# Update all interfaces
.\scripts\deploy-to-branch.ps1 -Interface all -Message "fix: multiple bug fixes across all UIs"

# Skip database sync (code-only changes)
.\scripts\deploy-to-branch.ps1 -Interface mobile -Message "style: update mobile theme" -SkipDbSync

# Re-deploy same version (e.g., after fixing a build issue)
.\scripts\deploy-to-branch.ps1 -Interface desktop -Message "fix: hotfix" -SkipVersionBump

# Deploy but don't push to git yet (want to review first)
.\scripts\deploy-to-branch.ps1 -Interface cashier -Message "feat: new cashier feature" -SkipGitPush
```

### Flags
| Flag | Effect |
|------|--------|
| `-SkipDbSync` | Skip database dump/restore (faster, code-only deploy) |
| `-SkipVersionBump` | Don't bump version, don't run simple-push.js |
| `-SkipGitPush` | Don't `git push` at end (deploy only) |

---

## 📂 What Gets Git-Ignored

All temporary/generated files are automatically ignored (already in `.gitignore`):

| File/Pattern | Purpose | Location |
|-------------|---------|----------|
| `aqura_dump.sql.gz` | Database dump | `$env:TEMP` (PC) + `/tmp/` (servers) |
| `aqura_build.tar.gz` | Compressed build | `$env:TEMP` (PC) + `/tmp/` (branch) |
| `reset_sequences.sql` | Sequence reset SQL | `$env:TEMP` (PC) + `/tmp/` (branch) |
| `aqura-frontend-build.zip` | Cloud storage upload | Project root (cleaned by simple-push.js) |
| `frontend/build/` | Compiled frontend | Local build dir |
| `*.zip`, `*.tar.gz` | All archives | Everywhere |
| `temp_*` | Temp SQL files | Project root |

**Only source code + config changes go into git** — no build artifacts, dumps, or temp files.

---

## 🔢 Version Numbering

**Format: `AQ[Desktop].[Mobile].[Cashier].[Customer]`**

- **Desktop** (1st): Business management & admin tools
- **Mobile** (2nd): Employee app & HR tools
- **Cashier** (3rd): POS & store operations
- **Customer** (4th): Consumer shopping app

Example: `AQ34.13.8.8` = Desktop v34, Mobile v13, Cashier v8, Customer v8

The script automatically updates version displays in:
- `package.json` (both root and frontend)
- `Sidebar.svelte` (desktop)
- `+page.svelte` (desktop login)
- `+layout.svelte` (mobile)
- `TopBar.svelte` (customer)
- `CashierInterface.svelte` (cashier)
- `VersionChangelog.svelte` (changelog popup)

---

## 🏗️ What the Script Does (Step by Step)

### Step 1: Version Bump + Cloud Deploy
Runs `simple-push.js --deploy` which:
- Increments version in `package.json`
- Updates all UI version displays
- Creates git commit
- Builds with `adapter-node`
- Uploads ZIP to Supabase Storage (`frontend-builds` bucket)
- Registers build in `frontend_builds` table

### Step 2: Database Dump (Cloud → PC → Branch)
- Creates `pg_dump` on cloud server (compressed ~60-80 MB)
- Downloads to PC via SCP
- Uploads from PC to branch server via SCP

### Step 3: Database Restore + Sequence Reset
- Restores the dump into branch PostgreSQL (via Docker)
- Resets all sequences to match max IDs
- Runs `NOTIFY pgrst, 'reload schema'` to refresh PostgREST cache

### Step 4: Build Frontend
- Sets `BUILD_ADAPTER=node` for SvelteKit adapter-node
- Sets `NODE_OPTIONS=--max-old-space-size=8192` (8GB heap)
- Runs `npm run build` in frontend directory

### Step 5: Compress + Upload
- Creates `tar.gz` of `build/`, `package.json`, `pnpm-lock.yaml`
- Uploads to branch at `/tmp/aqura_build.tar.gz`

### Step 6: Deploy on Branch
- Kills old `node build/index.js` process
- Removes old build files from `/tmp/build/`
- Extracts new build
- Installs production dependencies with `npm install --omit=dev --legacy-peer-deps`

### Step 7: Start + Verify
- Starts `node build/index.js` with:
  - `PORT=3001`
  - `NODE_OPTIONS=--max-old-space-size=4096`
  - `NODE_ENV=production`
- Waits 5 seconds, then checks HTTP 200 from `http://localhost:3001`
- Shows deployed version from `package.json`

### Step 8: Git Push + Cleanup
- Pushes commit to remote repository
- Deletes all temp files on PC, cloud, and branch

---

## ❌ Troubleshooting

### "Cannot reach cloud server"
- Check internet connection
- Verify SSH key: `ssh -i ~/.ssh/id_ed25519_nopass root@8.213.42.21 "echo ok"`

### "Cannot reach branch server"
- Check if VM is running (Hyper-V Manager)
- Ping: `ping 192.168.0.101`
- Restart VM if needed

### "Frontend build failed"
- Check Node.js memory: increase `--max-old-space-size` if needed
- Try rebuilding manually: `cd frontend; $env:BUILD_ADAPTER='node'; npm run build`

### "Frontend returned HTTP 000"
- App crashed on startup — check logs: `ssh u@192.168.0.101 "tail -50 /tmp/app.log"`
- Port conflict: `ssh u@192.168.0.101 "lsof -i :3001"`
- Common fix: another process on port 3001 → `ssh u@192.168.0.101 "pkill -f 'node.*build/index.js'"`

### "Git push failed"
- Check branch: `git status`
- Pull first: `git pull --rebase`
- Then re-run with `-SkipVersionBump -SkipDbSync` to retry deploy + push

### "Database restore errors"
- These are usually harmless (duplicate constraint warnings)
- Verify: `ssh u@192.168.0.101 "docker exec supabase-db psql -U supabase_admin postgres -c 'SELECT count(*) FROM information_schema.tables WHERE table_schema = '\''public'\'';'"`

---

## 🗄️ Server Details Reference

### Database Credentials (Branch)
| Setting | Value |
|---------|-------|
| Container | `supabase-db` |
| User | `supabase_admin` |
| Password | `your-super-secret-and-long-postgres-password` |
| Database | `postgres` |
| Port | `5432` (internal Docker) |

### SSH Keys
| Key | Passphrase | Usage |
|-----|-----------|-------|
| `~/.ssh/id_ed25519_nopass` | None | Script automation (preferred) |
| `~/.ssh/id_ed25519` | `@#Imanihayath120` | Manual backup |

### Key Ports on Branch (192.168.0.101)
| Port | Service |
|------|---------|
| 3001 | Frontend app (SvelteKit) |
| 3000 | Supabase Studio |
| 8000 | Supabase REST API |
| 5432 | PostgreSQL (Docker internal) |

---

## 📝 After Deployment Checklist

The script handles everything, but you may want to manually:

- [ ] Test login at `http://192.168.0.101:3001`
- [ ] Verify data appears correctly (users, products, etc.)
- [ ] Update `VersionChangelog.svelte` with detailed change descriptions (the script adds a basic entry — expand it with dated sub-headers and categorized items)

---

Generated: March 5, 2026
Version: 1.0 — Replaces MANUAL_SYNC_GUIDE.md + AI_VERSION_PUSH_AND_DEPLOY_GUIDE.md
