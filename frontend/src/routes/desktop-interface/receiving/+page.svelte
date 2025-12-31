<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/utils/supabase';

  let branches = [];
  let selectedBranch = '';
  let setAsDefaultBranch = false;
  let loading = false;
  let errorMessage = '';

  onMount(async () => {
    await loadBranches();
  });

  async function loadBranches() {
    try {
      loading = true;
      errorMessage = '';

      const { data, error } = await supabase
        .from('branches')
        .select('id, name_en, name_ar, location_en')
        .eq('is_active', true)
        .order('name_en');

      if (error) throw error;
      branches = data || [];
      console.log('Loaded branches:', branches);
    } catch (err) {
      errorMessage = 'Failed to load branches: ' + err.message;
      console.error('Error loading branches:', err);
    } finally {
      loading = false;
    }
  }

  function confirmBranchSelection() {
    if (!selectedBranch) {
      alert('Please select a branch first');
      return;
    }
    
    if (setAsDefaultBranch) {
      localStorage.setItem('defaultBranch', selectedBranch);
    }
    
    // Navigate to Step 2 with selected branch
    goto(`/desktop-interface/receiving/step2?branch=${selectedBranch}`);
  }
</script>

<svelte:head>
  <title>Start Receiving - Step 1: Select Branch</title>
</svelte:head>

<div class="receiving-container">
  <div class="header">
    <h1>Start Receiving</h1>
    <div class="step-indicator">
      <div class="step active">
        <span class="step-number">1</span>
        <span class="step-text">Select Branch</span>
      </div>
      <div class="step">
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
    <h3>Step 1: Select Branch</h3>
    
    {#if loading}
      <div class="loading">
        <div class="spinner"></div>
        <span>Loading branches...</span>
      </div>
    {:else if errorMessage}
      <div class="error-message">
        <span class="error-icon">⚠️</span>
        <span>{errorMessage}</span>
      </div>
    {:else}
      <div class="branch-selection">
        <label for="branch-select">Select a branch to start receiving:</label>
        <select 
          id="branch-select"
          bind:value={selectedBranch}
          class="form-select"
        >
          <option value="">-- Select Branch --</option>
          {#each branches as branch}
            <option value={branch.id.toString()}>
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
      </div>
    {/if}
  </div>

  <!-- Step 1 Complete - Continue Button -->
  {#if selectedBranch}
    <div class="step-navigation">
      <div class="step-complete-info">
        <span class="step-complete-icon">✅</span>
        <span class="step-complete-text">Step 1 Complete: Branch Selected</span>
      </div>
      <button type="button" on:click={confirmBranchSelection} class="continue-step-btn">
        Continue to Step 2: Select Vendor →
      </button>
    </div>
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

  .step.active:not(:last-child)::after {
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

  .step.active .step-text {
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

  .loading {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 20px;
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

  .error-icon {
    font-size: 20px;
  }

  .branch-selection label {
    display: block;
    font-weight: 500;
    color: #374151;
    margin-bottom: 10px;
  }

  .form-select {
    width: 100%;
    padding: 12px;
    border: 2px solid #e5e7eb;
    border-radius: 8px;
    font-size: 16px;
    background: white;
    transition: border-color 0.2s;
  }

  .form-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .branch-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 20px;
    padding: 15px;
    background: #f8fafc;
    border-radius: 8px;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    font-weight: 500;
    color: #374151;
  }

  .checkbox-label input[type="checkbox"] {
    width: 18px;
    height: 18px;
    accent-color: #3b82f6;
  }

  .confirm-btn {
    background: #10b981;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .confirm-btn:hover {
    background: #059669;
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
