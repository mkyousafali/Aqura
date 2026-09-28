[CmdletBinding()]
param(
    [string]$Remote = "origin",
    [string]$Branch = "master",
    [string]$DeployHost = "8.213.42.21",
    [string]$DeployUser = "root",
    [string]$IdentityFile = "$HOME/.ssh/id_ed25519_nopass",
    [switch]$SkipPush,
    [switch]$SkipDeploy,
    [switch]$AllowDirty,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

function Invoke-Checked {
    param([Parameter(Mandatory)] [string]$FilePath, [Parameter(Mandatory)] [string[]]$Arguments)
    Write-Host "> $FilePath $($Arguments -join ' ')" -ForegroundColor Cyan
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code ${LASTEXITCODE}: $FilePath" }
}

$currentBranch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $Branch) {
    throw "Deployment requires branch '$Branch'; current branch is '$currentBranch'."
}
$workingTree = & git status --porcelain
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect the Git working tree." }
if ($workingTree -and -not $AllowDirty) { throw "Working tree is not clean. Commit or stash changes before deployment." }

if (-not $DryRun) {
    Invoke-Checked "node" @((Join-Path $PSScriptRoot "bump-version.mjs"))
    $deployVersion = (Get-Content -LiteralPath (Join-Path $repoRoot "frontend/package.json") -Raw | ConvertFrom-Json).version
    Invoke-Checked "git" @("add", "--", "frontend/package.json", "frontend/src/lib/appVersion.ts")
    Invoke-Checked "git" @("commit", "-m", "chore: bump deployment version to $deployVersion")
    Write-Host "Prepared deployment version $deployVersion." -ForegroundColor Green
}
else {
    Invoke-Checked "node" @((Join-Path $PSScriptRoot "bump-version.mjs"), "--check")
    Write-Host "Dry run does not change or commit the application version." -ForegroundColor DarkGray
}

$commit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw "Unable to resolve the deployment Git commit." }

$pnpm = if (Get-Command pnpm.cmd -ErrorAction SilentlyContinue) { "pnpm.cmd" } else { "pnpm" }
$oldAdapter = $env:BUILD_ADAPTER
try {
    $env:BUILD_ADAPTER = "node"
    Invoke-Checked $pnpm @("--filter", "aqura-frontend", "build")
}
finally { $env:BUILD_ADAPTER = $oldAdapter }

$timestamp = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
$releaseId = "$($commit.Substring(0, 12))-$timestamp"
$tempRoot = Join-Path $repoRoot ".deployment-temp"
$stageDir = Join-Path $tempRoot $releaseId
$archive = Join-Path $tempRoot "$releaseId.tar.gz"
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

try {
    Copy-Item -LiteralPath (Join-Path $repoRoot "frontend/build") -Destination (Join-Path $stageDir "build") -Recurse
    Copy-Item -LiteralPath (Join-Path $repoRoot "frontend/package.json") -Destination (Join-Path $stageDir "package.json")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "websocket-polyfill.mjs") -Destination $stageDir
    [IO.File]::WriteAllText((Join-Path $stageDir "REVISION"), "$commit`n", (New-Object Text.UTF8Encoding($false)))

    $packagePath = Join-Path $stageDir "package.json"
    $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    $package.PSObject.Properties.Remove("devDependencies")
    if ($package.dependencies) {
        $package.dependencies.PSObject.Properties.Remove("aqura")
        $package.dependencies | Add-Member -NotePropertyName "ws" -NotePropertyValue "^8.18.3" -Force
    }
    [IO.File]::WriteAllText($packagePath, (($package | ConvertTo-Json -Depth 20) + "`n"), (New-Object Text.UTF8Encoding($false)))

    Invoke-Checked "tar" @("-czf", $archive, "-C", $stageDir, ".")
    Write-Host "> tar -tzf $archive (output suppressed)" -ForegroundColor DarkGray
    & tar -tzf $archive | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Archive validation failed with exit code $LASTEXITCODE."
    }
    Write-Host "Validated release archive: $archive" -ForegroundColor Green

    if ($DryRun) {
        Write-Host "Dry run complete. Git push and server deployment were skipped." -ForegroundColor Green
        return
    }
    if (-not $SkipPush) { Invoke-Checked "git" @("push", $Remote, $Branch) }

    if (-not $SkipDeploy) {
        $sshArgs = @("-o", "BatchMode=yes", "-o", "ConnectTimeout=15")
        if ($IdentityFile) { $sshArgs += @("-i", (Resolve-Path $IdentityFile).Path) }
        $target = "$DeployUser@$DeployHost"
        $remoteArchive = "/opt/aqura-web/incoming/$releaseId.tar.gz"
        $remoteScript = "/opt/aqura-web/incoming/activate-$releaseId.sh"
        Invoke-Checked "ssh" ($sshArgs + @($target, "mkdir -p /opt/aqura-web/incoming"))
        Invoke-Checked "scp" ($sshArgs + @($archive, "${target}:$remoteArchive"))
        Invoke-Checked "scp" ($sshArgs + @((Join-Path $PSScriptRoot "activate-release.sh"), "${target}:$remoteScript"))
        Invoke-Checked "ssh" ($sshArgs + @($target, "bash '$remoteScript' '$remoteArchive' '$releaseId' '$commit'; status=`$?; rm -f '$remoteScript'; exit `$status"))
    }
    Write-Host "Push and deployment completed for $releaseId." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force }
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    if ((Test-Path -LiteralPath $tempRoot) -and -not (Get-ChildItem -LiteralPath $tempRoot -Force)) { Remove-Item -LiteralPath $tempRoot -Force }
}
