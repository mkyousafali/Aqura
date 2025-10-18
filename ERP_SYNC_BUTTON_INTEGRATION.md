# ERP Sync Button Integration Guide

## Overview
The ERP Sync Button provides a manual way to sync ERP references from task completions to receiving records when the automatic trigger isn't working properly.

## Files Created

### 1. Database Functions
**File**: `supabase/migrations/79_manual_erp_sync_functions.sql`
- `sync_erp_reference_for_receiving_record(uuid)` - Sync specific record
- `check_erp_sync_status_for_record(uuid)` - Check sync status
- `sync_all_pending_erp_references()` - Bulk sync all pending

### 2. API Endpoint
**File**: `frontend/src/routes/api/receiving-records/sync-erp/+server.js`
- `POST` - Trigger manual sync for specific receiving record
- `GET` - Check sync status for specific receiving record

### 3. UI Component
**File**: `frontend/src/lib/components/admin/receiving/ERPSyncButton.svelte`
- Smart sync button with status indicators
- Auto-detects sync status
- Shows real-time feedback

### 4. Example Integration
**File**: `frontend/src/lib/components/admin/receiving/ReceivingRecordsWithSync.svelte`
- Example table with sync buttons
- Shows how to handle sync events
- Includes bulk sync option

## Quick Integration

### 1. Run Database Migration
```sql
-- Copy and paste 79_manual_erp_sync_functions.sql into Supabase SQL Editor
```

### 2. Add Sync Button to Your Receiving Records View
```svelte
<script>
  import ERPSyncButton from '$lib/components/admin/receiving/ERPSyncButton.svelte';
  
  function handleSyncCompleted(event) {
    const { receivingRecordId, syncResult, message } = event.detail;
    console.log('Sync completed:', message);
    // Update your local data or refresh the view
  }
</script>

<!-- In your table or card view -->
<ERPSyncButton 
  receivingRecordId={record.id}
  size="small"
  on:syncCompleted={handleSyncCompleted}
/>
```

### 3. Add to Existing Components
You can add the sync button to any existing receiving records view:

**Where to add:**
- `StartReceiving.svelte` - After saving receiving data
- `ReceivingRecordsList.svelte` - In the actions column
- `ReceivingRecordDetails.svelte` - In the header or details section

## Button States

| State | Appearance | Description |
|-------|------------|-------------|
| `🔄 Sync ERP` | Orange warning button | ERP reference needs to be synced |
| `✅ Synced` | Green success button | ERP reference is already synced |
| `❌ No ERP` | Disabled gray button | No ERP reference available |
| `Syncing...` | Loading state | Currently processing sync |

## Usage Examples

### Basic Usage
```svelte
<ERPSyncButton receivingRecordId={record.id} />
```

### With Custom Size and Variant
```svelte
<ERPSyncButton 
  receivingRecordId={record.id}
  size="large"
  variant="warning"
  on:syncCompleted={handleSync}
/>
```

### With Event Handling
```svelte
<ERPSyncButton 
  receivingRecordId={record.id}
  on:syncCompleted={(event) => {
    if (event.detail.syncResult.synced) {
      // Update local state
      refreshReceivingRecords();
    }
  }}
/>
```

## Manual Testing

1. **Create a receiving record** with tasks
2. **Complete inventory manager task** with ERP reference
3. **Check if auto-sync worked** - if not, sync button will show "🔄 Sync ERP"
4. **Click sync button** - should update receiving record
5. **Button changes to "✅ Synced"**

## Bulk Sync Function

For administrators, you can run bulk sync:

```javascript
// Call the bulk sync API
const response = await fetch('/api/receiving-records/sync-erp', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sync_all: true })
});
```

Or directly in database:
```sql
SELECT * FROM sync_all_pending_erp_references();
```

## Troubleshooting

1. **Button shows "❌ No ERP"**: Inventory manager hasn't completed task with ERP reference
2. **Sync fails**: Check browser console and Supabase logs
3. **No sync button**: Make sure migration 79 is applied
4. **API errors**: Check that API endpoint files are in correct location

This provides a reliable manual backup when the automatic trigger system has issues!