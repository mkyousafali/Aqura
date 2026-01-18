# AI Agent Guide: Svelte Logic and Store Integrity

## Purpose
This guide helps AI agents avoid logical and runtime errors when editing Svelte components, specifically regarding stores, imports, and i18n integration.

---

## Critical Rules for Svelte Logic and Stores

### 1. **i18n Implementation Pattern**
In this workspace, the i18n system uses a specific pattern. Failure to follow this will cause a `store_invalid_shape` error.

**Pattern:**
- `_` is the **reactive store** (derived from localeData).
- `t` is a **plain function** (get-based, non-reactive).

**Rule:**
If you use `$t(...)` in the template or script, you **MUST** import `_` as `t`.

```typescript
// CORRECT: Using $t (reactive)
import { _ as t } from '$lib/i18n';

// WRONG: Using $t with this import will crash
import { t } from '$lib/i18n';
```

### 2. **Always Check Import Paths and Symbols**
Before adding a new feature or fixing logic, read the existing imports.

- **Supabase:** Always import from `$lib/utils/supabase`.
- **Stores:** Check if the variable being accessed with `$` is actually a store.
- **Components:** Verify the relative or aliased path (e.g., `$lib/components/...`).

### 3. **Avoid "Blind" Replacements**
When using `replace_string_in_file`, ensure you include enough context (3-5 lines) to avoid replacing the wrong occurrence or breaking the indentation. Svelte is sensitive to tag placement and script/style block boundaries.

### 4. **Incremental Testing with `get_errors`**
After every logic or import change:
1. Use the `get_errors` tool on the file you edited.
2. If errors exist, fix them immediately before moving to the next task.
3. Don't assume "no news is good news"—compiler errors can break the entire UI.

### 5. **Common Logical Pitfalls**

#### Pitfall #1: Reactive Assignments
In Svelte 4/5, remember how reactivity works. 
```javascript
// Local variables are only reactive if reassigned
let value = 0;
function update() {
    value += 1; // Triggered correctly
}

// Objects/Arrays need reassignment or specific update patterns
let list = [];
function add() {
    list = [...list, newItem]; // Safe reassignment for reactivity
}
```

#### Pitfall #2: Store Subscription Cleanup
If you manually subscribe to a store in `<script>`, ensure you return the unsubscription function in `onUnmount`. Often, using the `$` prefix is safer and cleaner as Svelte handles the lifecycle automatically.

---

## Verification Checklist for Logic Edits

```
□ Is every variable prefixed with $ actually a store?
□ Did I import { _ as t } if I used $t?
□ Did I verify the Supabase table names against migrations?
□ Did I use get_errors to check for compiler/lint issues?
□ If I added an async function, did I handle errors (try/catch)?
□ Are all my imports correctly resolved (no red squigglies)?

---

## 6. RTL (Arabic) UI Implementation Rule

When implementing Arabic support, ensure the UI flips correctly.

### **CSS for Dropdown Arrows**
Standard browser dropdown arrows often don't flip or align well in RTL. Always add this global CSS to your Svelte component's `<style>` block:

```css
/* RTL Adjustments for Select Arrows */
:global([dir="rtl"] select) {
    background-position: left 0.75rem center !important;
    padding-left: 2.5rem !important;
    padding-right: 0.75rem !important;
}
```

### **Directional Attributes**
Ensure the root container or modals have the `dir` attribute:
```svelte
<div dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
```

### **Arrow Symbols in Buttons**
Manual arrow symbols (←, →) should be flipped manually:
```svelte
<button>{$locale === 'ar' ? '→' : '←'} {$t('hr.prev')}</button>
```
```

## How to Update Without Errors

1. **Research:** Read the target file AND its dependencies (e.g., `src/lib/i18n/index.ts`).
2. **Context:** Search the codebase for similar patterns (e.g., `grep_search "$t("`).
3. **Draft:** Plan the exact string replacement including whitespace.
4. **Execute:** Apply changes.
5. **Verify:** Use `get_errors` and check the local dev server output if possible.
