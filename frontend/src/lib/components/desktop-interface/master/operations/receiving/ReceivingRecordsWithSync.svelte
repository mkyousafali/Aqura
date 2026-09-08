<!-- Example usage of ERPSyncButton in receiving records -->
<script>
  import ERPSyncButton from './ERPSyncButton.svelte';
  
  // Example receiving records data
  let receivingRecords = [
    {
      id: 'dd002fee-5e2f-49f0-828d-8b9e9e2907b4',
      bill_number: 'BILL-001',
      vendor_name: 'ABC Vendor',
      bill_amount: 1500.00,
      erp_purchase_invoice_reference: null,
      created_at: '2025-10-18T10:30:00Z'
    },
    {
      id: '52636abe-4205-4818-8f85-39114727e469',
      bill_number: 'BILL-002', 
      vendor_name: 'XYZ Supplier',
      bill_amount: 2300.00,
      erp_purchase_invoice_reference: '25123',
      created_at: '2025-10-18T11:15:00Z'
    }
  ];
  
  // Handle sync completion event
  function handleSyncCompleted(event) {
    const { receivingRecordId, syncResult, message } = event.detail;
    
    console.log('ERP sync completed:', { receivingRecordId, syncResult, message });
    
    // Update the local record with the new ERP reference
    if (syncResult.synced && syncResult.erp_reference) {
      const recordIndex = receivingRecords.findIndex(r => r.id === receivingRecordId);
      if (recordIndex !== -1) {
        receivingRecords[recordIndex].erp_purchase_invoice_reference = syncResult.erp_reference;
        receivingRecords = [...receivingRecords]; // Trigger reactivity
      }
    }
    
    // Show notification or toast message
    alert(message);
  }
</script>

<div class="p-6">
  <h2 class="text-2xl font-bold text-gray-900 mb-6">Receiving Records with ERP Sync</h2>
  
  <!-- Receiving Records Table -->
  <div class="overflow-x-auto">
    <table class="min-w-full bg-white border border-gray-200 rounded-lg shadow">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            Bill Number
          </th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            Vendor
          </th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            Amount
          </th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            ERP Reference
          </th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            ERP Sync
          </th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            Created
          </th>
        </tr>
      </thead>
      <tbody class="bg-white divide-y divide-gray-200">
        {#each receivingRecords as record}
          <tr class="hover:bg-gray-50">
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
              {record.bill_number}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {record.vendor_name}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              ${record.bill_amount.toFixed(2)}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {#if record.erp_purchase_invoice_reference}
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  {record.erp_purchase_invoice_reference}
                </span>
              {:else}
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-500">
                  Not set
                </span>
              {/if}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              <!-- ERP Sync Button -->
              <ERPSyncButton 
                receivingRecordId={record.id}
                size="small"
                variant="primary"
                on:syncCompleted={handleSyncCompleted}
              />
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {new Date(record.created_at).toLocaleDateString()}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
  
  <!-- Bulk Sync Button -->
  <div class="mt-6 flex justify-between items-center">
    <div class="text-sm text-gray-500">
      {receivingRecords.length} receiving records
    </div>
    
    <button 
      class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md font-medium transition-colors"
      on:click={() => {
        // Implement bulk sync functionality
        alert('Bulk ERP sync feature - coming soon!');
      }}
    >
      🔄 Sync All Pending ERP References
    </button>
  </div>
  
  <!-- Usage Instructions -->
  <div class="mt-8 p-4 bg-blue-50 border border-blue-200 rounded-lg">
    <h3 class="text-lg font-semibold text-blue-900 mb-2">ERP Sync Instructions</h3>
    <div class="text-sm text-blue-800 space-y-1">
      <p>• <strong>🔄 Sync ERP</strong>: Manual sync available when task completion has ERP reference</p>
      <p>• <strong>✅ Synced</strong>: ERP reference is already synced from task completion</p>
      <p>• <strong>❌ No ERP</strong>: No ERP reference found in completed tasks</p>
      <p>• <strong>Status Dots</strong>: 🟢 Synced, 🟠 Needs Sync, ⚪ No ERP</p>
    </div>
  </div>
</div>