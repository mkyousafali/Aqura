# Migration Guide: Clear Old Supabase Data

Your application is configured to use the self-hosted Supabase at `https://supabase.urbanaqura.com`, but old cached data from your previous Supabase instance might still be stored in the browser.

## ⚠️ Problem
- Old Supabase data is cached in browser storage (localStorage, IndexedDB, service worker cache)
- This cached data takes priority over new requests
- New data still gets created but old data conflicts

## ✅ Solution: Complete Cache Cleanup

### Option 1: Manual Browser Cleanup (Recommended for first time)

1. **Open your browser's Developer Tools**
   - Press `F12` or `Ctrl+Shift+I` (Windows/Linux)
   - Press `Cmd+Option+I` (Mac)

2. **Go to Application Tab**
   - Click on "Application" tab in DevTools
   
3. **Clear Storage:**
   - Click "Storage" → "Clear site data" (checkbox all)
   - Select all options and click "Clear"
   
4. **Clear Cache:**
   - Click "Cache Storage" 
   - Right-click each cache and delete it

5. **Unregister Service Workers:**
   - Click "Service Workers"
   - Unregister all service workers

6. **Clear IndexedDB:**
   - Expand "IndexedDB"
   - Delete all databases

### Option 2: Automatic Cleanup (Using Console)

1. **Open Developer Console** (F12 → Console tab)

2. **Copy and paste this code:**
```javascript
async function clearOldSupabaseData() {
  console.log('🔄 Starting data migration cleanup...');
  
  // 1. Clear localStorage
  localStorage.clear();
  
  // 2. Clear sessionStorage
  sessionStorage.clear();
  
  // 3. Clear IndexedDB
  const dbs = await indexedDB.databases();
  for (const db of dbs) {
    indexedDB.deleteDatabase(db.name);
  }
  
  // 4. Clear service worker caches
  if ('caches' in window) {
    const cacheNames = await caches.keys();
    for (const cacheName of cacheNames) {
      await caches.delete(cacheName);
    }
  }
  
  // 5. Unregister service workers
  const registrations = await navigator.serviceWorker.getRegistrations();
  for (const registration of registrations) {
    await registration.unregister();
  }
  
  // 6. Clear cookies
  document.cookie.split(";").forEach((c) => {
    document.cookie = c
      .replace(/^ +/, "")
      .replace(/=.*/, `=;expires=${new Date().toUTCString()};path=/`);
  });
  
  console.log('✅ All old data cleared!');
}

clearOldSupabaseData();
```

3. **Press Enter**

### Option 3: Hardest Reset (Nuclear Option)

If the above doesn't work:

```bash
# Windows (PowerShell)
Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Recurse
Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker" -Recurse

# Mac
rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache
rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Service\ Worker

# Linux
rm -rf ~/.cache/google-chrome/Default/Cache
rm -rf ~/.cache/google-chrome/Default/Service\ Worker
```

---

## 🔄 After Cleanup: Hard Refresh

1. **Hard refresh your browser:**
   - Windows/Linux: `Ctrl+Shift+R`
   - Mac: `Cmd+Shift+R`

2. **Your app will now:**
   - Use the new Supabase client configuration
   - Connect to `https://supabase.urbanaqura.com`
   - Create fresh connections without old cache

3. **Login again** with your credentials

---

## ✨ Verify Migration is Working

After cleanup, check these in DevTools Console:

```javascript
// Check Supabase URL
console.log(import.meta.env.VITE_SUPABASE_URL)
// Should show: https://supabase.urbanaqura.com

// Check IndexedDB is empty
indexedDB.databases().then(dbs => console.log('IndexedDB:', dbs))
```

---

## 🐛 If Data Still Goes to Old Supabase

This means your backend is still pointing to the old database. Check:

1. **Backend DATABASE_URL** in `backend/.env`
   - Currently set to: `PENDING_NEW_DATABASE_URL`
   - Should be: `postgres://postgres:PASSWORD@db.supabase.urbanaqura.com:5432/postgres`

2. **Provide your PostgreSQL password** and I'll update it

3. **Restart the backend server** after updating `.env`

---

## 📝 Summary

| Component | Current Config | Status |
|-----------|-----------------|--------|
| Frontend Supabase URL | `https://supabase.urbanaqura.com` | ✅ Correct |
| Frontend Auth Keys | Valid keys | ✅ Correct |
| Backend Supabase URL | `https://supabase.urbanaqura.com` | ✅ Correct |
| Backend Database URL | `PENDING_NEW_DATABASE_URL` | ❌ **MISSING** |
| Browser Cache | Old data | ❌ **NEEDS CLEANUP** |

**Your data will go to self-hosted Supabase once you:**
1. ✅ Clean browser cache (do this first)
2. ⏳ Update backend DATABASE_URL (provide password)
3. ⏳ Restart backend server
