# Language Localization Fix Process

Complete guide for implementing English and Arabic localization for UI components in the Aqura Management System.

## Overview

This document outlines the systematic process for converting hardcoded English text to a bilingual (English/Arabic) localization system using the custom i18n implementation.

## Key Principles

- ✅ All UI text must be translatable (no hardcoded text)
- ✅ Use translation function `t()` NOT `$t()` (not a Svelte store)
- ✅ Translation files must have identical key structures in both languages
- ✅ Arabic translations must be culturally appropriate and grammatically correct
- ✅ Database multilingual fields use helper functions for dynamic content

---

## Step-by-Step Localization Process

### Step 1: Identify Hardcoded Text

Scan the component for all user-facing text that needs translation:
- Button labels
- Form labels and placeholders
- Window titles and headers
- Description text
- Help text and hints
- Error/success messages

**Example - HRMaster.svelte:**
```svelte
// ❌ BEFORE - Hardcoded English text
const dashboardButtons = [
  {
    id: 'upload-employees',
    title: 'Upload Employees',           // ← Hardcoded
    description: 'Import employees from Excel file',  // ← Hardcoded
    icon: '👥',
  }
];

<h1 class="title">HR Master Dashboard</h1>  {/* ← Hardcoded */}
<p class="subtitle">Complete Human Resources Management System</p>  {/* ← Hardcoded */}
```

### Step 2: Create Translation Keys

Design translation keys following naming conventions:
- **Format**: `section.descriptiveKeyName`
- **Section**: Feature category (hr, admin, reports, etc.)
- **Key Name**: Descriptive, camelCase, no hyphens

**Example Translation Keys:**
```
hr.masterTitle                      // Header title
hr.masterSubtitle                   // Header subtitle
hr.masterUploadEmployees            // Button: Upload Employees
hr.masterUploadEmployeesDesc        // Button description
hr.masterCreateDepartment           // Button: Create Department
hr.masterCreateDepartmentDesc       // Button description
```

**Naming Conventions:**
- `master*` - For master dashboard items
- `*Desc` or `*Description` - For descriptive text
- Use full names, avoid abbreviations (employeeId not empId)
- Group related keys logically

### Step 3: Add to English Translation File (en.ts)

1. **Import location**: `frontend/src/lib/i18n/locales/en.ts`
2. **Find the appropriate section** (hr, admin, branches, etc.)
3. **Add translation keys** in the correct object

**Example - en.ts:**
```typescript
hr: {
  // ... existing translations ...
  transactions: "transactions (latest first)",
  
  // HR Master Dashboard ← Add comment for grouping
  masterTitle: "HR Master Dashboard",
  masterSubtitle: "Complete Human Resources Management System",
  masterUploadEmployees: "Upload Employees",
  masterUploadEmployeesDesc: "Import employees from Excel file",
  masterCreateDepartment: "Create Department",
  masterCreateDepartmentDesc: "Add new organizational departments",
  masterCreateLevel: "Create Level",
  masterCreateLevelDesc: "Define organizational hierarchy levels",
  // ... more items ...
},
```

### Step 4: Add to Arabic Translation File (ar.ts)

1. **Import location**: `frontend/src/lib/i18n/locales/ar.ts`
2. **Match the EXACT structure** from en.ts
3. **Add appropriate Arabic translations** with proper grammar and cultural context

**Example - ar.ts:**
```typescript
hr: {
  // ... existing translations ...
  transactions: "معاملات (الأحدث أولاً)",
  
  // لوحة مراقبة إدارة الموارد البشرية
  masterTitle: "لوحة مراقبة إدارة الموارد البشرية",
  masterSubtitle: "نظام إدارة الموارد البشرية الشامل",
  masterUploadEmployees: "تحميل الموظفين",
  masterUploadEmployeesDesc: "استيراد الموظفين من ملف Excel",
  masterCreateDepartment: "إنشاء قسم",
  masterCreateDepartmentDesc: "إضافة أقسام تنظيمية جديدة",
  masterCreateLevel: "إنشاء مستوى",
  masterCreateLevelDesc: "تحديد مستويات الهرمية التنظيمية",
  // ... more items ...
},
```

**Arabic Translation Guidelines:**
- Use modern standard Arabic (Fusha)
- Consider cultural context and business terminology
- Maintain consistency with existing translations
- Check for proper grammar and diacritics
- Use appropriate business/technical terms

### Step 5: Update Component Imports

Add the i18n import to the component:

```typescript
// ✅ CORRECT - Import t function
import { t } from '$lib/i18n';

// ❌ WRONG - Don't import currentLanguage (doesn't exist)
import { t, isRTL, currentLanguage } from '$lib/i18n';

// ❌ WRONG - Don't import $t (not an export)
import { $t } from '$lib/i18n';
```

### Step 6: Convert Hardcoded Text to Translation Keys

Replace all hardcoded text with translation function calls:

**Option A: Static Object Data (Button configurations)**
```typescript
// ❌ BEFORE - Hardcoded
const dashboardButtons = [
  {
    id: 'upload-employees',
    title: 'Upload Employees',
    description: 'Import employees from Excel file',
  }
];

// ✅ AFTER - Translation keys in data
const dashboardButtons = [
  {
    id: 'upload-employees',
    titleKey: 'hr.masterUploadEmployees',
    descriptionKey: 'hr.masterUploadEmployeesDesc',
  }
];
```

**Option B: In HTML Template**
```svelte
// ❌ BEFORE - Hardcoded
<h1>{button.title}</h1>
<p>{button.description}</p>
<h1>HR Master Dashboard</h1>

// ✅ AFTER - Using t() function
<h1>{t(button.titleKey)}</h1>
<p>{t(button.descriptionKey)}</p>
<h1>{t('hr.masterTitle')}</h1>
```

**Option C: In Script Logic**
```typescript
// ❌ BEFORE - Hardcoded
alert(`${button.title} - Coming Soon!`);

// ✅ AFTER - Using t() function
alert(`${t(button.titleKey)} - Coming Soon!`);
```

**Critical - Function vs Store Syntax:**
```svelte
<!-- ✅ CORRECT - Use as function, no $ prefix -->
<h3>{t('hr.presentToday')}</h3>

<!-- ❌ WRONG - Not a store! Causes store_invalid_shape error -->
<h3>{$t('hr.presentToday')}</h3>

<!-- ❌ WRONG - Not just a variable -->
<h3>{t}</h3>
```

### Step 7: Handle Window Titles for Dynamic Updates

**CRITICAL: Window Titles from Parent Components**

When a component like HRMaster is opened as a window from a parent component (e.g., Sidebar), the window title is set in the PARENT, not in the child component.

**Problem Example:**
```typescript
// ❌ WRONG - Window opened from Sidebar.svelte
function openHRMaster() {
  openWindow({
    title: `HR Master #${instanceNumber}`,  // ← Hardcoded in Sidebar!
    component: HRMaster,
  });
}

// ❌ Then in HRMaster.svelte, trying to track windows:
let openedWindowIds = [];  // This array stays empty!
```

**Why This Fails:**
1. The window is created by Sidebar, not HRMaster
2. HRMaster's `openedWindowIds` array never gets populated
3. When locale changes, HRMaster has no windows to update

**Correct Solution - Child Component Auto-Detects Its Own Window:**

```typescript
// ✅ CORRECT - In HRMaster.svelte
let hrMasterWindowId = null;
let windows = [];

const unsubscribe = windowManager.windowList.subscribe(w => {
  windows = w;
  
  // Find the window that contains THIS component
  if (!hrMasterWindowId && w.length > 0) {
    const hrWindow = w.find(window => window.title?.startsWith('HR Master'));
    if (hrWindow) {
      hrMasterWindowId = hrWindow.id;  // ← Found it!
    }
  }
});

// When locale changes, update THE WINDOW'S title
$: {
  if (locale && hrMasterWindowId) {
    const hrWindow = windows.find(w => w.id === hrMasterWindowId);
    if (hrWindow) {
      // Extract instance number from current title
      const match = hrWindow.title.match(/#(\d+)$/);
      const instanceNumber = match ? match[1] : '0';
      
      // Update with translated title
      const newTitle = `${t('hr.masterTitle')} #${instanceNumber}`;
      windowManager.updateWindowTitle(hrMasterWindowId, newTitle);
    }
  }
}
```

**Key Points:**
- ✅ Child component finds its own window by matching title pattern
- ✅ Child component extracts instance number from current title
- ✅ Child component updates window title when locale changes
- ✅ Parent (Sidebar) doesn't need to know about translations

**Prevention Checklist for Window Titles:**
- [ ] Window is opened in parent component (Sidebar)?
- [ ] Child component needs to detect its own window ID
- [ ] Use `windowManager.windowList.subscribe()` to watch windows
- [ ] Look for window that matches component's title pattern
- [ ] Extract instance number: `title.match(/#(\d+)$/)`
- [ ] Update with `windowManager.updateWindowTitle(windowId, newTitle)`
- [ ] Test: Switch language → window title should update immediately



### Step 8: Handle Database Multilingual Content

For data from database with multilingual fields (name_en, name_ar):

```typescript
import { t, isRTL, currentLocale } from '$lib/i18n';
import { get } from 'svelte/store';

// ✅ CORRECT - Helper function for database content
function getLocalizedText(enText: string, arText: string): string {
  const locale = get(currentLocale);
  return locale === 'ar' ? arText : enText;
}

// Usage in component
<p>{getLocalizedText(branch.name_en, branch.name_ar)}</p>
<p>{getLocalizedText(position.position_title_en, position.position_title_ar)}</p>
```

### Step 9: Verify Translation File Structure

Ensure both en.ts and ar.ts have:
- ✅ Identical key names in same sections
- ✅ No duplicate keys (causes compilation errors)
- ✅ Matching number of translations per section
- ✅ Proper closing braces and commas

**Verification Checklist:**
```
For each new translation section:
[ ] Key exists in en.ts
[ ] Same key exists in ar.ts
[ ] Key names are IDENTICAL
[ ] No duplicate keys in object
[ ] Proper closing braces and commas
[ ] English text is professional and complete
[ ] Arabic text is grammatically correct and culturally appropriate
```

### Step 9: Run Error Checking

Use the error checking tool to verify no compilation errors:

```bash
# Check for TypeScript/Svelte errors
# Verify in VS Code: Terminal > Run Task > Lint All
```

**Expected Results:**
- ✅ Component file: No errors
- ✅ Translation files: No new errors (pre-existing errors in other sections OK)
- ✅ All translation keys resolve correctly

**Common Errors to Check:**
- ❌ `store_invalid_shape` - Using `$t()` instead of `t()`
- ❌ Duplicate key errors - Same key defined twice in object
- ❌ Missing translation key - Key used in component but not in files
- ❌ Mismatched structure - Key exists in en.ts but not ar.ts

### Step 10: Test in Both Languages

After completing all changes:

1. **Test in English Mode** (default)
   - All buttons and labels display in English
   - No text appears in Arabic
   - All descriptions show correctly

2. **Test in Arabic Mode**
   - Switch app to العربية (Arabic)
   - All buttons and labels display in Arabic
   - Layout is properly RTL
   - No English text visible in UI

3. **Test Interactive Elements**
   - Click buttons - window titles should be in correct language
   - Form labels should switch languages
   - Alerts and messages should be in correct language

---

## Translation File Structure

### Location
- English: `frontend/src/lib/i18n/locales/en.ts`
- Arabic: `frontend/src/lib/i18n/locales/ar.ts`

### Organization
Files are organized by feature sections:
```typescript
export const englishLocale = {
  translations: {
    app: { ... },           // General app
    nav: { ... },           // Navigation
    mobile: { ... },        // Mobile interface
    hr: { ... },            // HR features ← Most additions go here
    branches: { ... },      // Branch management
    vendors: { ... },       // Vendor management
    reports: { ... },       // Reports
    flyer: { ... },         // Marketing flyersections
    // ... more sections ...
  }
}
```

### Import Usage

```typescript
import { t, isRTL, currentLocale } from '$lib/i18n';
import { get } from 'svelte/store';

// ✅ Use t() function in templates
<h1>{t('section.key')}</h1>

// ✅ Use t() in script logic
const title = t('section.key');
alert(t('common.saved'));

// ✅ Read current locale for conditional logic
const locale = get(currentLocale);
if (locale === 'ar') {
  // Do something for Arabic
}

// ✅ Check if RTL
import { isRTL } from '$lib/i18n';
{#if isRTL()}
  {/* RTL specific layout */}
{:else}
  {/* LTR layout */}
{/if}
```

---

## Common Patterns & Examples

### Pattern 1: Button Configuration Array

```typescript
// Component data
const buttons = [
  {
    id: 'save',
    labelKey: 'common.save',
    iconKey: 'common.saveIcon',
  },
  {
    id: 'delete',
    labelKey: 'common.delete',
    iconKey: 'common.deleteIcon',
  }
];

// Component template
{#each buttons as btn}
  <button>{t(btn.labelKey)}</button>
{/each}
```

### Pattern 2: Window/Modal Titles

```typescript
// Script
const windowTitle = t('hr.masterTitle');
openWindow({
  id: 'hr-window',
  title: windowTitle,  // Will be in current language
  component: HRComponent
});
```

### Pattern 3: Form Labels

```svelte
<!-- ✅ Correct -->
<label>{t('hr.firstName')}</label>
<input placeholder={t('hr.firstNamePlaceholder')} />

<label>{t('hr.lastName')}</label>
<input placeholder={t('hr.lastNamePlaceholder')} />
```

### Pattern 4: Database Content with Fallback

```typescript
function getLocalizedText(enText: string, arText: string): string {
  const locale = get(currentLocale);
  // Fallback to English if Arabic text is empty
  return (locale === 'ar' && arText) ? arText : enText;
}
```

### Pattern 5: Dynamic Messages

```typescript
// ✅ Correct
const message = `${t('common.saved')} ${itemName}`;

// ✅ Correct with key data
const greeting = t('common.welcome');  // "Welcome"
const userName = userRecord.name;
const fullGreeting = `${greeting}, ${userName}`;
```

---

## Error Prevention Checklist

### Before Committing Code

- [ ] Ran `get_errors` tool - no new errors introduced
- [ ] Both en.ts and ar.ts files have identical key structures
- [ ] No `$t()` syntax (that causes store_invalid_shape error)
- [ ] All hardcoded text replaced with `t('key')` function calls
- [ ] Component imports `t` from `'$lib/i18n'`
- [ ] Database content uses `getLocalizedText()` helper
- [ ] RTL/LTR handling considered for Arabic mode
- [ ] Tested in both English and Arabic language modes
- [ ] No duplicate keys in translation objects
- [ ] All commas and braces properly closed

### Translation File Verification

- [ ] English and Arabic files have identical section names
- [ ] No trailing commas before closing braces
- [ ] Matching number of keys in both files
- [ ] No keys repeated within same object
- [ ] Proper TypeScript syntax (colons, semicolons)
- [ ] Comments properly formatted (`// comment`)

### Component Testing

- [ ] All UI text appears in correct language
- [ ] Window titles switch languages correctly
- [ ] Form labels and placeholders are localized
- [ ] Button labels are localized
- [ ] Error messages are localized
- [ ] No text wrapping issues in Arabic (RTL)
- [ ] No console errors in browser

---

## Quick Reference

### i18n Module Exports
```typescript
// ✅ Correct imports
import { t, isRTL, currentLocale } from '$lib/i18n';

// ✅ What they do:
t('key.path')           // Function: Get translated string
isRTL()                 // Function: Check if RTL mode
currentLocale           // Store: Read current locale ('en' or 'ar')
```

### Translation Key Formats
```
✅ hr.masterTitle              // Two-level: section.key
✅ hr.masterUploadEmployees    // Descriptive, camelCase
✅ common.save                 // Reusable common translations
❌ hrMasterTitle               // Should be hr.masterTitle
❌ hr_upload_employees         // Should use camelCase
❌ HR_MASTER_TITLE             // Should be lowercase camelCase
```

### Template Syntax
```svelte
<!-- ✅ Correct syntax -->
<h1>{t('hr.title')}</h1>
<button on:click={handleClick}>{t('common.save')}</button>
<p>{t('hr.description')}</p>

<!-- ❌ Wrong syntax -->
<h1>{$t('hr.title')}</h1>              <!-- Not a store! -->
<h1>HR Master {t}</h1>                 <!-- Missing key -->
<h1 data-i18n="hr.title"></h1>         <!-- Not how it works -->
```

---

## Recent Examples

### BiometricData.svelte Implementation
- **File**: `frontend/src/lib/components/admin/hr/BiometricData.svelte`
- **Changes**: Added 21+ localization keys for biometric dashboard
- **Keys added**: `hr.biometricData`, `hr.presentToday`, `hr.branchBreakdown`, etc.
- **Status**: ✅ Complete, no errors, both languages supported

### HRMaster.svelte Implementation
- **File**: `frontend/src/lib/components/admin/HRMaster.svelte`
- **Changes**: Converted 11 dashboard button titles and descriptions
- **Keys added**: `hr.masterUploadEmployees`, `hr.masterCreateDepartment`, etc. (23 total)
- **Status**: ✅ Complete, no errors, both languages supported

---

## Troubleshooting

### Issue: "store_invalid_shape" Error

**Cause**: Using `$t()` instead of `t()`

**Fix**:
```svelte
// ❌ Wrong
<h1>{$t('hr.title')}</h1>

// ✅ Correct
<h1>{t('hr.title')}</h1>
```

### Issue: Translation Key Returns Undefined

**Causes**:
1. Key doesn't exist in translation file
2. Key name is different in en.ts vs ar.ts
3. Wrong section name in key

**Fix**: Verify key exists in BOTH en.ts and ar.ts with identical names

### Issue: Text Doesn't Change When Switching Language

**Cause**: Using hardcoded string instead of translation key

**Fix**: Use `t('key')` function instead of hardcoded text

### Issue: Duplicate Key Error in Translation Files

**Cause**: Same key defined twice in same object

**Fix**: Check for duplicate key names, rename one section if needed

### Issue: Window Titles Don't Update When Language Changes ⚠️ CRITICAL

**Cause**: Window is opened by parent component (e.g., Sidebar) with hardcoded title, child component can't track it

**Symptoms**:
- Window opens correctly (window appears on screen)
- Window content translates properly (component inside is in correct language)
- BUT window title bar stays in English when language switches
- Console logs show: `openedWindowIds: 0` (tracking array is empty)

**Root Problem**:
```typescript
// ❌ WRONG - Window opened in Sidebar
function openHRMaster() {
  openWindow({
    title: `HR Master #${instanceNumber}`,  // ← Hardcoded!
    component: HRMaster,  // ← Child can't change parent's window title
  });
}

// ❌ In HRMaster.svelte, this array stays empty:
let openedWindowIds = [];  // Never populated because openHRWindow() never called!
```

**Solution**: Child component must auto-detect its own window and update it

```typescript
// ✅ CORRECT - In HRMaster.svelte
import { onDestroy } from 'svelte';

let hrMasterWindowId = null;
let windows = [];

// Subscribe to window list to find this window
const unsubscribe = windowManager.windowList.subscribe(w => {
  windows = w;
  
  // Auto-detect: find window containing this component
  if (!hrMasterWindowId && w.length > 0) {
    const hrWindow = w.find(window => window.title?.startsWith('HR Master'));
    if (hrWindow) {
      hrMasterWindowId = hrWindow.id;  // ← Found it!
    }
  }
});

onDestroy(() => unsubscribe());

// When locale changes, update window title
$: {
  if (locale && hrMasterWindowId) {
    const hrWindow = windows.find(w => w.id === hrMasterWindowId);
    if (hrWindow) {
      // Extract instance number: "HR Master #450" → "450"
      const match = hrWindow.title.match(/#(\d+)$/);
      const instanceNumber = match ? match[1] : '0';
      
      // Update with translated title
      const newTitle = `${t('hr.masterTitle')} #${instanceNumber}`;
      windowManager.updateWindowTitle(hrMasterWindowId, newTitle);
    }
  }
}
```

**Prevention Checklist - ALWAYS check this for window title issues**:
- [ ] Is window opened in PARENT component (Sidebar, Modal, etc.)?
- [ ] Does child component need to update window title when locale changes?
- [ ] Child component subscribing to `windowManager.windowList`?
- [ ] Auto-detecting window by title pattern matching?
- [ ] Extracting instance number with regex: `/#(\d+)$/`?
- [ ] Calling `windowManager.updateWindowTitle()` when locale changes?
- [ ] Test: Open window → switch language → title should update immediately

### Issue: Arabic Text Shows Unformatted or Wrong Direction

**Cause**: Missing RTL CSS or improper layout

**Fix**: Use `isRTL()` or `currentLocale` store to adjust styling:
```svelte
{#if isRTL()}
  <div style="direction: rtl; text-align: right;">...</div>
{:else}
  <div style="direction: ltr; text-align: left;">...</div>
{/if}
```

---

## Best Practices

1. **Always add translations BEFORE implementation** - Don't wait until after component is built
2. **Keep keys descriptive** - Avoid abbreviations, use full names
3. **Group related translations** - Keep similar items in same section
4. **Test in both languages** - Every language feature must work in English AND Arabic
5. **Use helper functions** - For database content with multilingual fields
6. **No hardcoded text** - All user-facing text must be translatable
7. **Keep files synchronized** - en.ts and ar.ts must have matching structures
8. **Run error checks** - Always verify after making changes
9. **Document changes** - Add comments in translation files for clarity
10. **Review Arabic translations** - Ensure cultural appropriateness

---

## Version Management

When completing localization work:
1. Update version: `npm run version:patch` or `:minor` or `:major`
2. Update version popup in `Sidebar.svelte` with feature descriptions
3. Commit: `git commit -m "feat: add Arabic/English localization for [feature]"`
4. Push: `git push origin master`

---

## Additional Resources

- **i18n Module**: `frontend/src/lib/i18n/`
- **Translation Files**: `frontend/src/lib/i18n/locales/`
- **Copilot Instructions**: `.copilot-instructions.md` - Section 6 (Bilingual Language Support Protocol)
- **Components**: Check `BiometricData.svelte` and `HRMaster.svelte` for working examples

---

## ⚠️ CRITICAL ISSUES - MUST PREVENT

### Window Title Translation (Most Common Mistake)

**DO NOT** try to track windows in component's `openedWindowIds` array when window is opened by parent.

**ALWAYS** use this pattern in child component:
1. Subscribe to `windowManager.windowList`
2. Auto-detect window by title pattern
3. Extract instance number from current title
4. Update with translated title when locale changes

See **Troubleshooting > Window Titles Don't Update** section above for complete solution.

---

**Last Updated**: November 29, 2025  
**Maintained By**: GitHub Copilot  
**Status**: Active Documentation  
**Critical Issue Fixed**: Window Title Translation Pattern (Nov 29, 2025)
