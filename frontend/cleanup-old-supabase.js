// Script to clear old Supabase data and migrate to new self-hosted instance
// Run this in the browser console to clear all cached data

async function clearOldSupabaseData() {
  console.log('🔄 Starting data migration cleanup...');
  
  try {
    // 1. Clear ALL localStorage
    console.log('1️⃣ Clearing localStorage...');
    localStorage.clear();
    console.log('✅ localStorage cleared');
    
    // 2. Clear ALL sessionStorage
    console.log('2️⃣ Clearing sessionStorage...');
    sessionStorage.clear();
    console.log('✅ sessionStorage cleared');
    
    // 3. Clear IndexedDB
    console.log('3️⃣ Clearing IndexedDB databases...');
    const dbs = await indexedDB.databases();
    for (const db of dbs) {
      console.log(`   - Deleting IndexedDB: ${db.name}`);
      indexedDB.deleteDatabase(db.name);
    }
    console.log('✅ IndexedDB databases cleared');
    
    // 4. Clear service worker caches
    console.log('4️⃣ Clearing service worker caches...');
    if ('caches' in window) {
      const cacheNames = await caches.keys();
      for (const cacheName of cacheNames) {
        console.log(`   - Deleting cache: ${cacheName}`);
        await caches.delete(cacheName);
      }
      console.log('✅ Service worker caches cleared');
    }
    
    // 5. Unregister service workers
    console.log('5️⃣ Unregistering service workers...');
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) {
      console.log(`   - Unregistering: ${registration.scope}`);
      await registration.unregister();
    }
    console.log('✅ Service workers unregistered');
    
    // 6. Clear cookies related to authentication
    console.log('6️⃣ Clearing cookies...');
    document.cookie.split(";").forEach((c) => {
      document.cookie = c
        .replace(/^ +/, "")
        .replace(/=.*/, `=;expires=${new Date().toUTCString()};path=/`);
    });
    console.log('✅ Cookies cleared');
    
    console.log('\n✅ ✅ ✅ All old data cleared! ✅ ✅ ✅');
    console.log('🔄 The app will now use your self-hosted Supabase at: https://supabase.urbanaqura.com');
    console.log('\n📝 Next steps:');
    console.log('1. Refresh the page (Ctrl+F5 or Cmd+Shift+R for hard refresh)');
    console.log('2. Login with your credentials');
    console.log('3. Data will now be stored in your self-hosted Supabase\n');
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
}

// Run the cleanup
clearOldSupabaseData();
