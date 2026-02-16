<#
.SYNOPSIS
    Sync database schema from cloud Supabase to local branch instance.
    
.DESCRIPTION
    Exports the full schema (tables, functions, RLS policies, triggers)
    from the cloud Supabase and imports it into the local branch instance.
    Run this after Install-AquraBranch.ps1 to set up the database schema.
    
.EXAMPLE
    .\Sync-Schema.ps1 -LocalIP 192.168.0.101
    
.NOTES
    Requires SSH key access to cloud server (8.213.42.21)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$LocalIP,
    
    [string]$CloudServer = "8.213.42.21",
    [string]$CloudSSHKey = "$env:USERPROFILE\.ssh\id_ed25519_nopass",
    [string]$LocalUser = "u"
)

function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $border = "=" * ($Text.Length + 4)
    Write-Host "`n  $border" -ForegroundColor $Color
    Write-Host "  | $Text |" -ForegroundColor $Color
    Write-Host "  $border`n" -ForegroundColor $Color
}

function Write-Step { param([string]$T) Write-Host "  > $T" -ForegroundColor Yellow }
function Write-Ok   { param([string]$T) Write-Host "  + $T" -ForegroundColor Green }
function Write-Err  { param([string]$T) Write-Host "  ! $T" -ForegroundColor Red }

$sshCloud = "ssh -i $CloudSSHKey root@$CloudServer"
$sshLocal = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL $LocalUser@$LocalIP"

Write-Banner "Schema Sync: Cloud -> Branch ($LocalIP)"

# Step 1: Export schema from cloud
Write-Step "Exporting schema from cloud server ($CloudServer)..."
$exportCmd = "docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only --no-owner --no-acl -N _analytics -N _realtime -N supabase_migrations -N supabase_functions > /tmp/cloud_schema.sql && wc -l /tmp/cloud_schema.sql"
$result = ssh -i $CloudSSHKey root@$CloudServer $exportCmd
Write-Ok "Schema exported: $result"

# Step 2: Copy to local machine
Write-Step "Downloading schema from cloud..."
$tempSchema = "$env:TEMP\cloud_schema.sql"
scp -i $CloudSSHKey "root@${CloudServer}:/tmp/cloud_schema.sql" $tempSchema
$schemaSize = [math]::Round((Get-Item $tempSchema).Length / 1KB, 1)
Write-Ok "Schema downloaded: $schemaSize KB"

# Step 3: Upload to local VM
Write-Step "Uploading schema to local VM ($LocalIP)..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL $tempSchema "${LocalUser}@${LocalIP}:/tmp/cloud_schema.sql"
Write-Ok "Schema uploaded to VM"

# Step 4: Import schema
Write-Step "Importing schema into local Supabase..."
$importResult = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$LocalUser@$LocalIP" "docker cp /tmp/cloud_schema.sql supabase-db:/tmp/cloud_schema.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/cloud_schema.sql 2>&1 | tail -20"
Write-Host $importResult
Write-Ok "Schema imported"

# Step 5: Verify
Write-Step "Verifying tables..."
$tableCount = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$LocalUser@$LocalIP" "docker exec supabase-db psql -U supabase_admin -d postgres -c `"SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';`" -t"
Write-Ok "Public tables: $($tableCount.Trim())"

$funcCount = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$LocalUser@$LocalIP" "docker exec supabase-db psql -U supabase_admin -d postgres -c `"SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace;`" -t"
Write-Ok "Public functions: $($funcCount.Trim())"

# Cleanup
Remove-Item $tempSchema -Force -ErrorAction SilentlyContinue
ssh -i $CloudSSHKey root@$CloudServer "rm -f /tmp/cloud_schema.sql" 2>$null

Write-Banner "Schema Sync Complete!" "Green"
Write-Host "  Local Supabase at http://${LocalIP}:8000 now has the cloud schema." -ForegroundColor White
Write-Host "  Next: Sync data using the Sync button in the Aqura app.`n" -ForegroundColor Gray
