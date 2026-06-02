import re

file_path = r"D:\Aqura\frontend\src\lib\components\desktop-interface\settings\HelperApps.svelte"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# These are the mojibake sequences (latin1 misread of utf-8 bytes) -> correct unicode
replacements = [
    ('\u00f0\u009f\u00a7\u00a9', '\U0001f9e9'),  # ðŸ§© -> 🧩
    ('\u00e2\u0086\u00bb', '\u21bb'),              # â†» -> ↻
    ('\u00e2\u009c\u0095', '\u2715'),              # âœ• -> ✕
    ('\u00e2\u009c\u0085', '\u2705'),              # âœ… -> ✅
    ('\u00e2\u009a\u00a0\u00ef\u00b8\u008f', '\u26a0\ufe0f'),  # âš ï¸ -> ⚠️
    ('\u00e2\u0080\u0094', '\u2014'),              # â€" -> —
    ('\u00e2\u0080\u00a6', '\u2026'),              # â€¦ -> …
    ('\u00e2\u00ac\u0086', '\u2b06'),              # â¬† -> ⬆
    ('\u00e2\u00ac\u0087', '\u2b07'),              # â¬‡ -> ⬇
    ('\u00e2\u009c\u0093', '\u2713'),              # âœ" -> ✓
    ('\u00f0\u009f\u009b\u0082\u00ef\u00b8\u008f', '\U0001f5c2\ufe0f'),  # ðŸ—‚ï¸ -> 🗂️
    ('\u00f0\u009f\u0094\u0084', '\U0001f504'),   # ðŸ"„ (🔄 Update)
]

original = content

# Fix all mojibake
for bad, good in replacements:
    content = content.replace(bad, good)

# The 📄 (document) icon for file preview should stay as 📄, not 🔄
# After fixing, 🔄 replaced all ðŸ"„. 
# We need to keep 🔄 for Update button and change file preview back to 📄
# Let's check: file preview line has "📄 <strong>" and Update button has "🔄 Update"  
# But since both ðŸ"„ became 🔄 after replace, fix the file preview one back
content = content.replace('\U0001f504 <strong>', '\U0001f4c4 <strong>')

if content != original:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed! Encoding corrected in HelperApps.svelte")
else:
    print("No changes made (characters may already be correct)")
