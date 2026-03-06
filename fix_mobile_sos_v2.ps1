$file = 'D:\Aqura\frontend\src\routes\mobile-interface\support\+page.svelte'
$content = Get-Content $file -Raw -Encoding UTF8

# Simple string replacement - find the old pattern and replace with new
$oldPattern = @"
										<!-- Badge 4: SOS mode -->
										{#if conv.is_sos}
											<span role="button" tabindex="0" class="wa-mbadge wa-mbadge-sos" on:click|stopPropagation={() => toggleSOS(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleSOS(conv)}>
"@

# Create the replacement with proper formatting  
$newPattern = @"
										<!-- Badge 4: SOS mode -->
										<span role="button" tabindex="0" class="wa-mbadge {conv.is_sos ? 'wa-mbadge-sos-active' : 'wa-mbadge-sos'}" on:click|stopPropagation={() => toggleSOS(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleSOS(conv)} title={`$locale === 'ar' ? (conv.is_sos ? 'اضغط لإلغاء وضع SOS' : 'اضغط لتفعيل وضع SOS') : (conv.is_sos ? 'Click to remove SOS mode' : 'Click to enable SOS')}>🛑</span>
"@

# Also need to remove the closing {/if}
# Find and replace: the entire if block with just the span
$content = $content -replace [regex]::Escape($oldPattern), $newPattern
# Now remove the closing {/if} that's no longer needed - look for it after the emoji
$content = $content -replace '(🛑</span>\s*)\{/if\}', '$1'

Set-Content $file -Value $content -Encoding UTF8
Write-Host "Mobile SOS badge fixed"
