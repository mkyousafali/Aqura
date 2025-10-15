<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/utils/supabase';

  let selectedBranch = '';
  let selectedVendorId = '';
  let selectedVendor = null;
  let billDate = '';
  let billAmount = '';
  let billNumber = '';
  let currentDateTime = '';
  let loading = false;
  let errorMessage = '';

  onMount(async () => {
    // Get parameters from URL
    selectedBranch = $page.url.searchParams.get('branch') || '';
    selectedVendorId = $page.url.searchParams.get('vendor') || '';
    
    if (!selectedBranch || !selectedVendorId) {
      // If missing parameters, redirect to appropriate step
      if (!selectedBranch) {
        goto('/admin/receiving');
      } else {
        goto(`/admin/receiving/step2?branch=${selectedBranch}`);
      }
      return;
    }

    await loadVendor();
    setCurrentDateTime();
  });

  async function loadVendor() {
    try {
      loading = true;
      const { data, error } = await supabase
        .from('vendors')
        .select('*')
        .eq('erp_vendor_id', selectedVendorId)
        .single();

      if (error) throw error;
      selectedVendor = data;
    } catch (err) {
      errorMessage = 'Failed to load vendor: ' + err.message;
      console.error('Error loading vendor:', err);
    } finally {
      loading = false;
    }
  }

  function setCurrentDateTime() {
    const now = new Date();
    currentDateTime = now.toLocaleString('en-US', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    });
    
    // Set bill date to today
    billDate = now.toISOString().split('T')[0];
  }

  function continueToStep4() {
    if (!billDate || !billAmount) {
      alert('Please fill in all required fields (Date and Bill Amount)');
      return;
    }
    
    // Navigate to Step 4 with all parameters
    const params = new URLSearchParams({
      branch: selectedBranch,
      vendor: selectedVendorId,
      billDate,
      billAmount,
      billNumber: billNumber || ''
    });
    
    goto(`/admin/receiving/step4?${params.toString()}`);
  }

  function calculateFinalAmount() {
    const amount = parseFloat(billAmount) || 0;
    return amount.toFixed(2);
  }
</script>

<svelte:head>
  <title>Start Receiving - Step 3: Bill Information</title>
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
      <div class="step active">
        <span class="step-number">3</span>
        <span class="step-text">Bill Information</span>
      </div>
      <div class="step">
        <span class="step-number">4</span>
        <span class="step-text">Receive Items</span>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="loading">
      <div class="spinner"></div>
      <span>Loading vendor information...</span>
    </div>
  {:else if errorMessage}
    <div class="error-message">
      <span class="error-icon">⚠️</span>
      <span>{errorMessage}</span>
    </div>
  {:else if selectedVendor}
    <div class="form-section">
      <h3>Step 3: Bill Information</h3>
      <p class="step-description">Review current date and enter bill details</p>
      
      <!-- Selected Vendor Info -->
      <div class="vendor-info">
        <h4>Selected Vendor</h4>
        <div class="vendor-details">
          <span class="vendor-name">{selectedVendor.vendor_name}</span>
          <span class="vendor-id">ERP ID: {selectedVendor.erp_vendor_id}</span>
        </div>
      </div>

      <div class="bill-info-grid">
        <div class="date-field">
          <label>Current Date & Time:</label>
          <input 
            type="text" 
            value={currentDateTime} 
            readonly 
            class="readonly-input"
          />
        </div>

        <div class="bill-date-field">
          <label for="bill-date">Bill Date: <span class="required">*</span></label>
          <input 
            type="date" 
            id="bill-date"
            bind:value={billDate}
            class="form-input"
            required
          />
        </div>

        <div class="bill-amount-field">
          <label for="bill-amount">Bill Amount: <span class="required">*</span></label>
          <div class="amount-input-wrapper">
            <span class="currency">SAR</span>
            <input 
              type="number" 
              id="bill-amount"
              bind:value={billAmount}
              step="0.01"
              min="0"
              placeholder="0.00"
              class="form-input amount-input"
              required
            />
          </div>
        </div>

        <div class="bill-number-field">
          <label for="bill-number">Bill Number:</label>
          <input 
            type="text" 
            id="bill-number"
            bind:value={billNumber}
            placeholder="Enter bill number (optional)"
            class="form-input"
          />
        </div>

        {#if billAmount}
          <div class="amount-summary">
            <h4>Amount Summary</h4>
            <div class="summary-row">
              <span class="summary-label">Bill Amount:</span>
              <span class="summary-value">SAR {calculateFinalAmount()}</span>
            </div>
            <div class="summary-row total">
              <span class="summary-label">Total Amount:</span>
              <span class="summary-value">SAR {calculateFinalAmount()}</span>
            </div>
          </div>
        {/if}
      </div>

      <!-- Payment Information -->
      {#if selectedVendor.payment_method}
        <div class="payment-info">
          <h4>Vendor Payment Information</h4>
          <div class="payment-details">
            <div class="payment-method">
              <span class="label">Payment Method:</span>
              <span class="value">{selectedVendor.payment_method}</span>
            </div>
            {#if selectedVendor.credit_period}
              <div class="credit-period">
                <span class="label">Credit Period:</span>
                <span class="value">{selectedVendor.credit_period} days</span>
              </div>
            {/if}
            {#if selectedVendor.bank_name}
              <div class="bank-name">
                <span class="label">Bank:</span>
                <span class="value">{selectedVendor.bank_name}</span>
              </div>
            {/if}
          </div>
        </div>
      {/if}

      <!-- VAT Information -->
      {#if selectedVendor.vat_number}
        <div class="vat-info">
          <h4>VAT Information</h4>
          <div class="vat-details">
            <span class="label">Vendor VAT Number:</span>
            <span class="value">{selectedVendor.vat_number}</span>
          </div>
        </div>
      {/if}
    </div>

    <!-- Step 3 Complete - Continue Button -->
    {#if billDate && billAmount}
      <div class="step-navigation">
        <div class="step-complete-info">
          <span class="step-complete-icon">✅</span>
          <span class="step-complete-text">Step 3 Complete: Bill Information Entered</span>
        </div>
        <button type="button" on:click={continueToStep4} class="continue-step-btn">
          Continue to Step 4: Receive Items →
        </button>
      </div>
    {/if}
  {/if}
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

  .step.active:not(:last-child)::after,
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
    margin-bottom: 20px;
  }

  .vendor-info {
    background: #f0f9ff;
    padding: 20px;
    border-radius: 8px;
    border-left: 4px solid #3b82f6;
    margin-bottom: 30px;
  }

  .vendor-info h4 {
    margin: 0 0 10px 0;
    color: #1e40af;
    font-weight: 600;
  }

  .vendor-details {
    display: flex;
    align-items: center;
    gap: 15px;
  }

  .vendor-name {
    font-size: 18px;
    font-weight: 600;
    color: #1f2937;
  }

  .vendor-id {
    color: #6b7280;
    font-size: 14px;
  }

  .bill-info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
    margin-bottom: 30px;
  }

  .bill-info-grid label {
    display: block;
    font-weight: 500;
    color: #374151;
    margin-bottom: 8px;
  }

  .required {
    color: #dc2626;
  }

  .form-input {
    width: 100%;
    padding: 12px;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 16px;
    transition: border-color 0.2s;
  }

  .form-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .readonly-input {
    background: #f9fafb;
    color: #6b7280;
    cursor: not-allowed;
  }

  .amount-input-wrapper {
    position: relative;
  }

  .currency {
    position: absolute;
    left: 12px;
    top: 50%;
    transform: translateY(-50%);
    color: #6b7280;
    font-weight: 500;
  }

  .amount-input {
    padding-left: 50px;
  }

  .amount-summary {
    grid-column: 1 / -1;
    background: #f9fafb;
    padding: 20px;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
  }

  .amount-summary h4 {
    margin: 0 0 15px 0;
    color: #1f2937;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 0;
    border-bottom: 1px solid #e5e7eb;
  }

  .summary-row.total {
    border-bottom: none;
    font-weight: 600;
    font-size: 18px;
    color: #1f2937;
    border-top: 2px solid #3b82f6;
    padding-top: 15px;
    margin-top: 10px;
  }

  .summary-label {
    color: #6b7280;
  }

  .summary-value {
    color: #1f2937;
    font-weight: 500;
  }

  .payment-info,
  .vat-info {
    background: #f8fafc;
    padding: 20px;
    border-radius: 8px;
    border: 1px solid #e2e8f0;
    margin-bottom: 20px;
  }

  .payment-info h4,
  .vat-info h4 {
    margin: 0 0 15px 0;
    color: #1f2937;
  }

  .payment-details {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
  }

  .payment-details > div,
  .vat-details {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .payment-details .label,
  .vat-details .label {
    font-weight: 500;
    color: #6b7280;
    font-size: 14px;
  }

  .payment-details .value,
  .vat-details .value {
    font-weight: 600;
    color: #1f2937;
  }

  .loading {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 40px;
    justify-content: center;
    color: #64748b;
  }

  .spinner {
    width: 20px;
    height: 20px;
    border: 2px solid #e2e8f0;
    border-top: 2px solid #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .error-message {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 15px;
    background: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 8px;
    color: #dc2626;
  }

  .step-navigation {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 15px;
    margin: 30px 0;
    padding: 20px;
    background: linear-gradient(135deg, #e8f5e8 0%, #f0f8f0 100%);
    border: 2px solid #4caf50;
    border-radius: 12px;
  }

  .step-complete-info {
    display: flex;
    align-items: center;
    gap: 10px;
    color: #2e7d32;
    font-weight: 600;
    font-size: 16px;
  }

  .step-complete-icon {
    font-size: 20px;
  }

  .continue-step-btn {
    background: linear-gradient(135deg, #4caf50 0%, #66bb6a 100%);
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 8px;
    cursor: pointer;
    font-size: 16px;
    font-weight: 600;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(76, 175, 80, 0.3);
  }

  .continue-step-btn:hover {
    background: linear-gradient(135deg, #388e3c 0%, #4caf50 100%);
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(76, 175, 80, 0.4);
  }
</style>