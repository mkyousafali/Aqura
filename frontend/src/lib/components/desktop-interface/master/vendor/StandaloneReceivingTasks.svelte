<!-- StandaloneReceivingTasks.svelte -->
<!-- Standalone Receiving Tasks system (separate from the existing Receiving Task Templates / auto-task system). -->
<!-- Built and tested independently before it replaces anything. -->
<script lang="ts">
  import { locale } from '$lib/i18n';

  $: isRTL = $locale === 'ar';

  // Standalone task list — plain, independent tasks (no templates, no position linkage yet)
  const tasks = [
    'Placing and Price Tag Verification',
    'Placing Product',
    'Price Tag Placing',
    'Original Bill Received',
    'Original Bill Uploading',
    'PR Excel Uploading',
    'PR Excel Verification',
    'Entering to ERP',
    'ERP Entry Verification',
    'Warehouse Placing',
    'Expiry Dates Updating',
    'On Delivery Payment Mark',
    'On Delivery Payment ERP Reference Update',
    'VAT Number and Name Verification'
  ];
</script>

<div class="srt-container" dir={isRTL ? 'rtl' : 'ltr'}>
  <div class="srt-table-wrap">
    <table class="srt-table">
      <thead>
        <tr>
          <th class="srt-num-col">#</th>
          <th>Task</th>
        </tr>
      </thead>
      <tbody>
        {#each tasks as task, i}
          <tr>
            <td class="srt-num-col">{i + 1}</td>
            <td>{task}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .srt-container {
    flex: 1;
    height: 100%;
    overflow-y: auto;
    padding: 1rem;
    background: linear-gradient(135deg, #e8f0fe 0%, #f0f7ff 50%, #e8f4f8 100%);
  }

  .srt-table-wrap {
    background: rgba(255, 255, 255, 0.75);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(59, 130, 246, 0.06);
  }

  .srt-table {
    width: 100%;
    border-collapse: collapse;
  }

  .srt-table thead th {
    text-align: left;
    padding: 0.7rem 1rem;
    background: rgba(241, 245, 249, 0.9);
    border-bottom: 1px solid #e2e8f0;
    font-weight: 700;
    font-size: 0.88rem;
    color: #1e293b;
  }
  [dir='rtl'] .srt-table thead th { text-align: right; }

  .srt-table tbody td {
    padding: 0.6rem 1rem;
    border-bottom: 1px solid #f1f5f9;
    font-size: 0.86rem;
    color: #334155;
  }

  .srt-table tbody tr:last-child td { border-bottom: none; }
  .srt-table tbody tr:hover { background: rgba(59, 130, 246, 0.04); }

  .srt-num-col {
    width: 3rem;
    text-align: center;
    color: #94a3b8;
  }
</style>
