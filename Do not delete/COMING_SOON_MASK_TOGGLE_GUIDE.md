# Currently Not Available Mask Toggle Guide (Customer Login Pages)

## Overview

The customer login pages have "Currently Not Available" masks/overlays that can be toggled on and off. These were used to indicate that the **Home Delivery & Store Pickup** feature via access code login is not yet available. There are **3 files** that need to be changed to fully enable or disable the masks.

---

## Files That Need Changes

### 1. `frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte`

**What it controls:** A white overlay with "Currently Not Available: Home Delivery & Store Pickup" text that covers the access code input section. Also disables the access code input fields, submit button, forgot/register links.

**Line ~13 — `showMask` prop default value:**

```svelte
// TO REMOVE (current state):
export let showMask: boolean = false;

// TO ADD BACK:
export let showMask: boolean = true;
```

**How it works:**
- `showMask` prop → sets `blockAccessCodeInput` variable (line ~39)
- `blockAccessCodeInput` controls:
  - The "Currently Not Available" mask overlay (line ~611: `{#if blockAccessCodeInput}`)
  - Disabling digit inputs (line ~640: `disabled={isLoading || blockAccessCodeInput}`)
  - Disabling remember device checkbox (line ~658)
  - Disabling submit button (line ~669)
  - Disabling forgot/register links (lines ~685, ~689)

---

### 2. `frontend/src/routes/login/+page.svelte`

**What it controls:** A dark semi-transparent overlay (`rgba(0, 0, 0, 0.75)` with `blur(3px)`) that covers the entire CustomerLogin component wrapper on the main `/login` page (when customer mode is selected).

**Line ~23 — `showMask` variable:**

```svelte
// TO REMOVE (current state):
let showMask = false;

// TO ADD BACK:
let showMask = true;
```

**How it works:**
- Line ~162: `{#if showMask}` → renders `<div class="login-mask"></div>` overlay
- This is a page-level variable, NOT passed as a prop to CustomerLogin

---

### 3. `frontend/src/routes/login/customer/+page.svelte`

**What it controls:** A light semi-transparent overlay (`rgba(255, 255, 255, 0.3)` with no blur) that covers the entire CustomerLogin component wrapper on the `/login/customer` dedicated page.

**Line ~10 — `showMask` variable:**

```svelte
// TO REMOVE (current state):
let showMask = false;

// TO ADD BACK:
let showMask = true;
```

**How it works:**
- Line ~69: `{#if showMask}` → renders `<div class="login-mask"></div>` overlay
- This is a page-level variable, NOT passed as a prop to CustomerLogin

---

## Quick Reference

### To REMOVE all "Currently Not Available" masks (allow customer login):

| File | Change |
|------|--------|
| `CustomerLogin.svelte` line ~13 | `export let showMask: boolean = false;` |
| `login/+page.svelte` line ~23 | `let showMask = false;` |
| `login/customer/+page.svelte` line ~10 | `let showMask = false;` |

### To ADD BACK all "Currently Not Available" masks (block customer login):

| File | Change |
|------|--------|
| `CustomerLogin.svelte` line ~13 | `export let showMask: boolean = true;` |
| `login/+page.svelte` line ~23 | `let showMask = true;` |
| `login/customer/+page.svelte` line ~10 | `let showMask = true;` |

---

## Important Notes

- The `/customer-interface/login/+page.svelte` page explicitly passes `showMask={false}` as a prop to `<CustomerLogin>` — this page is NOT affected by the default value change. It always shows the login form without a mask.
- Each of the 3 files above look for a comment starting with `// NOTE:` that explains the mask state. Update the comment when toggling.
- The `login-mask` CSS styles in `/login/+page.svelte` and `/login/customer/+page.svelte` are different:
  - `/login` page: dark overlay with blur (`rgba(0, 0, 0, 0.75)`, `backdrop-filter: blur(3px)`)
  - `/login/customer` page: light overlay without blur (`rgba(255, 255, 255, 0.3)`, `backdrop-filter: blur(0px)`)
- All **3 files must be changed together** for consistent behavior across all login entry points.
