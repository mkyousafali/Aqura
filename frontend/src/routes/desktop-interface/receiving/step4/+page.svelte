<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';

  let selectedBranch = '';
  let selectedVendorId = '';
  let billDate = '';
  let billAmount = '';
  let billNumber = '';

  onMount(() => {
    // Get parameters from URL
    selectedBranch = $page.url.searchParams.get('branch') || '';
    selectedVendorId = $page.url.searchParams.get('vendor') || '';
    billDate = $page.url.searchParams.get('billDate') || '';
    billAmount = $page.url.searchParams.get('billAmount') || '';
    billNumber = $page.url.searchParams.get('billNumber') || '';
    
    if (!selectedBranch || !selectedVendorId || !billDate || !billAmount) {
      // If missing required parameters, redirect to step 1
      goto('/desktop-interface/receiving');
      return;
    }
  });

  function completeReceiving() {
    alert('Receiving process completed! (This is a placeholder)');
    // TODO: Implement actual receiving completion logic
    goto('/desktop-interface/receiving');
  }

  function backToStep3() {
    const params = new URLSearchParams({
      branch: selectedBranch,
      vendor: selectedVendorId
    });
    goto(`/desktop-interface/receiving/step3?${params.toString()}`);
  }
</script>

<svelte:head>
  <title>Start Receiving - Step 4: Receive Items</title>
</svelte:head>

<div class="receiving-container">
  <div class="header">
    <h1>Start Receiving</h1>
    <div class="step-indicator">
      <div class="step completed">
        <span class="step-number">✓</span>
        <span class="step-text">Select Branch</span>
      </div>
      <div class="step completed">
        <span class="step-number">✓</span>
        <span class="step-text">Select Vendor</span>
      </div>
      <div class="step completed">
        <span class="step-number">✓</span>
        <span class="step-text">Bill Information</span>
      </div>
      <div class="step active">
        <span class="step-number">4</span>
        <span class="step-text">Receive Items</span>
      </div>
    </div>
  </div>

  <div class="form-section">
    <h3>Step 4: Receive Items</h3>
    <p class="step-description">Process the physical receiving of items and complete the workflow</p>
    
    <!-- Summary Information -->
    <div class="summary-info">
      <h4>Receiving Summary</h4>
      <div class="summary-grid">
        <div class="summary-item">
          <span class="label">Branch ID:</span>
          <span class="value">{selectedBranch}</span>
        </div>
        <div class="summary-item">
          <span class="label">Vendor ID:</span>
          <span class="value">{selectedVendorId}</span>
        </div>
        <div class="summary-item">
          <span class="label">Bill Date:</span>
          <span class="value">{billDate}</span>
        </div>
        <div class="summary-item">
          <span class="label">Bill Amount:</span>
          <span class="value">SAR {billAmount}</span>
        </div>
        {#if billNumber}
          <div class="summary-item">
            <span class="label">Bill Number:</span>
            <span class="value">{billNumber}</span>
          </div>
        {/if}
      </div>
    </div>

    <!-- Placeholder Content -->
    <div class="placeholder-content">
      <div class="placeholder-icon">📦</div>
      <h4>Receive Items Interface</h4>
      <p>This is where the item receiving interface will be implemented.</p>
      <p>Features to be added:</p>
      <ul>
        <li>Item scanning or manual entry</li>
        <li>Quantity verification</li>
        <li>Quality inspection</li>
        <li>Storage location assignment</li>
        <li>Digital signature capture</li>
        <li>Photo documentation</li>
      </ul>
    </div>

    <div class="action-buttons">
      <button type="button" class="back-btn" on:click={backToStep3}>
        ← Back to Step 3: Bill Information
      </button>
      <button type="button" class="complete-btn" on:click={completeReceiving}>
        Complete Receiving Process ✓
      </button>
    </div>
  </div>
</div>

<style>
  .receiving-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
  }

  .header {
    margin-bottom: 30px;
  }

  .header h1 {
    font-size: 2rem;
    font-weight: 600;
    color: #1a202c;
    margin-bottom: 20px;
  }

  .step-indicator {
    display: flex;
    justify-content: space-between;
    margin-bottom: 20px;
    background: white;
    padding: 20px;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .step {
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 1;
    position: relative;
  }

  .step:not(:last-child)::after {
    content: '';
    position: absolute;
    top: 15px;
    right: -50%;
    width: 100%;
    height: 2px;
    background: #e2e8f0;
    z-index: 1;
  }

  .step.active .step-number {
    background: #3b82f6;
    color: white;
  }

  .step.completed .step-number {
    background: #10b981;
    color: white;
  }

  .step.completed:not(:last-child)::after {
    background: #10b981;
  }

  .step-number {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    background: #e2e8f0;
    color: #64748b;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 14px;
    margin-bottom: 8px;
    position: relative;
    z-index: 2;
  }

  .step-text {
    font-size: 12px;
    color: #64748b;
    text-align: center;
  }

  .step.active .step-text,
  .step.completed .step-text {
    color: #3b82f6;
    font-weight: 600;
  }

  .form-section {
    background: white;
    padding: 30px;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    margin-bottom: 20px;
  }

  .form-section h3 {
    font-size: 1.5rem;
    font-weight: 600;
    color: #1a202c;
    margin-bottom: 10px;
  }

  .step-description {
    color: #6b7280;
    margin-bottom: 30px;
  }

  .summary-info {
    background: #f0f9ff;
    padding: 20px;
    border-radius: 8px;
    border-left: 4px solid #3b82f6;
    margin-bottom: 30px;
  }

  .summary-info h4 {
    margin: 0 0 15px 0;
    color: #1e40af;
    font-weight: 600;
  }

  .summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
  }

  .summary-item {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .summary-item .label {
    font-weight: 500;
    color: #6b7280;
    font-size: 14px;
  }

  .summary-item .value {
    font-weight: 600;
    color: #1f2937;
  }

  .placeholder-content {
    text-align: center;
    padding: 40px;
    background: #f9fafb;
    border-radius: 8px;
    border: 2px dashed #d1d5db;
    margin-bottom: 30px;
  }

  .placeholder-icon {
    font-size: 3rem;
    margin-bottom: 20px;
  }

  .placeholder-content h4 {
    color: #1f2937;
    margin-bottom: 10px;
  }

  .placeholder-content p {
    color: #6b7280;
    margin-bottom: 20px;
  }

  .placeholder-content ul {
    text-align: left;
    max-width: 400px;
    margin: 0 auto;
    color: #6b7280;
  }

  .placeholder-content li {
    margin-bottom: 8px;
  }

  .action-buttons {
    display: flex;
    justify-content: space-between;
    gap: 20px;
  }

  .back-btn {
    background: #6b7280;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 16px;
    font-weight: 500;
    transition: background-color 0.2s;
  }

  .back-btn:hover {
    background: #4b5563;
  }

  .complete-btn {
    background: linear-gradient(135deg, #059669 0%, #10b981 100%);
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 16px;
    font-weight: 600;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }

  .complete-btn:hover {
    background: linear-gradient(135deg, #047857 0%, #059669 100%);
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
  }
</style>
