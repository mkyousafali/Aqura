$file = "D:\Aqura\frontend\src\lib\components\desktop-interface\settings\HelperApps.svelte"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)

$replacements = @{
    'ðŸ§©'   = '🧩'
    'â†»'    = '↻'
    'âœ•'    = '✕'
    'âœ…'    = '✅'
    'âš ï¸'  = '⚠️'
    'ðŸ"„'   = '📄'
    'â€"'    = '—'
    'â€¦'    = '…'
    'â¬†'    = '⬆'
    'ðŸ—‚ï¸' = '🗂️'
    'âœ"'    = '✓'
    'â¬‡'    = '⬇'
}

foreach ($key in $replacements.Keys) {
    $content = $content.Replace($key, $replacements[$key])
}

# Fix Update button specifically (📄 Update -> 🔄 Update)
$content = $content.Replace('📄 Update', '🔄 Update')

[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
Write-Host "Done! Fixed encoding in HelperApps.svelte"
