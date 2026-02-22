<#
.SYNOPSIS
    Update Aqura — Push changes to cloud and/or branch VMs.
    
.DESCRIPTION
    Cloud is the single source of truth (king).
    
    Architecture:
      - Schema changes   → ONLY on cloud, then synced DOWN to branches
      - Data (inserts etc) → ONLY on cloud, branches get overwritten on sync
      - Frontend updates  → Built locally, pushed to branches
    
    Workflow:
      1. Run SQL on cloud:     .\Update-AquraBranch.ps1 -Cloud -SQLFile changes.sql
      2. Build frontend:       .\Build-Frontend.ps1
      3. Push to branches:     .\Update-AquraBranch.ps1 -All -SyncSchema
    
.EXAMPLE
    # Run SQL on cloud server (new tables, functions, etc.)
    .\Update-AquraBranch.ps1 -Cloud -SQLFile "D:\Aqura\my_changes.sql"
    
    # Run SQL on cloud + immediately sync schema to a branch
    .\Update-AquraBranch.ps1 -Cloud -SQLFile "changes.sql" -BranchIP 192.168.0.101 -SyncSchema
    
    # Update frontend only on one branch
    .\Update-AquraBranch.ps1 -BranchIP 192.168.0.101
    
    # Update frontend + sync schema from cloud to branch
    .\Update-AquraBranch.ps1 -BranchIP 192.168.0.101 -SyncSchema
    
    # Update ALL branches (frontend + schema + functions)
    .\Update-AquraBranch.ps1 -All -SyncSchema -UpdateFunctions
    
    # Cloud SQL only (no branch update)
    .\Update-AquraBranch.ps1 -Cloud -SQLFile "migration.sql"
    
.NOTES
    Author: Aqura DevOps
    Version: 2.1.0
    Date: 2026-02-16
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BranchIP,
    
    [string]$BuildZip = "",
    [string]$SQLFile = "",
    
    [switch]$Cloud,
    [switch]$SyncSchema,
    [switch]$UpdateFunctions,
    [switch]$All,
    [switch]$SkipBackup
)

$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════

$CloudServerIP    = "8.213.42.21"
$CloudSSHKey      = "$env:USERPROFILE\.ssh\id_ed25519_nopass"
$CloudAnonKey     = $env:SUPABASE_ANON_KEY  # Set via environment variable
$CloudServiceKey  = $env:SUPABASE_SERVICE_KEY  # Set via environment variable
$DefaultBuildZip  = Join-Path $PSScriptRoot "template\aqura-frontend-build.zip"
$SSHOpts          = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL")

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

function Write-Step ($msg) { Write-Host "  ► $msg" -ForegroundColor Yellow }
function Write-Success ($msg) { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail ($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info ($msg) { Write-Host "  ℹ $msg" -ForegroundColor Gray }

# ═══════════════════════════════════════════════════════════
# RUN SQL ON CLOUD (cloud is king)
# ═══════════════════════════════════════════════════════════

function Run-CloudSQL {
    param([string]$SqlPath)
    
    Write-Banner "Running SQL on Cloud Server ($CloudServerIP)" "Magenta"
    
    $fileName = Split-Path $SqlPath -Leaf
    $lineCount = (Get-Content $SqlPath).Count
    Write-Info "File: $fileName ($lineCount lines)"
    
    # Step 1: Upload SQL to cloud server
    Write-Step "Uploading SQL to cloud server..."
    scp -i $CloudSSHKey $SqlPath "root@${CloudServerIP}:/tmp/cloud_update.sql"
    Write-Success "Uploaded"
    
    # Step 2: Copy into container and execute
    Write-Step "Executing on cloud database..."
    $output = ssh -i $CloudSSHKey "root@$CloudServerIP" "docker cp /tmp/cloud_update.sql supabase-db:/tmp/cloud_update.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/cloud_update.sql 2>&1"
    
    # Show output (last 15 lines)
    Write-Host ""
    $outputLines = $output -split "`n"
    $showLines = if ($outputLines.Count -le 15) { $outputLines } else { $outputLines | Select-Object -Last 15 }
    foreach ($line in $showLines) {
        $color = if ($line -match 'ERROR') { 'Red' } elseif ($line -match 'CREATE|ALTER|INSERT|UPDATE|DELETE|GRANT|DROP') { 'Green' } else { 'Gray' }
        Write-Host "    $line" -ForegroundColor $color
    }
    Write-Host ""
    
    if ($output -match 'ERROR') {
        Write-Fail "SQL had errors — check output above"
    } else {
        Write-Success "SQL executed successfully on cloud"
    }
    
    # Cleanup
    ssh -i $CloudSSHKey "root@$CloudServerIP" "rm -f /tmp/cloud_update.sql" 2>$null
    
    Write-Info "Cloud DB is updated. Sync schema to branches with: -SyncSchema"
}

# ═══════════════════════════════════════════════════════════
# UPDATE FRONTEND
# ═══════════════════════════════════════════════════════════

function Update-Frontend {
    param([string]$IP, [string]$ZipPath)
    
    Write-Banner "Updating Frontend on $IP"
    
    # Step 1: Get current version
    Write-Step "Checking current version..."
    $currentVersion = ssh $SSHOpts "u@$IP" "cat /opt/aqura/build/version.txt 2>/dev/null || echo 'unknown'"
    Write-Info "Current version: $($currentVersion.Trim())"
    
    # Step 2: Backup current build (unless skipped)
    if (-not $SkipBackup) {
        Write-Step "Backing up current frontend..."
        $backupName = "build_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        ssh $SSHOpts "u@$IP" "cd /opt/aqura && cp -r build $backupName 2>/dev/null && echo 'Backup: /opt/aqura/$backupName' || echo 'No existing build to backup'"
    }
    
    # Step 3: Stop PM2
    Write-Step "Stopping Aqura process..."
    ssh $SSHOpts "u@$IP" "pm2 stop aqura 2>/dev/null; echo 'Stopped'"
    
    # Step 4: Upload new build
    Write-Step "Uploading new build ($([math]::Round((Get-Item $ZipPath).Length / 1MB, 1)) MB)..."
    scp $SSHOpts $ZipPath "u@${IP}:/tmp/aqura-frontend-build.zip"
    Write-Success "Upload complete"
    
    # Step 5: Extract and replace
    Write-Step "Extracting new build..."
    ssh $SSHOpts "u@$IP" @"
cd /opt/aqura
rm -rf build
unzip -q /tmp/aqura-frontend-build.zip -d build
chmod -R 755 build
rm -f /tmp/aqura-frontend-build.zip
echo 'Extracted to /opt/aqura/build'
"@
    Write-Success "Build extracted"
    
    # Step 6: Restart PM2
    Write-Step "Starting Aqura..."
    ssh $SSHOpts "u@$IP" @"
cd /opt/aqura
pm2 start build/index.js --name aqura --node-args='--env-file=.env' 2>/dev/null || pm2 restart aqura
pm2 save
echo 'Started'
"@
    
    # Step 7: Wait and verify
    Start-Sleep -Seconds 3
    Write-Step "Verifying..."
    try {
        $response = Invoke-WebRequest -Uri "http://${IP}:3001" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Success "Frontend is running at http://${IP}:3001"
        } else {
            Write-Fail "Frontend returned HTTP $($response.StatusCode)"
        }
    } catch {
        Write-Fail "Frontend not reachable yet — may need a few more seconds"
        Write-Info "Try: http://${IP}:3001"
    }
    
    # Step 8: Show new version
    $newVersion = ssh $SSHOpts "u@$IP" "cat /opt/aqura/build/version.txt 2>/dev/null || echo 'unknown'"
    Write-Success "Updated: $($currentVersion.Trim()) → $($newVersion.Trim())"
}

# ═══════════════════════════════════════════════════════════
# SYNC SCHEMA FROM CLOUD
# ═══════════════════════════════════════════════════════════

function Update-Schema {
    param([string]$IP)
    
    Write-Banner "Syncing Schema to $IP"
    
    Write-Step "Exporting schema from cloud..."
    $exportCmd = "docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only --no-owner --no-acl -N _analytics -N _realtime -N supabase_migrations -N supabase_functions > /tmp/cloud_schema.sql && wc -l /tmp/cloud_schema.sql"
    $result = ssh -i $CloudSSHKey "root@$CloudServerIP" $exportCmd
    Write-Success "Schema exported: $result"
    
    Write-Step "Downloading schema..."
    $tempSchema = "$env:TEMP\cloud_schema_update.sql"
    scp -i $CloudSSHKey "root@${CloudServerIP}:/tmp/cloud_schema.sql" $tempSchema
    Write-Success "Downloaded: $([math]::Round((Get-Item $tempSchema).Length / 1KB, 1)) KB"
    
    Write-Step "Uploading to VM ($IP)..."
    scp $SSHOpts $tempSchema "u@${IP}:/tmp/cloud_schema.sql"
    
    Write-Step "Importing schema (this may take a minute)..."
    ssh $SSHOpts "u@$IP" "docker cp /tmp/cloud_schema.sql supabase-db:/tmp/cloud_schema.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/cloud_schema.sql 2>&1 | tail -5"
    
    # Verify
    $tableCount = ssh $SSHOpts "u@$IP" "docker exec supabase-db psql -U supabase_admin -d postgres -t -c `"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';`""
    $funcCount = ssh $SSHOpts "u@$IP" "docker exec supabase-db psql -U supabase_admin -d postgres -t -c `"SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace;`""
    Write-Success "Schema synced — Tables: $($tableCount.Trim()), Functions: $($funcCount.Trim())"
    
    # Cleanup
    Remove-Item $tempSchema -Force -ErrorAction SilentlyContinue
    ssh -i $CloudSSHKey "root@$CloudServerIP" "rm -f /tmp/cloud_schema.sql" 2>$null
}

# ═══════════════════════════════════════════════════════════
# UPDATE IMPORT FUNCTIONS
# ═══════════════════════════════════════════════════════════

function Update-ImportFunctions {
    param([string]$IP)
    
    Write-Banner "Updating Import Functions on $IP"
    
    Write-Step "Deploying sync functions..."
    
    $importSQL = @"
-- clear_sync_tables: Bulk delete with FK checks disabled
CREATE OR REPLACE FUNCTION public.clear_sync_tables(p_tables text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS \$\$
DECLARE v_table text;
    v_allowed text[] := ARRAY[
        'desktop_themes','settings','ai_chat_guide','social_links',
        'branches','users','user_sessions','user_device_sessions',
        'user_favorite_buttons','user_theme_assignments','user_voice_preferences',
        'button_main_sections','button_sub_sections','sidebar_buttons',
        'button_permissions','interface_permissions','approval_permissions',
        'nationalities','hr_departments','hr_levels','hr_positions',
        'hr_employee_master','hr_employees','hr_position_assignments',
        'hr_position_reporting_template','hr_employee_contacts','hr_employee_documents',
        'hr_basic_salary','hr_insurance_companies',
        'branch_default_positions','receiving_user_defaults',
        'regular_shift','special_shift_weekday','special_shift_date_wise',
        'day_off','day_off_weekday','day_off_reasons',
        'official_holidays','employee_official_holidays','overtime_registrations',
        'hr_checklists','hr_checklist_questions','hr_checklist_operations',
        'employee_checklist_assignments',
        'incident_types','default_incident_users',
        'warning_main_category','warning_sub_category','warning_violation',
        'product_categories','product_units','products','product_details',
        'erp_connections','erp_synced_products','erp_sync_logs',
        'offers','offer_products','offer_names','offer_bundles','offer_cart_tiers',
        'bogo_offer_rules','flyer_offers','flyer_offer_products',
        'flyer_templates','shelf_paper_templates','shelf_paper_fonts',
        'customers','privilege_cards_master','privilege_cards_branch',
        'coupon_campaigns','coupon_products','coupon_eligible_customers',
        'delivery_service_settings','delivery_fee_tiers','branch_default_delivery_receivers',
        'vendors','requesters','denomination_types','tax_categories',
        'expense_sub_categories','pos_deduction_transfers',
        'asset_main_categories','asset_sub_categories',
        'system_api_keys'];
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
        'desktop_themes','settings','ai_chat_guide','social_links',
        'branches','users','user_sessions','user_device_sessions',
        'user_favorite_buttons','user_theme_assignments','user_voice_preferences',
        'button_main_sections','button_sub_sections','sidebar_buttons',
        'button_permissions','interface_permissions','approval_permissions',
        'nationalities','hr_departments','hr_levels','hr_positions',
        'hr_employee_master','hr_employees','hr_position_assignments',
        'hr_position_reporting_template','hr_employee_contacts','hr_employee_documents',
        'hr_basic_salary','hr_insurance_companies',
        'branch_default_positions','receiving_user_defaults',
        'regular_shift','special_shift_weekday','special_shift_date_wise',
        'day_off','day_off_weekday','day_off_reasons',
        'official_holidays','employee_official_holidays','overtime_registrations',
        'hr_checklists','hr_checklist_questions','hr_checklist_operations',
        'employee_checklist_assignments',
        'incident_types','default_incident_users',
        'warning_main_category','warning_sub_category','warning_violation',
        'product_categories','product_units','products','product_details',
        'erp_connections','erp_synced_products','erp_sync_logs',
        'offers','offer_products','offer_names','offer_bundles','offer_cart_tiers',
        'bogo_offer_rules','flyer_offers','flyer_offer_products',
        'flyer_templates','shelf_paper_templates','shelf_paper_fonts',
        'customers','privilege_cards_master','privilege_cards_branch',
        'coupon_campaigns','coupon_products','coupon_eligible_customers',
        'delivery_service_settings','delivery_fee_tiers','branch_default_delivery_receivers',
        'vendors','requesters','denomination_types','tax_categories',
        'expense_sub_categories','pos_deduction_transfers',
        'asset_main_categories','asset_sub_categories',
        'system_api_keys'];
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

SELECT 'Import functions updated' as result;
"@

    $tempSQL = "$env:TEMP\update_import_functions.sql"
    $importSQL | Set-Content -Path $tempSQL -Encoding UTF8
    
    scp $SSHOpts $tempSQL "u@${IP}:/tmp/import_functions.sql"
    ssh $SSHOpts "u@$IP" "docker cp /tmp/import_functions.sql supabase-db:/tmp/import_functions.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/import_functions.sql 2>&1 | tail -3"
    
    Remove-Item $tempSQL -Force -ErrorAction SilentlyContinue
    Write-Success "Import functions updated"
}

# ═══════════════════════════════════════════════════════════
# FIND ALL BRANCHES
# ═══════════════════════════════════════════════════════════

function Get-BranchConfigs {
    $configs = @()
    
    # Look for branch-config.json files in standard locations
    $searchPaths = @(
        "D:\Hyper-V\VMs",
        "D:\VMs",
        "C:\Hyper-V\VMs",
        "D:\Aqura-Branch-Installer"
    )
    
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $configFiles = Get-ChildItem -Path $searchPath -Filter "branch-config.json" -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $configFiles) {
                try {
                    $config = Get-Content $file.FullName -Raw | ConvertFrom-Json
                    $configs += @{
                        Name = $config.branchName
                        IP   = $config.vmIP
                        File = $file.FullName
                    }
                } catch {
                    Write-Info "Skipping invalid config: $($file.FullName)"
                }
            }
        }
    }
    
    return $configs
}

# ═══════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════

Clear-Host
Write-Banner "AQURA UPDATER v2.1 — Cloud is King" "Green"
Write-Info "Schema & data: Cloud → Branches (one-way)"
Write-Info "Frontend: Build locally → Push to branches"
Write-Host ""

# ── CLOUD SQL (run first if specified) ──
if ($Cloud) {
    if (-not (Test-Path $CloudSSHKey)) {
        Write-Fail "Cloud SSH key not found: $CloudSSHKey"
        exit 1
    }
    
    if ($SQLFile -ne "") {
        if (-not (Test-Path $SQLFile)) {
            Write-Fail "SQL file not found: $SQLFile"
            exit 1
        }
        Run-CloudSQL -SqlPath $SQLFile
    } else {
        Write-Fail "Use -SQLFile with -Cloud to specify the SQL file to run"
        Write-Host ""
        Write-Host "  Example:" -ForegroundColor White
        Write-Host "    .\Update-AquraBranch.ps1 -Cloud -SQLFile 'changes.sql'" -ForegroundColor Gray
        exit 1
    }
    
    # If no branch targets specified, we're done (cloud-only update)
    if (-not $BranchIP -and -not $All) {
        Write-Host ""
        Write-Banner "CLOUD UPDATE COMPLETE" "Green"
        Write-Host "  SQL applied to cloud DB successfully." -ForegroundColor White
        Write-Host "  To sync schema to branches:" -ForegroundColor Yellow
        Write-Host "    .\Update-AquraBranch.ps1 -All -SyncSchema" -ForegroundColor Gray
        Write-Host "    .\Update-AquraBranch.ps1 -BranchIP <IP> -SyncSchema" -ForegroundColor Gray
        Write-Host ""
        exit 0
    }
}

# ── Resolve build ZIP (needed for branch updates) ──
$needsFrontend = (-not $Cloud) -or ($BranchIP -ne "" -or $All)
if ($needsFrontend) {
    if ($BuildZip -eq "") {
        $BuildZip = $DefaultBuildZip
    }
    
    if (-not (Test-Path $BuildZip)) {
        # If only doing schema sync, frontend ZIP is optional
        if ($SyncSchema -and -not $All) {
            Write-Info "No frontend build found — will only sync schema"
            $skipFrontendUpdate = $true
        } else {
            Write-Fail "Frontend build not found: $BuildZip"
            Write-Info "Run Build-Frontend.ps1 first, or specify -BuildZip path"
            exit 1
        }
    } else {
        $zipSize = [math]::Round((Get-Item $BuildZip).Length / 1MB, 1)
        Write-Info "Frontend build: $BuildZip ($zipSize MB)"
        $skipFrontendUpdate = $false
    }
}

# Handle -All flag: update every branch
if ($All) {
    Write-Step "Discovering branch installations..."
    $branches = Get-BranchConfigs
    
    if ($branches.Count -eq 0) {
        Write-Fail "No branch-config.json files found"
        Write-Info "Use -BranchIP to specify a branch manually"
        exit 1
    }
    
    Write-Host ""
    Write-Host "  Found $($branches.Count) branch(es):" -ForegroundColor White
    foreach ($b in $branches) {
        Write-Host "    • $($b.Name) — $($b.IP)" -ForegroundColor Gray
    }
    Write-Host ""
    
    $confirm = Read-Host "  Update all branches? (y/n)"
    if ($confirm -ne 'y') {
        Write-Info "Cancelled"
        exit 0
    }
    
    $results = @()
    foreach ($branch in $branches) {
        Write-Host ""
        Write-Host "  ━━━ $($branch.Name) ($($branch.IP)) ━━━" -ForegroundColor Magenta
        try {
            if (-not $skipFrontendUpdate) {
                Update-Frontend -IP $branch.IP -ZipPath $BuildZip
            }
            if ($SyncSchema) { Update-Schema -IP $branch.IP }
            if ($UpdateFunctions) { Update-ImportFunctions -IP $branch.IP }
            $results += @{ Name = $branch.Name; IP = $branch.IP; Status = "✓ Updated" }
        } catch {
            Write-Fail "Failed to update $($branch.Name): $_"
            $results += @{ Name = $branch.Name; IP = $branch.IP; Status = "✗ Failed" }
        }
    }
    
    # Summary
    Write-Host ""
    Write-Banner "UPDATE SUMMARY" "Green"
    foreach ($r in $results) {
        $color = if ($r.Status -match "✓") { "Green" } else { "Red" }
        Write-Host "  $($r.Status)  $($r.Name) ($($r.IP))" -ForegroundColor $color
    }
    Write-Host ""
    exit 0
}

# Single branch update
if (-not $BranchIP) {
    Write-Fail "Please specify -BranchIP, -All, or -Cloud"
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host "    .\Update-AquraBranch.ps1 -Cloud -SQLFile changes.sql             ← run SQL on cloud" -ForegroundColor Gray
    Write-Host "    .\Update-AquraBranch.ps1 -BranchIP 192.168.0.101                 ← update frontend" -ForegroundColor Gray
    Write-Host "    .\Update-AquraBranch.ps1 -BranchIP 192.168.0.101 -SyncSchema     ← + sync schema" -ForegroundColor Gray
    Write-Host "    .\Update-AquraBranch.ps1 -All -SyncSchema                        ← all branches" -ForegroundColor Gray
    Write-Host "    .\Update-AquraBranch.ps1 -Cloud -SQLFile x.sql -All -SyncSchema  ← cloud + branches" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Verify branch is reachable
Write-Step "Checking branch VM ($BranchIP)..."
try {
    $pingResult = Test-Connection -ComputerName $BranchIP -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $pingResult) {
        Write-Fail "Cannot reach $BranchIP — is the VM running?"
        exit 1
    }
    Write-Success "Branch VM is reachable"
} catch {
    Write-Fail "Cannot reach $BranchIP"
    exit 1
}

# Run updates
if (-not $skipFrontendUpdate) {
    Update-Frontend -IP $BranchIP -ZipPath $BuildZip
}

if ($SyncSchema) {
    if (-not (Test-Path $CloudSSHKey)) {
        Write-Fail "Cloud SSH key not found: $CloudSSHKey"
        Write-Info "Schema sync requires SSH access to cloud server"
    } else {
        Update-Schema -IP $BranchIP
    }
}

if ($UpdateFunctions) {
    Update-ImportFunctions -IP $BranchIP
}

# Final
Write-Host ""
Write-Banner "UPDATE COMPLETE!" "Green"
Write-Host "  Branch:     $BranchIP" -ForegroundColor White
Write-Host "  Aqura URL:  http://${BranchIP}:3001" -ForegroundColor Green
if ($SyncSchema) {
    Write-Host "  Schema:     Synced from cloud" -ForegroundColor Cyan
}
if ($UpdateFunctions) {
    Write-Host "  Functions:  Updated" -ForegroundColor Cyan
}
Write-Host ""
