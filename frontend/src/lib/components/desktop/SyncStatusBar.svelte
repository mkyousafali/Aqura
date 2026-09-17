<script lang="ts">
  import { onMount } from 'svelte';
  
  let syncStatus: any = null;
  let isSyncing = false;
  let lastSyncTime: Date | null = null;
  let syncProgress = 0;
  let syncPhase = '';
  let syncMessage = '';
  let currentTable = '';
  let currentBucket = '';
  let currentFile = '';
  let tableProgress = { current: 0, total: 0 };
  
  onMount(async () => {
    if (!window.electronAPI) return;
    
    // Get initial sync status
    syncStatus = await window.electronAPI.getSyncStatus();
    if (syncStatus?.lastSync) {
      lastSyncTime = new Date(syncStatus.lastSync);
    }
    
    // Listen for sync events
    window.electronAPI.onSyncStart((data: any) => {
      console.log('🔄 Sync started:', data);
      isSyncing = true;
      syncProgress = 0;
      syncPhase = 'Starting...';
      syncMessage = '';
      currentTable = '';
      currentBucket = '';
      currentFile = '';
      tableProgress = { current: 0, total: 0 };
    });
    
    window.electronAPI.onSyncProgress((data: any) => {
      console.log('📊 Sync progress:', data);
      syncProgress = data.progress || 0;
      syncPhase = data.phase || '';
      syncMessage = data.message || '';
      currentTable = data.table || '';
      currentBucket = data.bucket || '';
      currentFile = data.file || '';
      if (data.current && data.total) {
        tableProgress = { current: data.current, total: data.total };
      }
    });
    
    window.electronAPI.onSyncComplete(async (data: any) => {
      console.log('✅ Sync complete:', data);
      isSyncing = false;
      syncProgress = 100;
      lastSyncTime = new Date();
      syncMessage = '';
      currentTable = '';
      
      // Refresh status
      syncStatus = await window.electronAPI.getSyncStatus();
    });
    
    window.electronAPI.onSyncError((error: any) => {
      isSyncing = false;
      syncMessage = '';
      currentTable = '';
      console.error('Sync error:', error);
    });
  });
  
  async function handleManualSync() {
    if (isSyncing) return;
    
    try {
      await window.electronAPI.triggerSync();
    } catch (error) {
      console.error('Failed to trigger sync:', error);
    }
  }
  
  function formatTimeAgo(date: Date | null): string {
    if (!date) return 'Never';
    
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
    
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  }
</script>

<div class="bg-white border-b border-gray-200 shadow-sm">
  <div class="container mx-auto px-4 py-2">
    <div class="flex items-center justify-between">
      <!-- Sync Status -->
      <div class="flex items-center space-x-4">
        {#if isSyncing}
          <div class="flex items-center space-x-2">
            <svg class="animate-spin h-5 w-5 text-purple-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <div class="flex flex-col">
              <span class="text-sm font-medium text-purple-600">
                {#if syncMessage}
                  {syncMessage}
                {:else if currentBucket}
                  Syncing {currentBucket} bucket... ({tableProgress.current}/{tableProgress.total} files)
                {:else if tableProgress.total > 0}
                  Syncing {currentTable || 'tables'}... ({tableProgress.current}/{tableProgress.total})
                {:else}
                  Syncing {syncPhase}... {syncProgress}%
                {/if}
              </span>
              {#if tableProgress.total > 0 || syncProgress > 0}
                <span class="text-xs text-gray-500">
                  {Math.round(syncProgress)}% complete
                  {#if syncPhase === 'database'}
                    - Database tables
                  {:else if syncPhase === 'storage'}
                    - Storage files
                  {/if}
                </span>
              {/if}
            </div>
          </div>
          
          <!-- Progress Bar -->
          <div class="w-48 h-2 bg-gray-200 rounded-full overflow-hidden">
            <div 
              class="h-full bg-gradient-to-r from-purple-500 to-blue-500 transition-all duration-300"
              style="width: {syncProgress}%"
            ></div>
          </div>
        {:else}
          <div class="flex items-center space-x-2">
            <svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            <span class="text-sm text-gray-600">
              Last sync: {formatTimeAgo(lastSyncTime)}
            </span>
          </div>
        {/if}
        
        {#if syncStatus}
          <span class="text-xs text-gray-500">
            Next sync in {Math.ceil((syncStatus.nextSync || 900000) / 60000)}m
          </span>
        {/if}
      </div>
      
      <!-- Sync Button -->
      <button
        on:click={handleManualSync}
        disabled={isSyncing}
        class="px-4 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center space-x-2"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
        <span>{isSyncing ? 'Syncing...' : 'Sync Now'}</span>
      </button>
    </div>
  </div>
</div>
