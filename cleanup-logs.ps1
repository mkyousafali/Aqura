# PowerShell script to remove debug console logs while keeping error logs
$files = Get-ChildItem -Path ".\frontend\src" -Recurse -Include "*.svelte", "*.ts", "*.js" | Where-Object { $_.Name -notlike "*.min.*" }

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if ($content) {
        # Remove debug console logs with emoji patterns but keep error logs
        $patterns = @(
            "console\.log\('🔍.*?\);"
            "console\.log\('🔧.*?\);"
            "console\.log\('🖼️.*?\);"
            "console\.log\('📎.*?\);"
            "console\.log\('📭.*?\);"
            "console\.log\('📁.*?\);"
            "console\.log\('✅.*?\);"
            "console\.log\('🔄.*?\);"
            "console\.log\('🔔.*?\);"
            "console\.log\('📱.*?\);"
            "console\.log\('🎯.*?\);"
            "console\.log\('📊.*?\);"
            "console\.log\('📤.*?\);"
            "console\.log\('🧪.*?\);"
            "console\.log\('🔊.*?\);"
            "console\.log\('📈.*?\);"
            "console\.log\('🚀.*?\);"
            "console\.log\('💾.*?\);"
            "console\.log\('📝.*?\);"
        )
        
        $modified = $false
        foreach ($pattern in $patterns) {
            $newContent = $content -replace $pattern, ""
            if ($newContent -ne $content) {
                $content = $newContent
                $modified = $true
            }
        }
        
        if ($modified) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Host "Cleaned: $($file.FullName)"
        }
    }
}