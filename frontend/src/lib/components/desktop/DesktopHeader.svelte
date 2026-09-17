<script lang="ts">
  import { onMount } from 'svelte';
  
  let appVersion = '1.0.0';
  let isOnline = true;
  let dbStatus = 'Checking...';
  
  // Open sync status window
  function openSyncStatus() {
    if (window.electronAPI && window.electronAPI.openSyncStatusWindow) {
      window.electronAPI.openSyncStatusWindow();
    }
  }
  
  onMount(async () => {
    // Get app version from Electron
    if (window.electronAPI) {
      appVersion = await window.electronAPI.getAppVersion();
      
      // Get database status
      const status = await window.electronAPI.getDatabaseStatus();
      if (status) {
        dbStatus = status.mode || 'Cloud-Only';
      }
      
      // Monitor online/offline status
      window.addEventListener('online', () => isOnline = true);
      window.addEventListener('offline', () => isOnline = false);
      isOnline = navigator.onLine;
    }
  });
</script>

<header class="bg-gradient-to-r from-purple-600 to-blue-600 text-white shadow-lg">
  <div class="container mx-auto px-4 py-3 flex items-center justify-between">
    <!-- App Title & Version -->
    <div class="flex items-center space-x-4">
      <div class="flex items-center space-x-2">
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"/>
        </svg>
        <div>
          <h1 class="text-xl font-bold">AQURA Desktop</h1>
          <p class="text-xs text-purple-200">v{appVersion}</p>
        </div>
      </div>
      
      <!-- Read-Only Badge -->
      <span class="px-3 py-1 bg-yellow-500 text-white text-xs font-semibold rounded-full">
        READ-ONLY MODE
      </span>
      
      <!-- Sync Status Button -->
      <button
        on:click={openSyncStatus}
        class="px-3 py-1 bg-blue-500 hover:bg-blue-600 text-white text-xs font-semibold rounded-full flex items-center space-x-1 transition-colors"
        title="View sync status"
      >
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <span>Sync Status</span>
      </button>
    </div>
    
    <!-- Status Indicators -->
    <div class="flex items-center space-x-4">
      <!-- Database Status -->
      <div class="flex items-center space-x-2">
        <div class="w-2 h-2 rounded-full {dbStatus === 'Local Database' ? 'bg-green-400' : 'bg-yellow-400'}"></div>
        <span class="text-sm">{dbStatus}</span>
      </div>
      
      <!-- Online/Offline Status -->
      <div class="flex items-center space-x-2">
        {#if isOnline}
          <svg class="w-5 h-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
            <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zM8 7a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zM14 4a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z"/>
          </svg>
          <span class="text-sm">Online</span>
        {:else}
          <svg class="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M13.477 14.89A6 6 0 015.11 6.524l8.367 8.368zm1.414-1.414L6.524 5.11a6 6 0 018.367 8.367zM18 10a8 8 0 11-16 0 8 8 0 0116 0z" clip-rule="evenodd"/>
          </svg>
          <span class="text-sm">Offline</span>
        {/if}
      </div>
    </div>
  </div>
</header>
