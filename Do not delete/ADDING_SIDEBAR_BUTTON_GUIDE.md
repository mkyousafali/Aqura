# Complete Guide: Adding a New Button to the Sidebar

Follow every step in order. Skipping any step causes bugs (wrong counts in Button Generator, missing permissions, broken button).

---

## Overview of What Gets Updated

| # | What | Where |
|---|------|--------|
| 1 | Database — register button | `sidebar_buttons` table (via SSH SQL) |
| 2 | Sidebar — import component | `Sidebar.svelte` imports |
| 3 | Sidebar — open function | `Sidebar.svelte` script section |
| 4 | Sidebar — buttonActions map | `Sidebar.svelte` (~line 2060) |
| 5 | Sidebar — buttonCodeToI18nKey map | `Sidebar.svelte` (~line 285) |
| 6 | Sidebar — button UI | `Sidebar.svelte` template section |
| 7 | Button Generator structure | `parse-sidebar-code/+server.ts` |
| 8 | i18n English | `frontend/src/lib/i18n/locales/en.ts` |
| 9 | i18n Arabic | `frontend/src/lib/i18n/locales/ar.ts` |
| 10 | Push to git | Terminal |

---

## Step 1 — Register the Button in the Database

You must insert the button into `sidebar_buttons` so it can be permission-controlled.

### 1a — Find the correct `main_section_id` and `subsection_id`

```powershell
ssh -i "C:\Users\ME\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -c 'SELECT id, section_name_en, section_code FROM button_main_sections ORDER BY id;'"
```

Main sections and their IDs:
| ID | Section |
|----|---------|
| 11 | Delivery |
| 12 | Vendor |
| 13 | Media |
| 14 | Promo |
| 15 | Finance |
| 16 | HR |
| 17 | Tasks |
| 18 | Outreach (Notifications) |
| 19 | User |
| 20 | Controls |
| 21 | Stock |
| 22 | WhatsApp |
| 23 | Loyalty |

```powershell
ssh -i "C:\Users\ME\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -c 'SELECT id, subsection_name_en, subsection_code FROM button_sub_sections WHERE main_section_id = 16 ORDER BY id;'"
```
Replace `16` with your section's ID. Subsection names are usually: `Dashboard`, `Manage`, `Operations`, `Reports`.

### 1b — Insert the button

Use the file approach for safe SQL execution from Windows PowerShell:

```powershell
@"
INSERT INTO sidebar_buttons (main_section_id, subsection_id, button_name_en, button_name_ar, button_code, icon, display_order, is_active)
VALUES (16, 75, 'My Button Name', 'اسم الزر', 'MY_BUTTON_CODE', '🔧', 10, true)
ON CONFLICT (main_section_id, subsection_id, button_code) DO NOTHING;
"@ | Set-Content -Path "D:\Aqura\temp_btn.sql" -Encoding UTF8

scp -i "C:\Users\ME\.ssh\id_ed25519_nopass" D:\Aqura\temp_btn.sql root@8.213.42.21:/tmp/temp_btn.sql
ssh -i "C:\Users\ME\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker cp /tmp/temp_btn.sql supabase-db:/tmp/temp_btn.sql && docker exec supabase-db psql -U supabase_admin -d postgres -f /tmp/temp_btn.sql"
Remove-Item D:\Aqura\temp_btn.sql
```

**Rules:**
- `button_code` must be `UPPER_SNAKE_CASE`
- `ON CONFLICT ... DO NOTHING` prevents duplicate errors if run twice
- `display_order` controls sort order within the subsection; check existing buttons first:
  ```powershell
  ssh -i "C:\Users\ME\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -c 'SELECT id, button_code, display_order FROM sidebar_buttons WHERE subsection_id = 75 ORDER BY display_order;'"
  ```

---

## Step 2 — Import the Component in Sidebar.svelte

File: `frontend/src/lib/components/desktop-interface/common/Sidebar.svelte`

Find the import block near the top (around line 100–200) with other imports from the same section. Add your component import next to related imports.

```typescript
import MyNewWindow from '$lib/components/desktop-interface/master/hr/MyNewWindow.svelte';
```

---

## Step 3 — Add the Open Function in Sidebar.svelte

Find the function for a nearby button in the same subsection and add yours after it.

```typescript
function openMyNewWindow() {
    collapseAllMenus();
    const windowId = generateWindowId('my-new-window');
    const instanceNumber = Math.floor(Math.random() * 1000) + 1;

    openWindow({
        id: windowId,
        title: `${t('nav.myNewWindow')} #${instanceNumber}`,
        component: MyNewWindow,
        componentName: "MyNewWindow",
        icon: '🔧',
        size: { width: 1200, height: 700 },
        position: {
            x: 50 + (Math.random() * 100),
            y: 50 + (Math.random() * 100)
        },
        resizable: true,
        minimizable: true,
        maximizable: true,
        closable: true
    });
    showHRSubmenu = false; // set to whichever section submenu variable applies
}
```

**Common `show*Submenu` variable names:**
- `showHRSubmenu` — HR section
- `showControlsSubmenu` — Controls section
- `showFinanceSubmenu` — Finance section
- `showStockSubmenu` — Stock section
- (find others with: `let show` search in Sidebar.svelte)

---

## Step 4 — Add to the `buttonActions` Map in Sidebar.svelte

Search for `const buttonActions` or `'SECURITY_CODE': openSecurityCodeWindow` (around line 2060). Add your entry nearby:

```typescript
'MY_BUTTON_CODE': openMyNewWindow,
```

This map is used by `isButtonAllowed` and keyboard shortcuts. **Every button must be here.**

---

## Step 5 — Add to the `buttonCodeToI18nKey` Map in Sidebar.svelte

Search for `buttonCodeToI18nKey` (around line 285). Add your button code:

```typescript
'MY_BUTTON_CODE': 'nav.myNewWindow',
```

This map is used by the Button Access Control window to display human-readable button names. **If missing, the button appears as its raw code in the permissions UI.**

---

## Step 6 — Add the Button UI in the Sidebar Template

Find the correct subsection in the template (search for the subsection header, e.g., `<!-- Dashboard Subsection Items -->`). Add inside the `{#if showHR*Submenu}` block:

```svelte
{#if isButtonAllowed('MY_BUTTON_CODE')}
    <div class="submenu-item-container">
        <button class="submenu-item" on:click={openMyNewWindow}>
            <span class="menu-icon">🔧</span>
            <span class="menu-text">{t('nav.myNewWindow')}</span>
        </button>
    </div>
{/if}
```

**Rules:**
- Always wrap in `{#if isButtonAllowed('MY_BUTTON_CODE')}` — master admins see all buttons automatically
- Use `on:click` (Svelte 4 syntax — NOT `onclick`)
- Put it in the right subsection (Dashboard / Manage / Operations / Reports)

---

## Step 7 — Update the Button Generator Structure

File: `frontend/src/routes/api/parse-sidebar-code/+server.ts`

This file has a **hardcoded structure** that the Button Generator uses to count and list buttons in the "Code Base" section. If you skip this, the count will be wrong (e.g., shows `[1]` instead of `[2]`).

Find your section in the `structure` object and add your button code to the correct subsection array:

```typescript
HR: {
    DASHBOARD: ['SECURITY_CODE', 'FINGERPRINT_DASHBOARD', 'MY_BUTTON_CODE'],  // ← add here
    MANAGE: ['EMPLOYEE_MASTER', 'LINK_ID', 'HR_SERVICES'],
    OPERATIONS: [...],
    REPORTS: [...]
},
```

**Match the subsection exactly** to where you placed the button in Sidebar.svelte.

---

## Step 8 — Add English i18n Key

File: `frontend/src/lib/i18n/locales/en.ts`

Find the `nav:` section and add your key near related entries:

```typescript
myNewWindow: "My New Window",
```

---

## Step 9 — Add Arabic i18n Key

File: `frontend/src/lib/i18n/locales/ar.ts`

Add the Arabic translation in the same position:

```typescript
myNewWindow: "نافذتي الجديدة",
```

---

## Step 10 — Commit and Push

```powershell
git add -A ; git commit -m "Section: add My New Window button to Sidebar" ; git push origin master
```

---

## Quick Reference Checklist

```
[ ] 1. DB: INSERT into sidebar_buttons (main_section_id, subsection_id, button_code, ...)
[ ] 2. Sidebar.svelte: import MyComponent from '...'
[ ] 3. Sidebar.svelte: function openMyComponent() { openWindow({...}) }
[ ] 4. Sidebar.svelte: 'MY_CODE': openMyComponent  in buttonActions map
[ ] 5. Sidebar.svelte: 'MY_CODE': 'nav.myKey'  in buttonCodeToI18nKey map
[ ] 6. Sidebar.svelte: {#if isButtonAllowed('MY_CODE')} button UI {/if}
[ ] 7. parse-sidebar-code/+server.ts: add 'MY_CODE' to correct section/subsection array
[ ] 8. en.ts: myKey: "English Label"
[ ] 9. ar.ts: myKey: "Arabic Label"
[ ] 10. git add -A ; git commit ; git push
```

---

## Common Mistakes

| Mistake | Symptom |
|---------|---------|
| Skip Step 1 (DB) | Button visible to master admin only, can't grant to others |
| Skip Step 4 (buttonActions) | Button may not respond to programmatic triggers |
| Skip Step 5 (buttonCodeToI18nKey) | Button Access Control shows raw code like `MY_BUTTON_CODE` |
| Skip Step 7 (parse-sidebar-code) | Button Generator shows wrong count in Code Base section |
| Skip Step 8 or 9 (i18n) | Button shows key string like `nav.myKey` instead of label |
| Wrong subsection in Step 7 | Button Generator count is off in wrong subsection |
| Use `onclick` instead of `on:click` | Svelte 4 syntax error — always use `on:click` |

---

## Section & Subsection IDs (Current)

### Main Sections (`button_main_sections`)
| ID | Code | Name |
|----|------|------|
| 11 | DELIVERY | Delivery |
| 12 | VENDOR | Vendor |
| 13 | MEDIA | Media |
| 14 | PROMO | Promo |
| 15 | FINANCE | Finance |
| 16 | HR | HR |
| 17 | TASKS | Tasks |
| 18 | NOTIFICATIONS | Outreach |
| 19 | USER | User |
| 20 | CONTROLS | Controls |
| 21 | STOCK | Stock |
| 22 | WHATSAPP | WhatsApp |
| 23 | LOYALTY | Loyalty |

### HR Subsections (`button_sub_sections` where main_section_id = 16)
| ID | Code | Name |
|----|------|------|
| 56 | MANAGE | Manage |
| 57 | REPORTS | Reports |
| 68 | OPERATIONS | Operations |
| 75 | DASHBOARD | Dashboard |

> To get subsection IDs for other sections, run:
> ```powershell
> ssh -i "C:\Users\ME\.ssh\id_ed25519_nopass" root@8.213.42.21 "docker exec supabase-db psql -U supabase_admin -d postgres -c 'SELECT id, subsection_name_en, subsection_code, main_section_id FROM button_sub_sections ORDER BY main_section_id, id;'"
> ```
