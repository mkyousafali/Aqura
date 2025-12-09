<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { currentUser } from '$lib/utils/persistentAuth';

  // State for each card
  let branches = [];
  let selectedBranch = null;
  let branchSearchQuery = '';
  let filteredBranches = [];

  let purchasingManagers = [];
  let selectedPurchasingManager = null;
  let pmSearchQuery = '';
  let filteredPMs = [];

  let branchManagers = [];
  let selectedBranchManager = null;
  let bmSearchQuery = '';
  let filteredBMs = [];

  let inventoryManagers = [];
  let selectedInventoryManager = null;
  let imSearchQuery = '';
  let filteredIMs = [];

  let nightSupervisors = [];
  let selectedNightSupervisors = [];
  let nsSearchQuery = '';
  let filteredNSs = [];

  let accountants = [];
  let selectedAccountant = null;
  let accSearchQuery = '';
  let filteredAccs = [];

  let warehouseHandlers = [];
  let selectedWarehouseHandler = null;
  let whSearchQuery = '';
  let filteredWHs = [];

  let shelfStockers = [];
  let selectedShelfStocker = null;
  let ssSearchQuery = '';
  let filteredSSs = [];

  let vendors = [];
  let selectedVendor = null;
  let vendorSearchQuery = '';
  let filteredVendors = [];
  let vendorPage = 0;
  let vendorPageSize = 50;
  let hasMoreVendors = false;
  let totalVendorCount = 0;

  // Bill information section
  let showBillInformation = false;
  let currentDateTime = '';
  let billDate = '';
  let billAmount = '';
  let billNumber = '';
  let paymentMethod = '';
  let creditPeriod = '';
  let bankName = '';
  let iban = '';
  let dueDate = '';
  
  // VAT verification
  let vendorVatNumber = '';
  let billVatNumber = '';
  let vatMismatchReason = '';
  
  // Returns
  let returns = {
    expired: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
    nearExpiry: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
    overStock: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' },
    damage: { hasReturn: 'no', amount: '', erpDocumentType: '', erpDocumentNumber: '', vendorDocumentNumber: '' }
  };

  // Loading states
  let isLoadingBranches = false;
  let isLoadingPMs = false;
  let isLoadingBMs = false;
  let isLoadingIMs = false;
  let isLoadingNSs = false;
  let isLoadingAccs = false;
  let isLoadingWHs = false;
  let isLoadingSSs = false;
  let isLoadingVendors = false;

  // Load branches on mount
  onMount(async () => {
    await loadBranches();
  });

  // 1. Load Branches
  async function loadBranches() {
    isLoadingBranches = true;
    try {
      const { data, error } = await supabase
        .from('branches')
        .select('*')
        .order('name_en');
      
      if (error) throw error;
      branches = data || [];
      filteredBranches = branches;
    } catch (error) {
      console.error('Error loading branches:', error);
    } finally {
      isLoadingBranches = false;
    }
  }

  // 2. Load Purchasing Managers (after branch selected)
  async function loadPurchasingManagers() {
    if (!selectedBranch) return;
    
    isLoadingPMs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      purchasingManagers = allUsers.filter(u => 
        u.position.toLowerCase().includes('purchasing') && 
        u.position.toLowerCase().includes('manager')
      );
      filteredPMs = purchasingManagers;
    } catch (error) {
      console.error('Error loading purchasing managers:', error);
    } finally {
      isLoadingPMs = false;
    }
  }

  // 3. Load Branch Managers (after purchasing manager selected)
  async function loadBranchManagers() {
    if (!selectedPurchasingManager || !selectedBranch) return;
    
    isLoadingBMs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            branch_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('branch_id', selectedBranch.id)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      branchManagers = allUsers.filter(u => 
        u.position.toLowerCase().includes('branch') && 
        u.position.toLowerCase().includes('manager')
      );
      filteredBMs = branchManagers;
    } catch (error) {
      console.error('Error loading branch managers:', error);
    } finally {
      isLoadingBMs = false;
    }
  }

  // 4. Load Inventory Managers (after branch manager selected)
  async function loadInventoryManagers() {
    if (!selectedBranchManager || !selectedBranch) return;
    
    isLoadingIMs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            branch_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('branch_id', selectedBranch.id)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      inventoryManagers = allUsers.filter(u => 
        u.position.toLowerCase().includes('inventory') && 
        u.position.toLowerCase().includes('manager')
      );
      filteredIMs = inventoryManagers;
    } catch (error) {
      console.error('Error loading inventory managers:', error);
    } finally {
      isLoadingIMs = false;
    }
  }

  // 5. Load Night Supervisors (after inventory manager selected)
  async function loadNightSupervisors() {
    if (!selectedInventoryManager || !selectedBranch) return;
    
    isLoadingNSs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            branch_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('branch_id', selectedBranch.id)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      nightSupervisors = allUsers.filter(u => 
        u.position.toLowerCase().includes('night') && 
        u.position.toLowerCase().includes('supervisor')
      );
      filteredNSs = nightSupervisors;
    } catch (error) {
      console.error('Error loading night supervisors:', error);
    } finally {
      isLoadingNSs = false;
    }
  }

  // 6. Load Accountants (after night supervisor selected)
  async function loadAccountants() {
    if (selectedNightSupervisors.length === 0 || !selectedBranch) return;
    
    isLoadingAccs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            branch_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('branch_id', selectedBranch.id)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      accountants = allUsers.filter(u => 
        u.position.toLowerCase().includes('accountant')
      );
      filteredAccs = accountants;
    } catch (error) {
      console.error('Error loading accountants:', error);
    } finally {
      isLoadingAccs = false;
    }
  }

  // 7. Load Warehouse Handlers (after accountant selected)
  async function loadWarehouseHandlers() {
    if (!selectedAccountant || !selectedBranch) return;
    
    isLoadingWHs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            branch_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('branch_id', selectedBranch.id)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      warehouseHandlers = allUsers.filter(u => 
        u.position.toLowerCase().includes('warehouse') || 
        u.position.toLowerCase().includes('stock handler')
      );
      filteredWHs = warehouseHandlers;
    } catch (error) {
      console.error('Error loading warehouse handlers:', error);
    } finally {
      isLoadingWHs = false;
    }
  }

  // 8. Load Shelf Stockers (after warehouse handler selected)
  async function loadShelfStockers() {
    if (!selectedWarehouseHandler || !selectedBranch) return;
    
    isLoadingSSs = true;
    try {
      const { data, error } = await supabase
        .from('users')
        .select(`
          id,
          username,
          hr_employees!inner(
            id,
            name,
            employee_id,
            branch_id,
            hr_position_assignments!inner(
              is_current,
              hr_positions(
                position_title_en,
                position_title_ar
              )
            )
          )
        `)
        .eq('branch_id', selectedBranch.id)
        .eq('status', 'active')
        .eq('hr_employees.hr_position_assignments.is_current', true)
        .order('username');
      
      if (error) throw error;
      
      const allUsers = (data || []).map(user => {
        const positions = user.hr_employees?.hr_position_assignments || [];
        const position = positions[0]?.hr_positions?.position_title_en || '';
        return {
          id: user.id,
          username: user.username,
          full_name: user.hr_employees?.name || 'N/A',
          employee_id: user.hr_employees?.employee_id || 'N/A',
          position: position
        };
      });
      
      shelfStockers = allUsers.filter(u => 
        u.position.toLowerCase().includes('shelf') && 
        u.position.toLowerCase().includes('stocker')
      );
      filteredSSs = shelfStockers;
    } catch (error) {
      console.error('Error loading shelf stockers:', error);
    } finally {
      isLoadingSSs = false;
    }
  }

  // 9. Load Vendors (after shelf stocker selected) - Optimized with pagination
  async function loadVendors(append = false) {
    if (!selectedShelfStocker || !selectedBranch) return;
    
    isLoadingVendors = true;
    try {
      const from = append ? vendorPage * vendorPageSize : 0;
      const to = from + vendorPageSize - 1;
      
      // Parallel queries for count and data
      const [countResult, dataResult] = await Promise.all([
        !append ? supabase
          .from('vendors')
          .select('*', { count: 'exact', head: true })
          .eq('status', 'Active') : Promise.resolve({ count: totalVendorCount }),
        supabase
          .from('vendors')
          .select('erp_vendor_id, vendor_name, salesman_name, vendor_contact_number, payment_method, categories, status, vat_applicable, vat_number')
          .eq('status', 'Active')
          .order('vendor_name')
          .range(from, to)
      ]);
      
      if (dataResult.error) throw dataResult.error;
      
      if (!append) {
        totalVendorCount = countResult.count || 0;
        vendors = dataResult.data || [];
        vendorPage = 0;
      } else {
        vendors = [...vendors, ...(dataResult.data || [])];
      }
      
      hasMoreVendors = vendors.length < totalVendorCount;
      filteredVendors = vendors;
    } catch (error) {
      console.error('Error loading vendors:', error);
    } finally {
      isLoadingVendors = false;
    }
  }
  
  // Load more vendors
  function loadMoreVendors() {
    vendorPage++;
    loadVendors(true);
  }

  // Search handlers
  $: filteredBranches = branches.filter(b => 
    b.name_en?.toLowerCase().includes(branchSearchQuery.toLowerCase()) ||
    b.name_ar?.toLowerCase().includes(branchSearchQuery.toLowerCase())
  );

  $: filteredPMs = purchasingManagers.filter(pm => 
    pm.full_name?.toLowerCase().includes(pmSearchQuery.toLowerCase()) ||
    pm.username?.toLowerCase().includes(pmSearchQuery.toLowerCase())
  );

  $: filteredBMs = branchManagers.filter(bm => 
    bm.full_name?.toLowerCase().includes(bmSearchQuery.toLowerCase()) ||
    bm.username?.toLowerCase().includes(bmSearchQuery.toLowerCase())
  );

  $: filteredIMs = inventoryManagers.filter(im => 
    im.full_name?.toLowerCase().includes(imSearchQuery.toLowerCase()) ||
    im.username?.toLowerCase().includes(imSearchQuery.toLowerCase())
  );

  $: filteredNSs = nightSupervisors.filter(ns => 
    ns.full_name?.toLowerCase().includes(nsSearchQuery.toLowerCase()) ||
    ns.username?.toLowerCase().includes(nsSearchQuery.toLowerCase())
  );

  $: filteredAccs = accountants.filter(acc => 
    acc.full_name?.toLowerCase().includes(accSearchQuery.toLowerCase()) ||
    acc.username?.toLowerCase().includes(accSearchQuery.toLowerCase())
  );

  $: filteredWHs = warehouseHandlers.filter(wh => 
    wh.full_name?.toLowerCase().includes(whSearchQuery.toLowerCase()) ||
    wh.username?.toLowerCase().includes(whSearchQuery.toLowerCase())
  );

  $: filteredSSs = shelfStockers.filter(ss => 
    ss.full_name?.toLowerCase().includes(ssSearchQuery.toLowerCase()) ||
    ss.username?.toLowerCase().includes(ssSearchQuery.toLowerCase())
  );

  $: filteredVendors = vendors.filter(v => 
    v.vendor_name?.toLowerCase().includes(vendorSearchQuery.toLowerCase()) ||
    String(v.erp_vendor_id || '').toLowerCase().includes(vendorSearchQuery.toLowerCase())
  );

  // Selection handlers with cascading loads
  function selectBranch(branch) {
    selectedBranch = branch;
    loadPurchasingManagers();
  }

  function selectPurchasingManager(pm) {
    selectedPurchasingManager = pm;
    loadBranchManagers();
  }

  function selectBranchManager(bm) {
    selectedBranchManager = bm;
    loadInventoryManagers();
  }

  function selectInventoryManager(im) {
    selectedInventoryManager = im;
    loadNightSupervisors();
  }

  function toggleNightSupervisor(ns) {
    const index = selectedNightSupervisors.findIndex(s => s.id === ns.id);
    if (index > -1) {
      selectedNightSupervisors = selectedNightSupervisors.filter(s => s.id !== ns.id);
    } else {
      selectedNightSupervisors = [...selectedNightSupervisors, ns];
    }
    
    if (selectedNightSupervisors.length > 0) {
      loadAccountants();
    }
  }

  function selectAccountant(acc) {
    selectedAccountant = acc;
    loadWarehouseHandlers();
  }

  function selectWarehouseHandler(wh) {
    selectedWarehouseHandler = wh;
    loadShelfStockers();
  }

  function selectShelfStocker(ss) {
    selectedShelfStocker = ss;
    loadVendors();
  }

  function selectVendor(vendor) {
    selectedVendor = vendor;
  }
  
  // Proceed to bill information
  function proceedToBillInformation() {
    showBillInformation = true;
    updateCurrentDateTime();
    const interval = setInterval(updateCurrentDateTime, 1000);
  }
  
  function updateCurrentDateTime() {
    const now = new Date();
    const options = { 
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
      hour12: false
    };
    currentDateTime = now.toLocaleString('en-GB', options);
  }
  
  function backToVendorSelection() {
    showBillInformation = false;
  }
  
  // Calculate due date based on payment method
  $: {
    if (paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery') {
      const now = new Date();
      dueDate = now.toISOString().split('T')[0];
    } else if ((paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit') && billDate && creditPeriod) {
      const bill = new Date(billDate);
      bill.setDate(bill.getDate() + parseInt(creditPeriod));
      dueDate = bill.toISOString().split('T')[0];
    } else {
      dueDate = '';
    }
  }
  
  // Mask VAT number function
  function maskVatNumber(vatNumber) {
    if (!vatNumber || vatNumber.length < 4) return vatNumber;
    const lastFour = vatNumber.slice(-4);
    const masked = '*'.repeat(vatNumber.length - 4);
    return masked + lastFour;
  }
  
  // Check VAT match
  $: vatNumbersMatch = vendorVatNumber && billVatNumber ? 
    vendorVatNumber === billVatNumber : null;
  
  // Set vendor VAT number when vendor selected
  $: if (selectedVendor) {
    vendorVatNumber = selectedVendor.vat_number || '';
  }
</script>

<div class="container">
  <div class="header">
    <h2>Start Receiving Process</h2>
    {#if $currentUser}
      <p class="user-info">Receiving User: <strong>{$currentUser.full_name}</strong></p>
    {/if}
  </div>

  {#if !showBillInformation}
  <div class="cards-grid">
    <!-- Card 1: Choose Branch -->
    <div class="card" class:completed={selectedBranch}>
      <div class="card-header">
        <h3>1. Choose Branch</h3>
        {#if selectedBranch}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if selectedBranch}
          <div class="selected-item">
            <strong>{selectedBranch.name_en}</strong>
            <button class="change-btn" on:click={() => selectedBranch = null}>Change</button>
          </div>
        {:else if isLoadingBranches}
          <p class="loading">Loading branches...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search branches..." 
            bind:value={branchSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredBranches as branch}
              <div class="list-item" on:click={() => selectBranch(branch)}>
                {branch.name_en}
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 2: Choose Purchasing Manager -->
    <div class="card" class:disabled={!selectedBranch} class:completed={selectedPurchasingManager}>
      <div class="card-header">
        <h3>2. Purchasing Manager</h3>
        {#if selectedPurchasingManager}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedBranch}
          <p class="disabled-text">Select branch first</p>
        {:else if selectedPurchasingManager}
          <div class="selected-item">
            <strong>{selectedPurchasingManager.full_name}</strong>
            <p class="subtitle">{selectedPurchasingManager.username}</p>
            <button class="change-btn" on:click={() => selectedPurchasingManager = null}>Change</button>
          </div>
        {:else if isLoadingPMs}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={pmSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredPMs as pm}
              <div class="list-item" on:click={() => selectPurchasingManager(pm)}>
                <strong>{pm.full_name}</strong>
                <span class="subtitle">{pm.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 3: Choose Branch Manager -->
    <div class="card" class:disabled={!selectedPurchasingManager} class:completed={selectedBranchManager}>
      <div class="card-header">
        <h3>3. Branch Manager</h3>
        {#if selectedBranchManager}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedPurchasingManager}
          <p class="disabled-text">Select purchasing manager first</p>
        {:else if selectedBranchManager}
          <div class="selected-item">
            <strong>{selectedBranchManager.full_name}</strong>
            <p class="subtitle">{selectedBranchManager.username}</p>
            <button class="change-btn" on:click={() => selectedBranchManager = null}>Change</button>
          </div>
        {:else if isLoadingBMs}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={bmSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredBMs as bm}
              <div class="list-item" on:click={() => selectBranchManager(bm)}>
                <strong>{bm.full_name}</strong>
                <span class="subtitle">{bm.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 4: Inventory Manager -->
    <div class="card" class:disabled={!selectedBranchManager} class:completed={selectedInventoryManager}>
      <div class="card-header">
        <h3>4. Inventory Manager</h3>
        {#if selectedInventoryManager}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedBranchManager}
          <p class="disabled-text">Select branch manager first</p>
        {:else if selectedInventoryManager}
          <div class="selected-item">
            <strong>{selectedInventoryManager.full_name}</strong>
            <p class="subtitle">{selectedInventoryManager.username}</p>
            <button class="change-btn" on:click={() => selectedInventoryManager = null}>Change</button>
          </div>
        {:else if isLoadingIMs}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={imSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredIMs as im}
              <div class="list-item" on:click={() => selectInventoryManager(im)}>
                <strong>{im.full_name}</strong>
                <span class="subtitle">{im.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 5: Night Supervisor (Multiple) -->
    <div class="card" class:disabled={!selectedInventoryManager} class:completed={selectedNightSupervisors.length > 0}>
      <div class="card-header">
        <h3>5. Night Supervisor</h3>
        {#if selectedNightSupervisors.length > 0}
          <span class="checkmark">✓ {selectedNightSupervisors.length}</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedInventoryManager}
          <p class="disabled-text">Select inventory manager first</p>
        {:else if isLoadingNSs}
          <p class="loading">Loading...</p>
        {:else}
          {#if selectedNightSupervisors.length > 0}
            <div class="selected-items-list">
              {#each selectedNightSupervisors as ns}
                <div class="selected-badge">
                  {ns.full_name}
                  <button class="remove-btn" on:click={() => toggleNightSupervisor(ns)}>×</button>
                </div>
              {/each}
            </div>
          {/if}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={nsSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredNSs as ns}
              <div 
                class="list-item" 
                class:selected={selectedNightSupervisors.some(s => s.id === ns.id)}
                on:click={() => toggleNightSupervisor(ns)}
              >
                <strong>{ns.full_name}</strong>
                <span class="subtitle">{ns.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 6: Accountant -->
    <div class="card" class:disabled={selectedNightSupervisors.length === 0} class:completed={selectedAccountant}>
      <div class="card-header">
        <h3>6. Accountant</h3>
        {#if selectedAccountant}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if selectedNightSupervisors.length === 0}
          <p class="disabled-text">Select night supervisor first</p>
        {:else if selectedAccountant}
          <div class="selected-item">
            <strong>{selectedAccountant.full_name}</strong>
            <p class="subtitle">{selectedAccountant.username}</p>
            <button class="change-btn" on:click={() => selectedAccountant = null}>Change</button>
          </div>
        {:else if isLoadingAccs}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={accSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredAccs as acc}
              <div class="list-item" on:click={() => selectAccountant(acc)}>
                <strong>{acc.full_name}</strong>
                <span class="subtitle">{acc.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 7: Warehouse Handler -->
    <div class="card" class:disabled={!selectedAccountant} class:completed={selectedWarehouseHandler}>
      <div class="card-header">
        <h3>7. Warehouse Handler</h3>
        {#if selectedWarehouseHandler}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedAccountant}
          <p class="disabled-text">Select accountant first</p>
        {:else if selectedWarehouseHandler}
          <div class="selected-item">
            <strong>{selectedWarehouseHandler.full_name}</strong>
            <p class="subtitle">{selectedWarehouseHandler.username}</p>
            <button class="change-btn" on:click={() => selectedWarehouseHandler = null}>Change</button>
          </div>
        {:else if isLoadingWHs}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={whSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredWHs as wh}
              <div class="list-item" on:click={() => selectWarehouseHandler(wh)}>
                <strong>{wh.full_name}</strong>
                <span class="subtitle">{wh.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 8: Shelf Stocker -->
    <div class="card" class:disabled={!selectedWarehouseHandler} class:completed={selectedShelfStocker}>
      <div class="card-header">
        <h3>8. Shelf Stocker</h3>
        {#if selectedShelfStocker}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedWarehouseHandler}
          <p class="disabled-text">Select warehouse handler first</p>
        {:else if selectedShelfStocker}
          <div class="selected-item">
            <strong>{selectedShelfStocker.full_name}</strong>
            <p class="subtitle">{selectedShelfStocker.username}</p>
            <button class="change-btn" on:click={() => selectedShelfStocker = null}>Change</button>
          </div>
        {:else if isLoadingSSs}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search..." 
            bind:value={ssSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredSSs as ss}
              <div class="list-item" on:click={() => selectShelfStocker(ss)}>
                <strong>{ss.full_name}</strong>
                <span class="subtitle">{ss.username}</span>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Card 9: Choose Vendor -->
    <div class="card" class:disabled={!selectedShelfStocker} class:completed={selectedVendor}>
      <div class="card-header">
        <h3>9. Choose Vendor</h3>
        {#if selectedVendor}
          <span class="checkmark">✓</span>
        {/if}
      </div>
      <div class="card-body">
        {#if !selectedShelfStocker}
          <p class="disabled-text">Select shelf stocker first</p>
        {:else if selectedVendor}
          <div class="selected-item">
            <strong>{selectedVendor.vendor_name}</strong>
            <p class="subtitle">ID: {selectedVendor.erp_vendor_id}</p>
            <button class="change-btn" on:click={() => selectedVendor = null}>Change</button>
          </div>
        {:else if isLoadingVendors}
          <p class="loading">Loading...</p>
        {:else}
          <input 
            type="text" 
            placeholder="Search vendors..." 
            bind:value={vendorSearchQuery}
            class="search-input"
          />
          <div class="list">
            {#each filteredVendors as vendor}
              <div class="list-item" on:click={() => selectVendor(vendor)}>
                <strong>{vendor.vendor_name}</strong>
                <span class="subtitle">ID: {vendor.erp_vendor_id}</span>
              </div>
            {/each}
            {#if hasMoreVendors && !vendorSearchQuery}
              <button class="load-more-btn" on:click={loadMoreVendors} disabled={isLoadingVendors}>
                {isLoadingVendors ? 'Loading...' : `Load More (${totalVendorCount - vendors.length} remaining)`}
              </button>
            {/if}
          </div>
        {/if}
      </div>
    </div>
  </div>

  <!-- Standalone Next Button -->
  {#if selectedVendor}
    <div class="next-button-container">
      <div class="summary-info">
        <p><strong>Branch:</strong> {selectedBranch?.name_en}</p>
        <p><strong>Vendor:</strong> {selectedVendor?.vendor_name}</p>
        <p><strong>All staff selected</strong></p>
      </div>
      <button class="next-btn" on:click={proceedToBillInformation}>
        Next: Bill Information →
      </button>
      <p class="info-text">Proceed to enter bill details and complete receiving</p>
    </div>
  {/if}
  {/if}

<!-- Bill Information Full Page Section -->
{#if showBillInformation}
  <div class="bill-info-page">
    <button class="back-btn" on:click={backToVendorSelection}>← Back to Selection</button>
    
    <div class="bill-info-content">
      <div class="info-section">
        <h3>Selected Details</h3>
        <div class="info-grid">
          <div class="info-item">
            <label>Branch:</label>
            <span>{selectedBranch?.name_en}</span>
          </div>
          <div class="info-item">
            <label>Vendor:</label>
            <span>{selectedVendor?.vendor_name}</span>
          </div>
          <div class="info-item">
            <label>Receiving User:</label>
            <span>{$currentUser?.full_name}</span>
          </div>
        </div>
      </div>

      <div class="form-section-full">
        <h3>Bill Details</h3>
        <div class="form-row">
          <div class="form-group-full">
            <label>Current Date & Time</label>
            <input type="text" value={currentDateTime} readonly class="readonly-input" />
          </div>
          <div class="form-group-full">
            <label>Bill Date *</label>
            <input type="date" bind:value={billDate} required />
          </div>
          <div class="form-group-full">
            <label>Bill Amount *</label>
            <input type="number" bind:value={billAmount} placeholder="0.00" step="0.01" required />
          </div>
          <div class="form-group-full">
            <label>Bill Number *</label>
            <input type="text" bind:value={billNumber} placeholder="Bill #" required />
          </div>
        </div>
      </div>

      <!-- Return Policy Section -->
      {#if selectedVendor}
      <div class="form-section-full return-policy-section">
        <h3>Current Return Policy for {selectedVendor.vendor_name}</h3>
        <div class="policy-grid">
          <div class="policy-item">
            <label>Expired Products:</label>
            <span class="policy-value">{selectedVendor.return_expired_products || 'Not specified'}</span>
          </div>
          <div class="policy-item">
            <label>Near Expiry Products:</label>
            <span class="policy-value">{selectedVendor.return_near_expiry_products || 'Not specified'}</span>
          </div>
          <div class="policy-item">
            <label>Over Stock:</label>
            <span class="policy-value">{selectedVendor.return_over_stock || 'Not specified'}</span>
          </div>
          <div class="policy-item">
            <label>Damage Products:</label>
            <span class="policy-value">{selectedVendor.return_damage_products || 'Not specified'}</span>
          </div>
          <div class="policy-item">
            <label>Return Policy Status:</label>
            <span class="policy-value">{selectedVendor.no_return ? 'No Returns Accepted' : 'Returns Accepted'}</span>
          </div>
        </div>
      </div>
      {/if}

      <!-- Return Processing Section -->
      {#if selectedVendor && !selectedVendor.no_return}
      <div class="form-section-full">
        <h3>Return Processing</h3>
        <p class="section-description">Mark if there are any returns for this receiving and enter amounts</p>
        
        {#each [
          { key: 'expired', label: 'Expired Products' },
          { key: 'nearExpiry', label: 'Near Expiry Products' },
          { key: 'overStock', label: 'Over Stock' },
          { key: 'damage', label: 'Damage Products' }
        ] as returnType}
        <div class="return-question">
          <label>Returns for {returnType.label}:</label>
          <div class="form-row">
            <div class="form-group-full">
              <select bind:value={returns[returnType.key].hasReturn}>
                <option value="no">No</option>
                <option value="yes">Yes</option>
              </select>
            </div>
            {#if returns[returnType.key].hasReturn === 'yes'}
              <div class="form-group-full">
                <input type="number" bind:value={returns[returnType.key].amount} placeholder="Return amount" step="0.01" min="0" />
              </div>
              <div class="form-group-full">
                <select bind:value={returns[returnType.key].erpDocumentType}>
                  <option value="">Select ERP Document Type</option>
                  <option value="GRR">GRR (Goods Return Receipt)</option>
                  <option value="PRI">PRI (Purchase Return Invoice)</option>
                </select>
              </div>
              <div class="form-group-full">
                <input type="text" bind:value={returns[returnType.key].erpDocumentNumber} placeholder="ERP document number" />
              </div>
              <div class="form-group-full">
                <input type="text" bind:value={returns[returnType.key].vendorDocumentNumber} placeholder="Vendor document number" />
              </div>
            {/if}
          </div>
        </div>
        {/each}

        <!-- Bill Amount Summary -->
        <div class="bill-summary">
          <div class="summary-row">
            <label>Original Bill Amount:</label>
            <span class="amount-display">{parseFloat(billAmount || 0).toFixed(2)}</span>
          </div>
          <div class="summary-row">
            <label>Total Return Amount:</label>
            <span class="amount-display return-amount">{(
              parseFloat(returns.expired.hasReturn === 'yes' ? returns.expired.amount || 0 : 0) +
              parseFloat(returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.amount || 0 : 0) +
              parseFloat(returns.overStock.hasReturn === 'yes' ? returns.overStock.amount || 0 : 0) +
              parseFloat(returns.damage.hasReturn === 'yes' ? returns.damage.amount || 0 : 0)
            ).toFixed(2)}</span>
          </div>
          <div class="summary-row final-amount">
            <label>Final Bill Amount:</label>
            <span class="amount-display">{(
              parseFloat(billAmount || 0) - (
                parseFloat(returns.expired.hasReturn === 'yes' ? returns.expired.amount || 0 : 0) +
                parseFloat(returns.nearExpiry.hasReturn === 'yes' ? returns.nearExpiry.amount || 0 : 0) +
                parseFloat(returns.overStock.hasReturn === 'yes' ? returns.overStock.amount || 0 : 0) +
                parseFloat(returns.damage.hasReturn === 'yes' ? returns.damage.amount || 0 : 0)
              )
            ).toFixed(2)}</span>
          </div>
        </div>
      </div>
      {/if}

      <div class="form-section-full">
        <h3>Payment Information</h3>
        <div class="form-row">
          <div class="form-group-full">
            <label>Payment Method *</label>
            <select bind:value={paymentMethod} required>
              <option value="">Select Payment Method</option>
              <option value="Cash on Delivery">Cash on Delivery</option>
              <option value="Bank on Delivery">Bank on Delivery</option>
              <option value="Cash Credit">Cash Credit</option>
              <option value="Bank Credit">Bank Credit</option>
            </select>
          </div>
          {#if paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit'}
            <div class="form-group-full">
              <label>Credit Period (days)</label>
              <input type="number" bind:value={creditPeriod} placeholder="Enter credit period in days" min="0" />
            </div>
          {/if}
          {#if paymentMethod === 'Bank on Delivery' || paymentMethod === 'Bank Credit'}
            <div class="form-group-full">
              <label>Bank Name</label>
              <input type="text" bind:value={bankName} placeholder="Enter bank name" />
            </div>
            <div class="form-group-full">
              <label>IBAN</label>
              <input type="text" bind:value={iban} placeholder="Enter IBAN number" />
            </div>
          {/if}
        </div>
      </div>

      <!-- Due Date Section -->
      {#if paymentMethod}
      <div class="form-section-full">
        <h3>Due Date Information</h3>
        {#if paymentMethod === 'Cash on Delivery' || paymentMethod === 'Bank on Delivery'}
          <p class="section-description">Payment due on delivery (current date)</p>
        {:else if paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit'}
          <p class="section-description">Calculated based on bill date and credit period</p>
        {/if}
        <div class="form-row">
          <div class="form-group-full">
            <label>Due Date</label>
            <input type="date" value={dueDate} readonly class="readonly-input" />
            {#if paymentMethod === 'Cash Credit' || paymentMethod === 'Bank Credit'}
              <small class="calculation-info">Bill Date + {creditPeriod || 0} days</small>
            {:else}
              <small class="calculation-info">Due on delivery</small>
            {/if}
          </div>
        </div>
      </div>
      {/if}

      {#if selectedVendor?.vat_applicable === 'VAT Applicable'}
      <div class="form-section-full">
        <h3>VAT Verification</h3>
        <div class="form-row">
          <div class="form-group-full">
            <label>Vendor VAT Number (from system)</label>
            <input type="text" value={selectedVendor?.vat_number || 'Not set'} disabled />
          </div>
          <div class="form-group-full">
            <label>Bill VAT Number *</label>
            <input type="text" bind:value={billVatNumber} placeholder="VAT number from bill" required />
          </div>
          {#if billVatNumber && billVatNumber !== selectedVendor?.vat_number}
            <div class="form-group-full">
              <label>VAT Mismatch Reason *</label>
              <textarea bind:value={vatMismatchReason} placeholder="Explain why VAT numbers don't match" required></textarea>
            </div>
          {/if}
        </div>
      </div>
      {/if}

      <div class="action-buttons">
        <button class="cancel-btn" on:click={backToVendorSelection}>Cancel</button>
        <button 
          class="save-btn" 
          disabled={!billDate || !billAmount || !billNumber || !paymentMethod}
        >
          Save & Generate Clearance Certificate
        </button>
      </div>
    </div>
  </div>
{/if}
</div>

<style>
  .container {
    padding: 1rem;
    width: 100%;
    max-width: 100%;
    box-sizing: border-box;
    margin: 0;
  }

  .header {
    margin-bottom: 2rem;
  }

  .header h2 {
    margin: 0 0 0.5rem 0;
    color: #333;
  }

  .user-info {
    margin: 0;
    color: #666;
  }

  .cards-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    width: 100%;
    max-width: 100%;
    box-sizing: border-box;
  }

  .card {
    border: 3px solid orange;
    border-radius: 8px;
    padding: 1rem;
    background: white;
    min-height: 200px;
    display: flex;
    flex-direction: column;
    transition: all 0.3s ease;
  }

  .card.disabled {
    opacity: 0.5;
    border-color: #ccc;
    pointer-events: none;
  }

  .card.completed {
    border-color: #4CAF50;
    background: #f0f9f0;
  }

  .card.finalize-card {
    border-color: #2196F3;
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid #eee;
  }

  .card-header h3 {
    margin: 0;
    font-size: 1rem;
    color: #333;
  }

  .checkmark {
    color: #4CAF50;
    font-size: 1.5rem;
    font-weight: bold;
  }

  .card-body {
    flex: 1;
    overflow-y: auto;
    max-height: 300px;
  }

  .disabled-text {
    color: #999;
    font-style: italic;
    text-align: center;
    padding: 2rem 0;
  }

  .loading {
    color: #666;
    text-align: center;
    padding: 2rem 0;
  }

  .search-input {
    width: 100%;
    padding: 0.5rem;
    margin-bottom: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-sizing: border-box;
  }

  .list {
    max-height: 200px;
    overflow-y: auto;
  }

  .list-item {
    padding: 0.75rem;
    border-bottom: 1px solid #eee;
    cursor: pointer;
    transition: background 0.2s;
  }

  .list-item:hover {
    background: #f5f5f5;
  }

  .list-item.selected {
    background: #e3f2fd;
    border-left: 3px solid #2196F3;
  }

  .list-item strong {
    display: block;
    color: #333;
  }

  .subtitle {
    display: block;
    font-size: 0.85rem;
    color: #666;
    margin-top: 0.25rem;
  }

  .selected-item {
    background: #f5f5f5;
    padding: 1rem;
    border-radius: 4px;
    text-align: center;
  }

  .selected-item strong {
    display: block;
    font-size: 1.1rem;
    color: #333;
    margin-bottom: 0.5rem;
  }

  .selected-item p {
    margin: 0.25rem 0;
    color: #666;
  }

  .change-btn {
    margin-top: 0.5rem;
    padding: 0.5rem 1rem;
    background: #ff9800;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9rem;
  }

  .change-btn:hover {
    background: #f57c00;
  }

  .selected-items-list {
    margin-bottom: 0.5rem;
  }

  .selected-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: #2196F3;
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
    margin: 0.25rem;
    font-size: 0.85rem;
  }

  .remove-btn {
    background: rgba(255, 255, 255, 0.3);
    border: none;
    color: white;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    cursor: pointer;
    font-size: 1rem;
    line-height: 1;
    padding: 0;
  }

  .remove-btn:hover {
    background: rgba(255, 255, 255, 0.5);
  }

  .form-group {
    margin-bottom: 1rem;
  }

  .form-group label {
    display: block;
    margin-bottom: 0.25rem;
    color: #333;
    font-weight: 500;
    font-size: 0.9rem;
  }

  .input-field {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-sizing: border-box;
    font-size: 0.9rem;
  }

  .finalize-btn {
    width: 100%;
    padding: 1rem;
    background: #4CAF50;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  .finalize-btn:hover {
    background: #45a049;
  }

  .load-more-btn {
    width: 100%;
    padding: 0.75rem;
    margin-top: 0.5rem;
    background: #2196F3;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9rem;
  }

  .load-more-btn:hover:not(:disabled) {
    background: #1976D2;
  }

  .load-more-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .info-text {
    text-align: center;
    color: #666;
    font-size: 0.85rem;
    margin: 0;
  }

  .summary-info {
    background: #f5f5f5;
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
  }

  .summary-info p {
    margin: 0.5rem 0;
    font-size: 0.9rem;
  }

  /* Bill Information Full Page Styles */
  .bill-info-page {
    width: 100%;
    background: white;
  }

  .back-btn {
    background: #2196F3;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1rem;
    margin: 1.5rem;
    transition: all 0.3s ease;
    box-shadow: 0 2px 8px rgba(33, 150, 243, 0.3);
  }

  .back-btn:hover {
    background: #1976D2;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(33, 150, 243, 0.4);
  }

  .bill-info-content {
    padding: 2rem;
  }

  .info-section {
    background: #f5f5f5;
    padding: 1.5rem;
    border-radius: 8px;
    margin-bottom: 2rem;
  }

  .info-section h3 {
    margin: 0 0 1rem 0;
    color: #333;
  }

  .info-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
  }

  .info-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .info-item label {
    font-weight: 600;
    color: #666;
    font-size: 0.85rem;
  }

  .info-item span {
    color: #333;
    font-size: 1rem;
  }

  .form-section-full {
    margin-bottom: 2rem;
    padding: 1.5rem;
    border: 1px solid #ddd;
    border-radius: 8px;
  }

  .form-section-full h3 {
    margin: 0 0 1.5rem 0;
    color: #333;
    font-size: 1.2rem;
    border-bottom: 2px solid #2196F3;
    padding-bottom: 0.5rem;
  }

  .form-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 1.5rem;
  }

  .form-group-full {
    display: flex;
    flex-direction: column;
  }

  .form-group-full label {
    margin-bottom: 0.5rem;
    color: #333;
    font-weight: 500;
    font-size: 0.95rem;
  }

  .form-group-full input,
  .form-group-full select,
  .form-group-full textarea {
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 1rem;
  }

  .form-group-full input:focus,
  .form-group-full select:focus,
  .form-group-full textarea:focus {
    outline: none;
    border-color: #2196F3;
    box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
  }

  .form-group-full input:disabled {
    background: #f5f5f5;
    cursor: not-allowed;
  }
  
  .readonly-input {
    background: #f5f5f5 !important;
    cursor: not-allowed;
  }

  .form-group-full textarea {
    min-height: 80px;
    resize: vertical;
  }
  
  .section-description {
    color: #666;
    font-size: 0.9rem;
    margin: 0 0 1rem 0;
  }
  
  /* Return Policy Section */
  .return-policy-section {
    background: #f9f9f9;
  }
  
  .policy-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
  }
  
  .policy-item {
    background: white;
    padding: 1rem;
    border-radius: 4px;
    border: 1px solid #e0e0e0;
  }
  
  .policy-item label {
    display: block;
    font-weight: 600;
    color: #666;
    font-size: 0.85rem;
    margin-bottom: 0.5rem;
  }
  
  .policy-value {
    display: block;
    color: #333;
    font-size: 1rem;
    padding: 0.5rem;
    background: #f5f5f5;
    border-radius: 4px;
  }
  
  /* Return Processing */
  .return-question {
    background: #f9f9f9;
    padding: 1rem;
    border-radius: 4px;
    margin-bottom: 1rem;
    border-left: 4px solid #ff9800;
  }
  
  .return-question > label {
    font-weight: 600;
    color: #333;
    display: block;
    margin-bottom: 0.75rem;
  }
  
  /* Bill Summary */
  .bill-summary {
    background: #e3f2fd;
    padding: 1.5rem;
    border-radius: 8px;
    margin-top: 1.5rem;
    border: 2px solid #2196F3;
  }
  
  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem 0;
    border-bottom: 1px solid #bbdefb;
  }
  
  .summary-row:last-child {
    border-bottom: none;
  }
  
  .summary-row.final-amount {
    font-weight: bold;
    font-size: 1.1rem;
    padding-top: 1rem;
    margin-top: 0.5rem;
    border-top: 2px solid #2196F3;
  }
  
  .amount-display {
    font-size: 1.1rem;
    color: #333;
  }
  
  .amount-display.return-amount {
    color: #f44336;
    font-weight: 600;
  }
  
  .calculation-info {
    display: block;
    font-size: 0.85rem;
    color: #666;
    margin-top: 0.25rem;
    font-style: italic;
  }

  .action-buttons {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    margin-top: 2rem;
    padding-top: 2rem;
    border-top: 2px solid #eee;
  }

  .cancel-btn {
    padding: 0.75rem 2rem;
    background: #f44336;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
  }

  .cancel-btn:hover {
    background: #d32f2f;
  }

  .save-btn {
    padding: 0.75rem 2rem;
    background: #4CAF50;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: bold;
  }

  .save-btn:hover:not(:disabled) {
    background: #45a049;
  }

  .save-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* Standalone Next Button */
  .next-button-container {
    max-width: 1400px;
    margin: 2rem auto;
    padding: 2rem;
    background: white;
    border: 2px solid #ff6600;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    text-align: center;
  }

  .next-button-container .summary-info {
    display: flex;
    justify-content: center;
    gap: 2rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
  }

  .next-button-container .summary-info p {
    margin: 0;
    font-size: 0.95rem;
  }

  .next-btn {
    padding: 1rem 3rem;
    background: linear-gradient(135deg, #ff6600 0%, #ff8533 100%);
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1.1rem;
    font-weight: bold;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(255, 102, 0, 0.3);
  }

  .next-btn:hover {
    background: linear-gradient(135deg, #ff7711 0%, #ff9944 100%);
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(255, 102, 0, 0.4);
  }

  .next-button-container .info-text {
    margin-top: 1rem;
    color: #666;
    font-size: 0.9rem;
  }

  @media (max-width: 1200px) {
    .cards-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 768px) {
    .cards-grid {
      grid-template-columns: 1fr;
    }
    
    .next-button-container .summary-info {
      flex-direction: column;
      gap: 0.5rem;
    }
  }
</style>
