# AI Agent Guide: I18N (Multilingual) Implementation

## Purpose
This guide outlines the standard procedure for implementing Arabic and English translations across the Aqura Management System.

---

## 1. File Locations
- **English Translations:** `frontend/src/lib/i18n/locales/en.ts`
- **Arabic Translations:** `frontend/src/lib/i18n/locales/ar.ts`
- **I18N Configuration:** `frontend/src/lib/i18n/index.ts`

---

## 2. Adding Translation Keys

### Step A: Identify the Category
Check if your key belongs to an existing category (e.g., `common`, `hr`, `nav`, `actions`) or requires a new one.

### Step B: Update `en.ts` (English)
Add your key-value pairs. 
- Use lowercase camelCase for keys.
- Ensure proper nesting.
- **CRITICAL:** Check for duplicate keys before adding.
- **CRITICAL:** Ensure a comma exists after the previous entry.

```typescript
// en.ts
common: {
  edit: "Edit",
  save: "Save",
  // ...
}
```

### Step C: Update `ar.ts` (Arabic)
Add the same keys with their Arabic translations.
- Key names MUST be identical to `en.ts`.
- Check for RTL-specific phrasing.

```typescript
// ar.ts
common: {
  edit: "تعديل",
  save: "حفظ",
  // ...
}
```

---

## 3. Usage in Svelte Components

### Import the I18N Tools
```svelte
<script lang="ts">
    import { _ as t, locale } from '$lib/i18n';
</script>
```

### Basic Text Translation
Use the `$t` store function with the dot-notation path to the key.
```svelte
<button>{$t('common.save')}</button>
```

### Conditional Rendering (Multilingual Fields)
When dealing with database fields that have English and Arabic versions (e.g., `name_en` and `name_ar`):
```svelte
<p>{$locale === 'ar' ? (item.name_ar || item.name_en) : item.name_en}</p>
```

### Direction-Specific Logic
Use the `$locale` store to adjust layouts if necessary (though Tailwind's `rtl:` and `ltr:` classes are preferred).
```svelte
<div class={$locale === 'ar' ? 'text-right' : 'text-left'}>
```

---

## 4. Common Pitfalls & Rules

### 1. Duplicate Keys
NEVER add a key that already exists in the same scope. The TypeScript compiler will throw an `An object literal cannot have multiple properties with the same name` error.

### 2. Missing Commas
Always ensure the line before your new entry has a comma.

### 3. Brace Balance
When using `replace_string_in_file`, be extremely careful not to delete or add extra closing braces `}`. Check brace balance after every edit.

### 4. Search Scope
Before adding a generic key like `cancel` or `edit`, search `en.ts` to see if it already exists under `common` or `actions`.

### 5. Translation Missing Errors
If you see `Translation key not found: path.to.key` in the console:
- Verify the key exists in BOTH `en.ts` and `ar.ts`.
- Verify the path in `$t('...')` matches the structure in the locale files exactly.

---

## 5. Verification Checklist

- [ ] Keys added to `en.ts`.
- [ ] Keys added to `ar.ts` with same name.
- [ ] No duplicate keys in either file.
- [ ] Svelte component imports `_ as t` and `locale`.
- [ ] Svelte component uses correctly namespaced keys (e.g., `common.edit`).
- [ ] Run `get_errors` on `en.ts` and `ar.ts` to check for syntax/duplicate errors.
- [ ] Check console for "Translation key not found" warnings.
