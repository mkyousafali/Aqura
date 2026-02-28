# 🪟 Pop-Out Window System — AI Agent Guide

## Overview

The Aqura desktop interface allows users to "pop out" any window into a separate browser window. This creates a complex cross-window communication architecture that requires careful handling.

**This guide covers:**
- How the pop-out system works (architecture)
- How to fix common pop-out bugs
- How sub-windows work inside popped-out windows
- Key files and their roles
- Critical pitfalls and solutions

---

## 🏗️ Architecture

### Window Hierarchy

When a window is popped out, the following hierarchy is created:

```
┌────────────────────────────────────────────┐
│  MAIN APP (Tab 1)                          │
│  - SvelteKit app at /desktop-interface     │
│  - Runs windowManager store               │
│  - All windows rendered here normally      │
│  - Listeners: storage, BroadcastChannel,   │
│    postMessage                             │
└─────────────┬──────────────────────────────┘
              │ window.open("", popout_features)
              ▼
┌────────────────────────────────────────────┐
│  POP-OUT WINDOW (Window 2)                 │
│  - Raw HTML (NOT SvelteKit)                │
│  - Created via window.open() + innerHTML   │
│  - Has header bar: "Return to App" + Close │
│  - Script injected via createElement       │
│  - Relays messages: iframe → opener        │
│  - window.opener = Main App                │
│  ┌────────────────────────────────────────┐│
│  │  IFRAME (inside Window 2)              ││
│  │  - SvelteKit app at                    ││
│  │    /desktop-interface?popout=<id>      ││
│  │  - Loads component via import.meta.glob││
│  │  - Runs its OWN windowManager instance ││
│  │  - window.parent = Pop-out Window      ││
│  │  - Same origin as Main App             ││
│  └────────────────────────────────────────┘│
└────────────────────────────────────────────┘
```

### Key Insight

The pop-out window (Window 2) is **raw HTML** — it is NOT a SvelteKit page. It's created by writing HTML directly to a new browser window. The actual SvelteKit app runs inside an **iframe** within that window.

This means:
- The iframe has its **own separate** Svelte store instances
- Svelte components **cannot** be serialized across windows (they are JS classes/functions)
- Communication between the iframe and main app requires explicit messaging

---

## 📁 Key Files

| File | Lines | Role |
|------|-------|------|
| `frontend/src/lib/stores/windowManager.ts` | ~1050 | Core store: `popOutWindow()`, `popInWindow()`, `WindowConfig` interface |
| `frontend/src/lib/utils/windowManagerUtils.ts` | ~110 | Context-aware `openWindow()` — detects popout, routes messages |
| `frontend/src/lib/components/common/Window.svelte` | ~660 | Individual window UI — title bar hiding, popout CSS, pop-out button |
| `frontend/src/lib/components/common/WindowManager.svelte` | ~130 | Container — filters windows for popout vs normal rendering |
| `frontend/src/routes/desktop-interface/+layout.svelte` | ~1450 | Layout — popout detection, component loading, cross-window messaging |

---

## 🔧 WindowConfig Interface

```typescript
export interface WindowConfig {
  id: string;
  title: string;
  component: any;                // Svelte component (NOT serializable!)
  componentName?: string;        // String name for cross-window serialization
  props?: Record<string, any>;
  icon?: string;
  position: { x: number; y: number };
  size: { width: number; height: number };
  resizable?: boolean;
  minimizable?: boolean;
  maximizable?: boolean;
  closable?: boolean;
  popOutEnabled?: boolean;       // Default: true
  isPoppedOut?: boolean;         // Tracks if currently popped out
  popOutWindow?: Window;         // Reference to the browser popup
  // ... other fields
}
```

### Critical: `componentName`

When opening a window that may be popped out or opened from a popped-out context, **always set `componentName`** explicitly:

```typescript
openWindow({
  title: 'My Component',
  component: MyComponent,
  componentName: 'MyComponent',    // ← MUST match the Svelte filename
  // ...
});
```

The `componentName` must match the `.svelte` filename exactly (without extension). This is used by `componentLoaderMap` (built from `import.meta.glob`) to dynamically load the component in the popout iframe.

---

## 🔄 Pop-Out Flow (Happy Path)

### 1. User Clicks Pop-Out Button

In `Window.svelte`:
```svelte
function popOut() {
  if (window.popOutEnabled && !window.isPoppedOut) {
    windowManager.popOutWindow(window.id);
  }
}
```

### 2. `popOutWindow()` in `windowManager.ts`

1. Checks for PWA mode (uses fullscreen fallback if PWA)
2. Opens new browser window via `window.open("", features)`
3. Resolves `componentName` (explicit → `component.name` → HMR metadata → title-based inference)
4. Builds iframe URL: `${baseUrl}?popout=${windowId}&windowData=${encodedJSON}`
5. Writes HTML to popup: header bar + iframe
6. **Creates `<script>` element programmatically** (NOT innerHTML) and appends it
7. Marks window as `isPoppedOut: true`, `state: "minimized"` in main app
8. Adds `beforeunload` listener to auto-restore

### 3. Iframe Loads SvelteKit App

In `+layout.svelte`:
1. Detects `isPopoutMode = true` from URL param `?popout=`
2. Parses `windowData` from URL (or waits for `postMessage` if data is large)
3. Uses `componentLoaderMap` (from `import.meta.glob`) to dynamically load the component
4. Opens the window in the iframe's local windowManager
5. Renders with `<WindowManager popoutOnly={popoutWindowId} />`

### 4. Window Renders in Popout

- `WindowManager.svelte` filters to show only the target window
- `Window.svelte` detects `isInPopout` and hides its title bar (popup has its own header)
- CSS removes borders/shadows and makes window fill the viewport

---

## 🧩 Sub-Window Communication (Opening Windows from Popout)

This is the most complex part. When a user clicks a button inside a popped-out window that should open a NEW window (e.g., "Account Recovery" inside Customer Master), the new window must open in the **main app**, not in the popout iframe.

### Communication Chain

```
Component in popout iframe
  → openWindow() from windowManagerUtils.ts
    → detects isInPopoutContext()
      → Method 1: postMessage to window.parent (popup window)
        → Popup's relay script forwards to window.opener (main app)
      → Method 2 (fallback): localStorage event
        → Main app's storage listener picks it up
      → Method 3 (fallback): BroadcastChannel
        → Main app's BroadcastChannel listener picks it up

Main app receives message
  → handleOpenWindowFromPopout()
    → componentLoaderMap[componentName]() to load component
    → windowManager.openWindow() with loaded component
```

### Three Communication Methods

#### Method 1: postMessage Relay (Primary)

```
Iframe → postMessage → Popup Window → relay script → postMessage → Main App (opener)
```

The popup window has a relay script (injected via `createElement('script')`) that forwards `open-window-from-popout` messages from the iframe to `window.opener`:

```javascript
// In popup window's script (windowManager.ts popOutWindow())
window.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'open-window-from-popout') {
    if (window.opener && !window.opener.closed) {
      window.opener.postMessage(event.data, '*');
    }
  }
});
```

#### Method 2: localStorage (Fallback)

```
Iframe → localStorage.setItem() → storage event → Main App
```

The `storage` event fires in ALL other same-origin browsing contexts. Since the iframe and main app share the same origin, this works cross-window.

Key in `windowManagerUtils.ts`:
```typescript
const key = "aqura-open-window-" + Date.now();
localStorage.setItem(key, JSON.stringify(message));
```

Listener in `+layout.svelte`:
```typescript
window.addEventListener('storage', (event) => {
  if (event.key?.startsWith('aqura-open-window-') && event.newValue) {
    const data = JSON.parse(event.newValue);
    handleOpenWindowFromPopout(data);
  }
});
```

#### Method 3: BroadcastChannel (Fallback)

```
Iframe → BroadcastChannel → Main App
```

Both the iframe and main app create a `BroadcastChannel('aqura-window-manager')`.

### Main App Handler

In `+layout.svelte`:
```typescript
function handleOpenWindowFromPopout(data: any) {
  const { windowConfig, componentName } = data;
  const resolvedName = componentName || windowConfig?.componentName || '';
  const loader = componentLoaderMap[resolvedName];
  if (loader) {
    loader().then((mod) => {
      windowManager.openWindow({ ...windowConfig, component: mod.default });
    });
  }
}
```

### Component Auto-Discovery

Components are auto-discovered via `import.meta.glob`:

```typescript
const _componentModules = import.meta.glob(
  '../../lib/components/desktop-interface/**/*.svelte'
);
const componentLoaderMap: Record<string, () => Promise<any>> = {};
for (const [path, loader] of Object.entries(_componentModules)) {
  const match = path.match(/([^/\\]+)\.svelte$/);
  if (match) {
    componentLoaderMap[match[1]] = loader as () => Promise<any>;
  }
}
```

This means ANY `.svelte` file under `lib/components/desktop-interface/` is automatically available — no manual registration needed. The key is the **filename without extension**.

---

## ⚠️ Critical Pitfalls & Solutions

### Pitfall 1: `<script>` Tags in innerHTML Don't Execute

**Problem:** In early versions, the popup window's HTML was set via `popOutWindow.document.body.innerHTML = '...<script>...</script>'`. Script tags injected via `innerHTML` are **never executed** by browsers.

**Solution:** Use `document.createElement('script')` + `appendChild()`:

```typescript
const script = popOutWindow.document.createElement("script");
script.textContent = `... your script code ...`;
popOutWindow.document.body.appendChild(script);
```

**This was the root cause of many relay failures.** If you see `innerHTML` with `<script>` tags in the popup, that's a bug.

### Pitfall 2: Svelte Components Can't Cross Windows

**Problem:** Svelte components are JavaScript class/function references. They CANNOT be serialized via `postMessage`, `localStorage`, or `BroadcastChannel`. Attempting to include `component` in a message will fail.

**Solution:** Always strip the `component` property and send only `componentName`:

```typescript
const { component, ...serializableConfig } = config;
const message = {
  type: "open-window-from-popout",
  windowConfig: serializableConfig,
  componentName: componentName,  // String, not component reference
};
```

The receiving side uses `componentLoaderMap[componentName]()` to dynamically import the component.

### Pitfall 3: isInPopout Detection

**Problem:** The popup iframe URL uses `?popout=` (query parameter), but early code only checked `location.hash` for `#popout=`.

**Solution:** Check BOTH:

```svelte
$: isInPopout = typeof globalThis !== 'undefined' && globalThis.window 
  && (globalThis.window.location.search.includes('popout=') 
      || globalThis.window.location.hash.includes('#popout='));
```

### Pitfall 4: Dual Headers

**Problem:** The popup window has its own header bar ("Return to App" + "Close"). If the inner Window.svelte also shows its title bar, there are two headers.

**Solution:** Window.svelte hides its title bar when in popout mode:

```svelte
{#if !isInPopout}
  <div class="title-bar">...</div>
{/if}
```

### Pitfall 5: postMessage Origin Issues

**Problem:** The popup window is opened with `window.open("", ...)` which gives it an `about:blank` origin. Messages from the iframe to `window.parent` may have origin mismatches.

**Solution:** The main app's message listener accepts blank/null origins:

```typescript
const isPopoutOrigin = event.origin === 'null' || event.origin === '' || event.origin === 'about:';
if (!isSameOrigin && !isPopoutOrigin) return;
```

### Pitfall 6: `componentName` Not Set

**Problem:** If `componentName` isn't set on the `openWindow()` call, the system falls back to `component.name`. In production builds, Svelte component names are often minified to single characters or `wrapper`/`Proxy`.

**Solution:** Always set `componentName` explicitly. The `windowManager.ts` also has a title-based fallback that infers component names from window titles (lines ~446-515), but this is fragile and only covers known patterns.

### Pitfall 7: Props Too Large for URL

**Problem:** When `windowData` is encoded in the iframe URL and props are large (>1000 chars), the URL may exceed browser limits.

**Solution:** `windowManager.ts` checks props size. If >1000 chars, it uses `postMessage` to send data to the iframe after it loads (via `popout-ready` / `popout-window-data` messages).

---

## 🔍 Debugging Checklist

When pop-out windows have issues, check the following:

### Blank Pop-out Window
1. Open browser DevTools in the popup window (right-click → Inspect)
2. Check console for errors
3. Verify the iframe URL loads correctly
4. Check if `componentName` resolves correctly (look for `🪟 Unknown component:` errors)
5. Verify `componentLoaderMap` contains the component: `console.log(Object.keys(componentLoaderMap).sort())`

### Sub-Window Not Opening from Popout
1. In the popout iframe's console, look for `🪟 Popout context detected` log
2. Check which communication method was used (postMessage/localStorage/BroadcastChannel)
3. In the **main app** tab's console, look for `🪟 localStorage storage event received` or `🪟 BroadcastChannel received` or `🪟 Parent received message`
4. Check if `componentName` matches a key in `componentLoaderMap`
5. Verify the popup window's relay script is running — look for `🪟 Popout window script initialized successfully` in the popup's console
6. If the relay script isn't running, the `<script>` tag is likely using `innerHTML` (broken) instead of `createElement` (working)

### "Return to App" Button Not Working
1. Check popup console for `returnToApp is not defined` error
2. If so, the script is injected via `innerHTML` (broken) — must use `createElement`
3. `window.opener` may be null if popup was opened from a different origin

### Pop-out Shows Dual Headers
1. Check if `Window.svelte` has `{#if !isInPopout}` around the title bar
2. Verify `isInPopout` checks both `location.search` and `location.hash`

---

## 📋 Adding a New Window That Works in Popout

When creating a new component that opens sub-windows:

### Step 1: Import the safe opener

```typescript
import { openWindow } from '$lib/utils/windowManagerUtils';
```

**NOT** `windowManager.openWindow()` directly.

### Step 2: Always set `componentName`

```typescript
openWindow({
  id: generateWindowId('my-window'),
  title: 'My Window',
  component: MyComponent,
  componentName: 'MyComponent',  // ← MUST match filename
  props: { someData: 'value' },
  icon: '📱',
  size: { width: 800, height: 600 },
  position: { x: 200, y: 100 },
});
```

### Step 3: Verify the component file exists

The file must be under `frontend/src/lib/components/desktop-interface/` so `import.meta.glob` discovers it.

### Step 4: Test in popout mode

1. Open the parent window normally
2. Pop it out
3. Click the button that opens a sub-window
4. The sub-window should appear in the main app tab

---

## 🔧 Fixing Components That Use `windowManager.openWindow()` Directly

These components bypass the popout-safe wrapper and will NOT work when popped out:

| Component | Line |
|-----------|------|
| `ViewOfferManager.svelte` | Lines 72, 99 |
| `DesignPlanner.svelte` | Line 1031 |

To fix, change:
```typescript
// BEFORE (broken in popout):
import { windowManager } from '$lib/stores/windowManager';
windowManager.openWindow({ ... });

// AFTER (works everywhere):
import { openWindow } from '$lib/utils/windowManagerUtils';
openWindow({ ... });
```

---

## 🏗️ Adding New Title-Based Component Name Inference

If adding a new component and `componentName` is not explicitly set, you can add a title-based fallback in `windowManager.ts` (inside `popOutWindow()` method, around line 450):

```typescript
} else if (windowConfig.title.includes("My New Window")) {
  componentName = "MyNewComponent";
}
```

But **prefer setting `componentName` explicitly** on all `openWindow()` calls instead.

---

## 📊 Communication Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      MAIN APP TAB                       │
│                                                         │
│  ┌─────────────────────────────────────────────┐       │
│  │ +layout.svelte (desktop-interface)          │       │
│  │                                             │       │
│  │  Listeners:                                 │       │
│  │  1. window.addEventListener('storage')      │  ←────┤── localStorage from iframe
│  │  2. BroadcastChannel('aqura-window-manager')│  ←────┤── BroadcastChannel from iframe
│  │  3. window.addEventListener('message')      │  ←────┤── postMessage from popup opener
│  │                                             │       │
│  │  Handler:                                   │       │
│  │  handleOpenWindowFromPopout(data)           │       │
│  │    → componentLoaderMap[name]()             │       │
│  │    → windowManager.openWindow(config)       │       │
│  └─────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    POPUP WINDOW                         │
│  (created via window.open, raw HTML)                    │
│  window.opener = Main App                               │
│                                                         │
│  ┌─────────────────────────┐                           │
│  │ Relay Script             │                           │
│  │ (createElement'd)        │                           │
│  │                          │                           │
│  │ Listens for messages     │                           │
│  │ from iframe, forwards    │──→ window.opener.postMessage
│  │ to window.opener         │                           │
│  └─────────────────────────┘                           │
│                                                         │
│  ┌─────────────────────────────────────────────┐       │
│  │ IFRAME (SvelteKit app)                      │       │
│  │ URL: ?popout=<id>&windowData=<json>         │       │
│  │                                             │       │
│  │ Component calls:                            │       │
│  │ openWindow() from windowManagerUtils.ts     │       │
│  │   → isInPopoutContext() = true              │       │
│  │   → Method 1: postMessage to window.parent  │──→ Relay
│  │   → Method 2: localStorage.setItem()        │──→ Main App
│  │   → Method 3: BroadcastChannel              │──→ Main App
│  │   → Method 4: windowManagerProxy            │       │
│  └─────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 Pop-In Flow

When the pop-out window is closed or "Return to App" is clicked:

1. `returnToApp()` sends `{ type: 'pop-in-window', windowId }` to `window.opener`
2. Or `beforeunload` event triggers `windowManager.popInWindow(windowId)`
3. `popInWindow()`:
   - Sets `isPoppedOut = false`
   - Sets `state = "normal"`
   - Closes the popup window if still open
   - Activates the window in the main app
   - Window reappears in the main app desktop

---

## 🧪 PWA Fallback

When the app runs as a PWA (standalone mode, iOS PWA, or WebView):
- `window.open()` may not work or may not create a separate window
- `popOutWindow()` detects PWA mode and calls `showWindowFullscreen()` instead
- This maximizes the window, hides all other windows, and shows a floating "← Back to Desktop" overlay button
- No cross-window communication is needed in this mode

---

## ✅ Summary of Fixes Applied

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Blank popout window | `componentName` not resolving | Added HMR metadata + title-based inference fallback |
| Dual headers | Title bar showing in both popup and iframe | `{#if !isInPopout}` around title bar in Window.svelte |
| `isInPopout` not detecting | Only checked `location.hash` for `#popout=` | Also check `location.search` for `?popout=` |
| Sub-window not opening from popout | `<script>` in innerHTML never executes | Use `createElement('script')` + `appendChild()` |
| Sub-window not opening (backup) | No cross-tab communication | Added localStorage + BroadcastChannel fallback channels |
| `returnToApp()` not working | Function defined in non-executing script | Moved to `createElement('script')` |
