
<script lang="ts">
  import StepIndicator from './StepIndicator.svelte';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { supabase } from '$lib/utils/supabase';
  import { onMount } from 'svelte';
  
  let steps = ['Select Branch', 'Select Vendor', 'Receive Items', 'Review & Submit'];
  let currentStep = 0;
  
  // Branch selection state
  let branches = [];
  let selectedBranch = '';
  let selectedBranchName = '';
  let showBranchSelector = true;
  let setAsDefaultBranch = false;
  let isLoading = false;
  let errorMessage = '';

  // Vendor selection state
  let vendors = [];
  let filteredVendors = [];
  let searchQuery = '';
  let selectedVendor = null;
  let vendorLoading = false;
  let vendorError = '';

  onMount(async () => {
    await loadBranches();
    // Check if user has a default branch
    if ($currentUser?.branch_id) {
      selectedBranch = $currentUser.branch_id;
      selectedBranchName = $currentUser.branchName || '';
      showBranchSelector = false;
      currentStep = 1; // Move to vendor selection
      await loadVendors();
    }
  });

  async function loadBranches() {
    try {
      isLoading = true;
      errorMessage = '';

      const { data, error } = await supabase
        .from('branches')
        .select('id, name_en, name_ar, location_en')
        .eq('is_active', true)
        .order('name_en');

      if (error) throw error;
      branches = data || [];
    } catch (err) {
      errorMessage = 'Failed to load branches: ' + err.message;
      console.error('Error loading branches:', err);
    } finally {
      isLoading = false;
    }
  }

  async function loadVendors() {
    try {
      vendorLoading = true;
      vendorError = '';

      const { data, error } = await supabase
        .from('vendors')
        .select('*')
        .eq('status', 'Active')
        .order('vendor_name', { ascending: true });

      if (error) throw error;
      vendors = data || [];
      filteredVendors = vendors;
    } catch (err) {
      vendorError = 'Failed to load vendors: ' + err.message;
      console.error('Error loading vendors:', err);
    } finally {
      vendorLoading = false;
    }
  }

  // Vendor search functionality
  function handleVendorSearch() {
    if (!searchQuery.trim()) {
      filteredVendors = vendors;
    } else {
      const query = searchQuery.toLowerCase();
      filteredVendors = vendors.filter(vendor => 
        vendor.erp_vendor_id.toString().includes(query) ||
        vendor.vendor_name.toLowerCase().includes(query) ||
        (vendor.salesman_name && vendor.salesman_name.toLowerCase().includes(query)) ||
        (vendor.place && vendor.place.toLowerCase().includes(query)) ||
        (vendor.categories && vendor.categories.some(cat => cat.toLowerCase().includes(query)))
      );
    }
  }

  // Reactive search
  $: if (searchQuery !== undefined) {
    handleVendorSearch();
  }

  async function handleBranchChange(event) {
    selectedBranch = event.target.value;
    const branch = branches.find(b => b.id == selectedBranch);
    selectedBranchName = branch ? branch.name_en : '';
  }

  function confirmBranchSelection() {
    if (selectedBranch) {
      showBranchSelector = false;
      currentStep = 1; // Move to next step
      
      // Load vendors for step 2
      loadVendors();
      
      // TODO: Save as default if checkbox is checked
      if (setAsDefaultBranch) {
        console.log('Would save branch as default:', selectedBranch);
      }
    }
  }

  function changeBranch() {
    showBranchSelector = true;
    currentStep = 0; // Go back to branch selection
    selectedVendor = null; // Clear vendor selection
  }

  function selectVendor(vendor) {
    selectedVendor = vendor;
    currentStep = 2; // Move to next step
  }

  function changeVendor() {
    selectedVendor = null;
    currentStep = 1; // Go back to vendor selection
  }
</script>
<StepIndicator {steps} {currentStep} />

<!-- Current User Section -->
<div class="user-info-section">
  <h2>Start Receiving Process</h2>
  {#if $currentUser}
    <p class="user-greeting">
      Welcome, <strong>{$currentUser.employeeName || $currentUser.username}</strong>
      {#if $currentUser.branchName}
        <span class="branch-info">({$currentUser.branchName})</span>
      {/if}
    </p>
  {:else}
    <p class="user-greeting">Welcome to the Receiving Process</p>
  {/if}
</div>

<!-- Branch Selection Section -->
<div class="form-section">
  <h3>Step 1: Select Branch</h3>
  
  {#if selectedBranch && !showBranchSelector}
    <div class="current-selection">
      <div class="selection-info">
        <span class="label">Selected Branch:</span>
        <span class="value">{selectedBranchName}</span>
      </div>
      <button type="button" on:click={changeBranch} class="change-btn">
        Change Branch
      </button>
    </div>
  {:else}
    <div class="branch-selector">
      {#if isLoading}
        <div class="loading-state">
          <div class="spinner"></div>
          <span>Loading branches...</span>
        </div>
      {:else if errorMessage}
        <div class="error-state">
          <p>{errorMessage}</p>
          <button on:click={loadBranches} class="retry-btn">Retry</button>
        </div>
      {:else}
        <label for="branch-select" class="form-label">Choose Branch:</label>
        <select 
          id="branch-select" 
          bind:value={selectedBranch} 
          on:change={handleBranchChange}
          class="form-select"
        >
          <option value="">-- Select Branch --</option>
          {#each branches as branch}
            <option value={branch.id}>
              {branch.name_en}
              {#if branch.location_en} - {branch.location_en}{/if}
            </option>
          {/each}
        </select>
        
        {#if selectedBranch}
          <div class="branch-actions">
            <label class="checkbox-label">
              <input type="checkbox" bind:checked={setAsDefaultBranch} />
              <span class="checkmark"></span>
              Set as default branch
            </label>
            <button type="button" on:click={confirmBranchSelection} class="confirm-btn">
              ✓ Confirm Branch
            </button>
          </div>
        {/if}
      {/if}
    </div>
  {/if}
</div>

<!-- Vendor Selection Section -->
{#if currentStep >= 1 && selectedBranch && !showBranchSelector}
  <div class="form-section">
    <h3>Step 2: Select Vendor</h3>
    
    {#if selectedVendor}
      <div class="current-selection">
        <div class="selection-info">
          <span class="label">Selected Vendor:</span>
          <span class="value">{selectedVendor.vendor_name}</span>
          <span class="vendor-id">({selectedVendor.erp_vendor_id})</span>
        </div>
        <button type="button" on:click={changeVendor} class="change-btn">
          Change Vendor
        </button>
      </div>
    {:else}
      <div class="vendor-selector">
        <!-- Search Bar -->
        <div class="vendor-search">
          <div class="search-input-wrapper">
            <span class="search-icon">🔍</span>
            <input 
              type="text" 
              placeholder="Search by ERP ID, vendor name, salesman, place, or category..."
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

        {#if vendorLoading}
          <div class="loading-state">
            <div class="spinner"></div>
            <span>Loading vendors...</span>
          </div>
        {:else if vendorError}
          <div class="error-state">
            <p>{vendorError}</p>
            <button on:click={loadVendors} class="retry-btn">Retry</button>
          </div>
        {:else if filteredVendors.length === 0}
          <div class="empty-state">
            {#if searchQuery}
              <span class="empty-icon">🔍</span>
              <h4>No vendors found</h4>
              <p>No vendors match your search criteria</p>
              <button class="clear-search-btn" on:click={() => searchQuery = ''}>Clear Search</button>
            {:else}
              <span class="empty-icon">📝</span>
              <h4>No vendors available</h4>
              <p>No active vendors found</p>
            {/if}
          </div>
        {:else}
          <!-- Vendor Table -->
          <div class="vendor-table">
            <table>
              <thead>
                <tr>
                  <th>ERP ID</th>
                  <th>Vendor Name</th>
                  <th>Salesman</th>
                  <th>Contact</th>
                  <th>Place</th>
                  <th>Categories</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredVendors as vendor}
                  <tr>
                    <td class="vendor-id">{vendor.erp_vendor_id}</td>
                    <td class="vendor-name">{vendor.vendor_name}</td>
                    <td class="vendor-data">
                      {#if vendor.salesman_name}
                        {vendor.salesman_name}
                      {:else}
                        <span class="no-data">No salesman</span>
                      {/if}
                    </td>
                    <td class="vendor-data">
                      {#if vendor.vendor_contact_number}
                        {vendor.vendor_contact_number}
                      {:else}
                        <span class="no-data">No contact</span>
                      {/if}
                    </td>
                    <td class="vendor-data">
                      {#if vendor.place}
                        📍 {vendor.place}
                      {:else}
                        <span class="no-data">No place</span>
                      {/if}
                    </td>
                    <td class="vendor-categories">
                      {#if vendor.categories && vendor.categories.length > 0}
                        <div class="category-badges">
                          {#each vendor.categories.slice(0, 2) as category}
                            <span class="category-badge">{category}</span>
                          {/each}
                          {#if vendor.categories.length > 2}
                            <span class="category-badge more">+{vendor.categories.length - 2}</span>
                          {/if}
                        </div>
                      {:else}
                        <span class="no-data">No categories</span>
                      {/if}
                    </td>
                    <td class="action-cell">
                      <button class="select-btn" on:click={() => selectVendor(vendor)}>
                        Select
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  </div>
{/if}

<!-- More StartReceiving content will be added here -->

<style>
	.user-info-section {
		margin-bottom: 2rem;
		padding: 1rem;
		background: #f8f9fa;
		border-radius: 8px;
		border-left: 4px solid #1976d2;
	}
	
	.user-info-section h2 {
		margin: 0 0 0.5rem 0;
		color: #1976d2;
		font-size: 1.5rem;
		font-weight: 600;
	}
	
	.user-greeting {
		margin: 0;
		color: #333;
		font-size: 1rem;
	}
	
	.user-greeting strong {
		color: #1976d2;
	}
	
	.branch-info {
		color: #666;
		font-style: italic;
		margin-left: 0.5rem;
	}

	.form-section {
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: #fff;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.form-section h3 {
		margin: 0 0 1rem 0;
		color: #333;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.current-selection {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		background: #e8f5e8;
		border-radius: 6px;
		border: 1px solid #4caf50;
	}

	.selection-info .label {
		color: #666;
		margin-right: 0.5rem;
	}

	.selection-info .value {
		font-weight: 600;
		color: #333;
	}

	.change-btn {
		padding: 0.5rem 1rem;
		background: #1976d2;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.9rem;
	}

	.change-btn:hover {
		background: #1565c0;
	}

	.branch-selector {
		max-width: 500px;
	}

	.form-label {
		display: block;
		margin-bottom: 0.5rem;
		color: #333;
		font-weight: 500;
	}

	.form-select {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 1rem;
		margin-bottom: 1rem;
	}

	.form-select:focus {
		outline: none;
		border-color: #1976d2;
		box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.2);
	}

	.branch-actions {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		cursor: pointer;
		color: #333;
	}

	.checkbox-label input[type="checkbox"] {
		margin-right: 0.5rem;
	}

	.confirm-btn {
		align-self: flex-start;
		padding: 0.75rem 1.5rem;
		background: #4caf50;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 1rem;
		font-weight: 500;
	}

	.confirm-btn:hover {
		background: #45a049;
	}

	.loading-state, .error-state {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		color: #666;
	}

	.spinner {
		width: 20px;
		height: 20px;
		border: 2px solid #f3f3f3;
		border-top: 2px solid #1976d2;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.retry-btn {
		padding: 0.5rem 1rem;
		background: #ff9800;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		margin-left: 1rem;
	}

	.retry-btn:hover {
		background: #e68900;
	}

	/* Vendor Selector Styles */
	.vendor-selector {
		max-width: 100%;
	}

	.vendor-search {
		margin-bottom: 1.5rem;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-icon {
		position: absolute;
		left: 1rem;
		color: #666;
		font-size: 1.1rem;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 0.75rem 0.75rem 3rem;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 1rem;
	}

	.search-input:focus {
		outline: none;
		border-color: #1976d2;
		box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.2);
	}

	.clear-search {
		position: absolute;
		right: 0.75rem;
		background: none;
		border: none;
		font-size: 1.2rem;
		cursor: pointer;
		color: #666;
		padding: 0.25rem;
	}

	.clear-search:hover {
		color: #333;
	}

	.search-results-info {
		margin-top: 0.5rem;
		color: #666;
		font-size: 0.9rem;
	}

	.empty-state {
		text-align: center;
		padding: 3rem 1rem;
		color: #666;
	}

	.empty-icon {
		font-size: 3rem;
		display: block;
		margin-bottom: 1rem;
	}

	.empty-state h4 {
		margin: 0 0 0.5rem 0;
		color: #333;
	}

	.empty-state p {
		margin: 0 0 1rem 0;
	}

	.clear-search-btn {
		padding: 0.5rem 1rem;
		background: #1976d2;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}

	.clear-search-btn:hover {
		background: #1565c0;
	}

	/* Vendor Table Styles */
	.vendor-table {
		background: white;
		border-radius: 8px;
		overflow: hidden;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.vendor-table table {
		width: 100%;
		border-collapse: collapse;
	}

	.vendor-table th {
		background: #f8f9fa;
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 1px solid #e9ecef;
	}

	.vendor-table td {
		padding: 1rem;
		border-bottom: 1px solid #e9ecef;
		vertical-align: top;
	}

	.vendor-table tbody tr:hover {
		background: #f8f9fa;
	}

	.vendor-id {
		font-weight: 600;
		color: #1976d2;
	}

	.vendor-name {
		font-weight: 600;
		color: #333;
	}

	.vendor-data {
		color: #666;
	}

	.no-data {
		color: #999;
		font-style: italic;
	}

	.category-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
	}

	.category-badge {
		background: #e3f2fd;
		color: #1976d2;
		padding: 0.25rem 0.5rem;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.category-badge.more {
		background: #f5f5f5;
		color: #666;
	}

	.select-btn {
		background: #4caf50;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		cursor: pointer;
		font-weight: 500;
	}

	.select-btn:hover {
		background: #45a049;
	}

	.selection-info .vendor-id {
		color: #666;
		font-weight: normal;
		margin-left: 0.5rem;
	}
</style>