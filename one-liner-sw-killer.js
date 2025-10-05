// COPY AND PASTE THIS ONE-LINER INTO BROWSER CONSOLE (F12)
// This will instantly stop all service workers and clear everything

navigator.serviceWorker.getRegistrations().then(regs => Promise.all(regs.map(reg => reg.unregister()))).then(() => caches.keys()).then(names => Promise.all(names.map(name => caches.delete(name)))).then(() => {localStorage.clear(); sessionStorage.clear(); console.log('🎉 ALL SERVICE WORKERS DESTROYED!'); location.reload();})