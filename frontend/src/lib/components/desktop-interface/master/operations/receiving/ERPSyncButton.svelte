<!-- ERPSyncButton.svelte -->
<script>
  import { createEventDispatcher } from 'svelte';
  
  export let receivingRecordId;
  export let size = 'normal'; // 'small', 'normal', 'large'
  export let variant = 'primary'; // 'primary', 'secondary', 'success', 'warning'
  
  const dispatch = createEventDispatcher();
  
  let isLoading = false;
  let syncStatus = null;
  let syncError = null;
  let lastSyncResult = null;
  
  // Button size classes
  const sizeClasses = {
    small: 'px-2 py-1 text-xs',
    normal: 'px-3 py-2 text-sm',
    large: 'px-4 py-3 text-base'
  };
  
  // Button variant classes
  const variantClasses = {
    primary: 'bg-blue-600 hover:bg-blue-700 text-white',
    secondary: 'bg-gray-600 hover:bg-gray-700 text-white',
    success: 'bg-green-600 hover:bg-green-700 text-white',
    warning: 'bg-orange-600 hover:bg-orange-700 text-white'
  };
  
  // Check sync status on component mount
  async function checkSyncStatus() {
    if (!receivingRecordId) return;
    
    try {
      console.log('🔍 Checking sync status for:', receivingRecordId);
      
      const response = await fetch(`/api/receiving-records/sync-erp?receiving_record_id=${receivingRecordId}`);
      const result = await response.json();
      
      console.log('📊 Sync status result:', result);
      
      if (result.success) {
        syncStatus = result.data;
        console.log('✅ Sync status loaded:', syncStatus);
      } else {
        console.error('❌ Sync status error:', result.error);
      }
    } catch (error) {
      console.error('Error checking sync status:', error);
    }
  }
  
  // Manual sync function
  async function syncErpReference() {
    if (!receivingRecordId || isLoading) return;
    
    console.log('🔄 Starting ERP sync for:', receivingRecordId);
    
    isLoading = true;
    syncError = null;
    
    try {
      const response = await fetch('/api/receiving-records/sync-erp', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          receiving_record_id: receivingRecordId
        })
      });
      
      const result = await response.json();
      
      console.log('📤 Sync response:', result);
      
      if (result.success) {
        lastSyncResult = result.data;
        
        // Refresh sync status
        await checkSyncStatus();
        
        // Dispatch event to parent component
        dispatch('syncCompleted', {
          receivingRecordId,
          syncResult: result.data,
          message: result.message
        });
        
        console.log('✅ Sync completed successfully');
        
        // Show success message briefly
        setTimeout(() => {
          lastSyncResult = null;
        }, 3000);
      } else {
        console.error('❌ Sync failed:', result.error);
        syncError = result.error;
      }
    } catch (error) {
      console.error('Error syncing ERP reference:', error);
      syncError = 'Failed to sync ERP reference';
    } finally {
      isLoading = false;
    }
  }
  
  // Initialize on mount
  checkSyncStatus();
  
  // Reactive statement to determine button text and state
  $: buttonText = isLoading ? 'Syncing...' : 
                  lastSyncResult?.synced ? '✅ Synced' :
                  syncStatus?.sync_status === 'SYNCED' ? '✅ Synced' :
                  syncStatus?.sync_status === 'NEEDS_SYNC' ? '🔄 Sync ERP' :
                  syncStatus?.sync_status === 'LEGACY_WITH_ERP' ? '📋 Has ERP' :
                  syncStatus?.sync_status === 'LEGACY_NO_ERP' ? '📋 Legacy' :
                  syncStatus?.sync_status === 'NO_ERP_REFERENCE' ? '❌ No ERP' :
                  '🔄 Sync ERP';
  
  $: buttonDisabled = isLoading || 
                      syncStatus?.sync_status === 'NO_ERP_REFERENCE' ||
                      syncStatus?.sync_status === 'LEGACY_NO_ERP' ||
                      syncStatus?.sync_status === 'SYNCED' ||
                      syncStatus?.sync_status === 'LEGACY_WITH_ERP' ||
                      !syncStatus?.can_sync;
  
  $: buttonVariant = lastSyncResult?.synced ? 'success' :
                     syncStatus?.sync_status === 'SYNCED' ? 'success' :
                     syncStatus?.sync_status === 'LEGACY_WITH_ERP' ? 'success' :
                     syncStatus?.sync_status === 'NEEDS_SYNC' ? 'warning' :
                     variant;
</script>

<div class="flex items-center space-x-2">
  <!-- Sync Button -->
  <button
    on:click={syncErpReference}
    disabled={buttonDisabled}
    class="font-medium rounded-md transition-colors duration-200 {sizeClasses[size]} {variantClasses[buttonVariant]} disabled:opacity-50 disabled:cursor-not-allowed"
    title={syncStatus?.sync_status === 'NO_ERP_REFERENCE' ? 'No ERP reference available to sync' : 
           syncStatus?.sync_status === 'LEGACY_NO_ERP' ? 'Legacy record without ERP reference' :
           syncStatus?.sync_status === 'SYNCED' ? 'ERP reference is already synced' :
           syncStatus?.sync_status === 'LEGACY_WITH_ERP' ? 'Legacy record with existing ERP reference' :
           'Click to sync ERP reference from task completion'}
  >
    {buttonText}
  </button>
  
  <!-- Status indicator -->
  {#if syncStatus}
    <div class="flex items-center space-x-1">
      {#if syncStatus.sync_status === 'SYNCED'}
        <span class="w-2 h-2 bg-green-500 rounded-full" title="ERP reference is synced"></span>
      {:else if syncStatus.sync_status === 'LEGACY_WITH_ERP'}
        <span class="w-2 h-2 bg-purple-500 rounded-full" title="Legacy record with ERP"></span>
      {:else if syncStatus.sync_status === 'NEEDS_SYNC'}
        <span class="w-2 h-2 bg-orange-500 rounded-full" title="ERP reference needs sync"></span>
      {:else if syncStatus.sync_status === 'LEGACY_NO_ERP'}
        <span class="w-2 h-2 bg-gray-500 rounded-full" title="Legacy record without ERP"></span>
      {:else if syncStatus.sync_status === 'NO_ERP_REFERENCE'}
        <span class="w-2 h-2 bg-gray-400 rounded-full" title="No ERP reference available"></span>
      {/if}
    </div>
  {/if}
</div>

<!-- Success/Error Messages -->
{#if lastSyncResult?.message}
  <div class="mt-2 p-2 bg-green-50 border border-green-200 rounded-md">
    <p class="text-sm text-green-800">{lastSyncResult.message}</p>
    {#if lastSyncResult.erp_reference}
      <p class="text-xs text-green-600 mt-1">ERP: {lastSyncResult.erp_reference}</p>
    {/if}
  </div>
{/if}

{#if syncError}
  <div class="mt-2 p-2 bg-red-50 border border-red-200 rounded-md">
    <p class="text-sm text-red-800">{syncError}</p>
  </div>
{/if}

<!-- Detailed Status (for debugging) -->
{#if syncStatus && size === 'large'}
  <div class="mt-3 p-3 bg-gray-50 border border-gray-200 rounded-md text-xs">
    <h4 class="font-semibold text-gray-700 mb-2">Sync Status Details:</h4>
    <div class="space-y-1 text-gray-600">
      <div><strong>Current ERP:</strong> {syncStatus.current_erp_reference || 'None'}</div>
      <div><strong>Task ERP:</strong> {syncStatus.task_erp_reference || 'None'}</div>
      <div><strong>Status:</strong> {syncStatus.sync_status}</div>
      {#if syncStatus.task_completed_at}
        <div><strong>Completed:</strong> {new Date(syncStatus.task_completed_at).toLocaleString()}</div>
      {/if}
      {#if syncStatus.task_completed_by}
        <div><strong>By:</strong> {syncStatus.task_completed_by}</div>
      {/if}
    </div>
  </div>
{/if}