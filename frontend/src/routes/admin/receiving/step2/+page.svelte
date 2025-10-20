<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { supabase } from '$lib/utils/supabase';

  let selectedBranch = '';
  let vendors = [];
  let filteredVendors = [];
  let selectedVendor = null;
  let searchQuery = '';
  let loading = false;
  let errorMessage = '';

  // Column visibility
  let visibleColumns = {
    erp_vendor_id: true,
    vendor_name: true,
    salesman_name: true,
    vendor_contact_number: true,
    payment_method: true,
    place: true,
    categories: true,
    delivery_modes: true,
    status: true,
    actions: true
  };

  onMount(async () => {
    // Get branch from URL parameters
    selectedBranch = $page.url.searchParams.get('branch') || '';
    
    if (!selectedBranch) {
      // If no branch selected, redirect to step 1
      goto('/admin/receiving');
      return;
    }

    await loadVendors();
  });

  async function loadVendors() {
    try {
      loading = true;
      errorMessage = '';

      // Load vendors filtered by selected branch only (not unassigned vendors)
      const { data, error } = await supabase
        .from('vendors')
        .select('*')
        .eq('status', 'Active')
        .eq('branch_id', selectedBranch) // Only vendors assigned to this specific branch
        .order('vendor_name', { ascending: true })
        .limit(10000); // Increase limit to show all vendors

      if (error) throw error;
      vendors = data || [];
      filteredVendors = vendors;
      
      // If no vendors found for this branch, show message
      if (vendors.length === 0) {
        errorMessage = `No vendors found for the selected branch. Please upload vendor data for this branch first or assign existing vendors to this branch.`;
      }
      
    } catch (err) {
      errorMessage = 'Failed to load vendors: ' + err.message;
      console.error('Error loading vendors:', err);
    } finally {
      loading = false;
    }
  }

  function handleVendorSearch() {
    if (!searchQuery.trim()) {
      filteredVendors = vendors;
    } else {
      filteredVendors = vendors.filter(vendor => 
        vendor.erp_vendor_id?.toString().includes(searchQuery.toLowerCase()) ||
        vendor.vendor_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        vendor.salesman_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        vendor.place?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        vendor.categories?.some(cat => cat.toLowerCase().includes(searchQuery.toLowerCase())) ||
        vendor.delivery_modes?.some(mode => mode.toLowerCase().includes(searchQuery.toLowerCase()))
      );
    }
  }

  function selectVendor(vendor) {
    selectedVendor = vendor;
  }

  function continueToStep3() {
    if (!selectedVendor) {
      alert('Please select a vendor first');
      return;
    }
    
    // Navigate to Step 3 with branch and vendor
    goto(`/admin/receiving/step3?branch=${selectedBranch}&vendor=${selectedVendor.erp_vendor_id}`);
  }

  function backToStep1() {
    goto('/admin/receiving');
  }

  $: if (searchQuery !== undefined) {
    handleVendorSearch();
  }
</script>

<svelte:head>
  <title>Start Receiving - Step 2: Select Vendor</title>
</svelte:head>

<div class="receiving-container">
  <div class="header">
    <h1>Start Receiving</h1>
    <div class="step-indicator">
      <div class="step completed">
        <span class="step-number">✓</span>
        <span class="step-text">Select Branch</span>
      </div>
      <div class="step active">
        <span class="step-number">2</span>
        <span class="step-text">Select Vendor</span>
      </div>
      <div class="step">
        <span class="step-number">3</span>
        <span class="step-text">Bill Information</span>
      </div>
      <div class="step">
        <span class="step-number">4</span>
        <span class="step-text">Receive Items</span>
      </div>
    </div>
  </div>

  <div class="form-section">
    <h3>Step 2: Select Vendor</h3>
    
    {#if selectedVendor}
      <div class="current-selection">
        <div class="selection-info">
          <span class="label">Selected Vendor:</span>
          <span class="value">{selectedVendor.vendor_name}</span>
          <span class="vendor-id">({selectedVendor.erp_vendor_id})</span>
        </div>
        <button type="button" on:click={() => selectedVendor = null} class="change-btn">
          Change Vendor
        </button>
      </div>
    {:else}
      <!-- Search Bar -->
      <div class="vendor-search">
        <div class="search-input-wrapper">
          <span class="search-icon">🔍</span>
          <input 
            type="text" 
            placeholder="Search by ERP ID, vendor name, salesman, place, categories, delivery modes..."
            bind:value={searchQuery}
            class="search-input"
          />
          {#if searchQuery}
            <button class="clear-search" on:click={() => searchQuery = ''}>×</button>
          {/if}
        </div>
        <div class="search-results-info">
          Showing {filteredVendors.length} of {vendors.length} vendors
        </div>
      </div>

      <!-- Vendor Table -->
      {#if loading}
        <div class="loading">
          <div class="spinner"></div>
          <span>Loading vendors...</span>
        </div>
      {:else if errorMessage}
        <div class="error-message">
          <span class="error-icon">⚠️</span>
          <span>{errorMessage}</span>
        </div>
      {:else if filteredVendors.length === 0}
        <div class="no-vendors">
          <span>No vendors found matching your search</span>
        </div>
      {:else}
        <div class="vendors-table-container">
          <table class="vendors-table">
            <thead>
              <tr>
                {#if visibleColumns.erp_vendor_id}<th>ERP Vendor ID</th>{/if}
                {#if visibleColumns.vendor_name}<th>Vendor Name</th>{/if}
                {#if visibleColumns.salesman_name}<th>Salesman Name</th>{/if}
                {#if visibleColumns.vendor_contact_number}<th>Contact</th>{/if}
                {#if visibleColumns.payment_method}<th>Payment Method</th>{/if}
                {#if visibleColumns.place}<th>Place</th>{/if}
                {#if visibleColumns.categories}<th>Categories</th>{/if}
                {#if visibleColumns.delivery_modes}<th>Delivery Modes</th>{/if}
                {#if visibleColumns.status}<th>Status</th>{/if}
                {#if visibleColumns.actions}<th>Actions</th>{/if}
              </tr>
            </thead>
            <tbody>
              {#each filteredVendors as vendor}
                <tr class="vendor-row">
                  {#if visibleColumns.erp_vendor_id}
                    <td class="vendor-id">{vendor.erp_vendor_id}</td>
                  {/if}
                  {#if visibleColumns.vendor_name}
                    <td class="vendor-name">{vendor.vendor_name || 'N/A'}</td>
                  {/if}
                  {#if visibleColumns.salesman_name}
                    <td class="salesman">{vendor.salesman_name || 'N/A'}</td>
                  {/if}
                  {#if visibleColumns.vendor_contact_number}
                    <td class="contact">{vendor.vendor_contact_number || 'N/A'}</td>
                  {/if}
                  {#if visibleColumns.payment_method}
                    <td class="payment-method">{vendor.payment_method || 'N/A'}</td>
                  {/if}
                  {#if visibleColumns.place}
                    <td class="place">{vendor.place || 'No place'}</td>
                  {/if}
                  {#if visibleColumns.categories}
                    <td class="categories">
                      {#if vendor.categories && vendor.categories.length > 0}
                        {vendor.categories.join(', ')}
                      {:else}
                        No categories
                      {/if}
                    </td>
                  {/if}
                  {#if visibleColumns.delivery_modes}
                    <td class="delivery-modes">
                      {#if vendor.delivery_modes && vendor.delivery_modes.length > 0}
                        {vendor.delivery_modes.join(', ')}
                      {:else}
                        No delivery modes
                      {/if}
                    </td>
                  {/if}
                  {#if visibleColumns.status}
                    <td class="status">
                      <span class="status-badge active">{vendor.status}</span>
                    </td>
                  {/if}
                  {#if visibleColumns.actions}
                    <td class="actions">
                      <button class="select-btn" on:click={() => selectVendor(vendor)}>
                        Select
                      </button>
                    </td>
                  {/if}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    {/if}
  </div>

  <!-- Step Navigation -->
  <div class="step-navigation">
    <div class="navigation-buttons">
      <button type="button" on:click={backToStep1} class="back-step-btn">
        ← Back to Step 1: Select Branch
      </button>
      
      {#if selectedVendor}
        <div class="step-complete-info">
          <span class="step-complete-icon">✅</span>
          <span class="step-complete-text">Step 2 Complete: Vendor Selected</span>
        </div>
        <button type="button" on:click={continueToStep3} class="continue-step-btn">
          Continue to Step 3: Bill Information →
        </button>
      {:else}
        <button type="button" disabled class="continue-step-btn disabled">
          Select a Vendor to Continue
        </button>
      {/if}
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

  .step.active:not(:last-child)::after,
  .step.completed:not(:last-child)::after {
    background: #3b82f6;
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
    margin-bottom: 20px;
  }

  .current-selection {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: #f0f9ff;
    padding: 20px;
    border-radius: 8px;
    border-left: 4px solid #3b82f6;
    margin-bottom: 20px;
  }

  .selection-info {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .label {
    font-weight: 500;
    color: #374151;
  }

  .value {
    font-weight: 600;
    color: #1f2937;
  }

  .vendor-id {
    color: #6b7280;
    font-size: 14px;
  }

  .change-btn {
    background: #f59e0b;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    font-weight: 500;
    transition: background-color 0.2s;
  }

  .change-btn:hover {
    background: #d97706;
  }

  .vendor-search {
    margin-bottom: 20px;
  }

  .search-input-wrapper {
    position: relative;
    margin-bottom: 10px;
  }

  .search-icon {
    position: absolute;
    left: 12px;
    top: 50%;
    transform: translateY(-50%);
    color: #9ca3af;
  }

  .search-input {
    width: 100%;
    padding: 12px 40px 12px 40px;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
    transition: border-color 0.2s;
  }

  .search-input:focus {
    outline: none;
    border-color: #3b82f6;
  }

  .clear-search {
    position: absolute;
    right: 12px;
    top: 50%;
    transform: translateY(-50%);
    background: none;
    border: none;
    font-size: 18px;
    cursor: pointer;
    color: #9ca3af;
  }

  .search-results-info {
    font-size: 14px;
    color: #6b7280;
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

  .vendors-table-container {
    overflow-x: auto;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
  }

  .vendors-table {
    width: 100%;
    border-collapse: collapse;
    background: white;
  }

  .vendors-table th {
    background: #f9fafb;
    padding: 12px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 1px solid #e5e7eb;
  }

  .vendors-table td {
    padding: 12px;
    border-bottom: 1px solid #f3f4f6;
  }

  .vendor-row:hover {
    background: #f9fafb;
  }

  .status-badge {
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
  }

  .status-badge.active {
    background: #dcfce7;
    color: #166534;
  }

  .select-btn {
    background: #3b82f6;
    color: white;
    border: none;
    padding: 6px 12px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    transition: background-color 0.2s;
  }

  .select-btn:hover {
    background: #2563eb;
  }

  .step-navigation {
    display: flex;
    flex-direction: column;
    align-items: center;
    margin: 30px 0;
    padding: 20px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .navigation-buttons {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 15px;
    width: 100%;
  }

  .back-step-btn {
    background: #6b7280;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: all 0.3s ease;
    align-self: flex-start;
  }

  .back-step-btn:hover {
    background: #4b5563;
  }

  .step-complete-info {
    display: flex;
    align-items: center;
    gap: 10px;
    color: #2e7d32;
    font-weight: 600;
    font-size: 16px;
    padding: 10px;
    background: linear-gradient(135deg, #e8f5e8 0%, #f0f8f0 100%);
    border: 2px solid #4caf50;
    border-radius: 8px;
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

  .continue-step-btn.disabled {
    background: #e0e0e0;
    color: #9e9e9e;
    cursor: not-allowed;
    transform: none;
    box-shadow: none;
  }

  .continue-step-btn.disabled:hover {
    background: #e0e0e0;
    transform: none;
    box-shadow: none;
  }
</style>