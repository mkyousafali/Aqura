$filePath = 'D:\Aqura\frontend\src\routes\mobile-interface\support\+page.svelte'
$content = Get-Content $filePath -Encoding UTF8

# Replace lines 995-998 (0-indexed 994-997)
$content[994] = "										<!-- Badge 4: SOS mode -->"
$content[995] = "										<span role=" + '"button"' + " tabindex=" + '"0"' + " class=" + '"wa-mbadge {conv.is_sos ? ' + "'wa-mbadge-sos-active'" + " : " + "'wa-mbadge-sos'" + "}" + '"' + " on:click|stopPropagation={() => toggleSOS(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleSOS(conv)} title={`$locale === 'ar' ? (conv.is_sos ? 'اضغط لإلغاء وضع SOS' : 'اضغط لتفعيل وضع SOS') : (conv.is_sos ? 'Click to remove SOS mode' : 'Click to enable SOS')}>🛑</span>"

# Remove old lines 996-998
$newContent = $content[0..995] + $content[999..($content.Count-1)]

Set-Content -Path $filePath -Value $newContent -Encoding UTF8
Write-Host "Mobile  SOS badge updated successfully"
