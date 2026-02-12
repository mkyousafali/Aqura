<!-- DefaultPositions.svelte -->
<!-- Manage default position assignments per branch for receiving tasks -->
<script lang="ts">
  import { supabase } from '$lib/utils/supabase';
  import { onMount } from 'svelte';

  // Branch selection state
  let branches: any[] = [];
  let selectedBranchId: number | null = null;
  let selectedBranchName = '';
  let isLoadingBranches = false;

  // Default positions state
  let defaultPositions: any = null;
  let isLoadingPositions = false;
  let isSaving = false;
  let saveSuccess = '';
  let saveError = '';

  // Position definitions (the 6 roles, excluding Shelf Stocker)
  const positionRoles = [
    { key: 'branch_manager_user_id', label: 'Branch Manager', icon: '👔', single: true },
    { key: 'purchasing_manager_user_id', label: 'Purchasing Manager', icon: '🛒', single: true },
    { key: 'inventory_manager_user_id', label: 'Inventory Manager', icon: '📦', single: true },
    { key: 'accountant_user_id', label: 'Accountant', icon: '💰', single: true },
    { key: 'night_supervisor_user_ids', label: 'Night Supervisor(s)', icon: '🌙', single: false },
    { key: 'warehouse_handler_user_id', label: 'Warehouse Handler', icon: '🏭', single: true },
  ];

  // Assigned users (resolved from IDs)
  let assignedUsers: Record<string, any> = {};

  // User picker state
  let showUserPicker = false;
  let pickerRoleKey = '';
  let pickerRoleLabel = '';
  let pickerIsSingle = true;
  let allUsers: any[] = [];
  let filteredUsers: any[] = [];
  let userSearchQuery = '';
  let isLoadingUsers = false;

  onMount(async () => {
    await loadBranches();
  });

  async function loadBranches() {
    try {
      isLoadingBranches = true;
      const { data, error } = await supabase
        .from('branches')
        .select('id, name_en')
        .eq('is_active', true)
        .order('name_en');
      
      if (error) throw error;
      branches = data || [];
    } catch (err: any) {
      console.error('Error loading branches:', err);
    } finally {
      isLoadingBranches = false;
    }
  }

  async function selectBranch(branchId: number) {
    selectedBranchId = branchId;
    const branch = branches.find(b => b.id === branchId);
    selectedBranchName = branch?.name_en || '';
    saveSuccess = '';
    saveError = '';
    await loadDefaultPositions();
  }

  async function loadDefaultPositions() {
    if (!selectedBranchId) return;

    try {
      isLoadingPositions = true;
      assignedUsers = {};

      const { data, error } = await supabase
        .from('branch_default_positions')
        .select('*')
        .eq('branch_id', selectedBranchId)
        .maybeSingle();

      if (error) throw error;

      defaultPositions = data;

      // Resolve user names for assigned positions
      if (data) {
        const userIds: string[] = [];
        
        for (const role of positionRoles) {
          if (role.single) {
            if (data[role.key]) userIds.push(data[role.key]);
          } else {
            if (data[role.key] && Array.isArray(data[role.key])) {
              userIds.push(...data[role.key]);
            }
          }
        }

        if (userIds.length > 0) {
          const { data: employees, error: usersError } = await supabase
            .from('hr_employee_master')
            .select('user_id, name_en, id')
            .in('user_id', userIds);

          if (!usersError && employees) {
            const userMap: Record<string, any> = {};
            employees.forEach(emp => {
              userMap[emp.user_id] = {
                id: emp.user_id,
                username: emp.id,
                displayName: emp.name_en || emp.id,
              };
            });

            for (const role of positionRoles) {
              if (role.single) {
                if (data[role.key] && userMap[data[role.key]]) {
                  assignedUsers[role.key] = userMap[data[role.key]];
                }
              } else {
                if (data[role.key] && Array.isArray(data[role.key])) {
                  assignedUsers[role.key] = data[role.key]
                    .filter((id: string) => userMap[id])
                    .map((id: string) => userMap[id]);
                }
              }
            }
          }
        }
      }
    } catch (err: any) {
      console.error('Error loading default positions:', err);
    } finally {
      isLoadingPositions = false;
    }
  }

  function openUserPicker(roleKey: string, roleLabel: string, isSingle: boolean) {
    pickerRoleKey = roleKey;
    pickerRoleLabel = roleLabel;
    pickerIsSingle = isSingle;
    userSearchQuery = '';
    showUserPicker = true;
    loadAllUsers();
  }

  async function loadAllUsers() {
    try {
      isLoadingUsers = true;
      
      // Get all employees
      const { data, error } = await supabase
        .from('hr_employee_master')
        .select('user_id, name_en, id')
        .order('name_en');
      
      if (error) throw error;
      
      // Get inactive user IDs (small set) to filter them out
      const { data: inactiveUsers } = await supabase
        .from('users')
        .select('id')
        .neq('status', 'active');
      
      const inactiveIds = new Set((inactiveUsers || []).map(u => u.id));
      
      allUsers = (data || [])
        .filter(emp => emp.user_id && !inactiveIds.has(emp.user_id))
        .map(emp => ({
          id: emp.user_id,
          username: emp.id,
          displayName: emp.name_en || emp.id,
        }));
      filteredUsers = allUsers;
    } catch (err: any) {
      console.error('Error loading users:', err);
    } finally {
      isLoadingUsers = false;
    }
  }

  function handleUserSearch() {
    if (!userSearchQuery.trim()) {
      filteredUsers = allUsers;
      return;
    }
    const q = userSearchQuery.toLowerCase();
    filteredUsers = allUsers.filter(u => 
      (u.username && u.username.toLowerCase().includes(q)) ||
      (u.displayName && u.displayName.toLowerCase().includes(q))
    );
  }

  $: if (userSearchQuery !== undefined) {
    handleUserSearch();
  }

  function selectUser(user: any) {
    if (pickerIsSingle) {
      assignedUsers[pickerRoleKey] = user;
      assignedUsers = { ...assignedUsers };
    } else {
      // Multi-select (night supervisors)
      const current = assignedUsers[pickerRoleKey] || [];
      if (!current.find((u: any) => u.id === user.id)) {
        assignedUsers[pickerRoleKey] = [...current, user];
        assignedUsers = { ...assignedUsers };
      }
    }
    showUserPicker = false;
  }

  function removeUser(roleKey: string, userId?: string) {
    const role = positionRoles.find(r => r.key === roleKey);
    if (role?.single) {
      delete assignedUsers[roleKey];
      assignedUsers = { ...assignedUsers };
    } else {
      // Multi-select removal
      const current = assignedUsers[roleKey] || [];
      assignedUsers[roleKey] = current.filter((u: any) => u.id !== userId);
      assignedUsers = { ...assignedUsers };
    }
  }

  function closeUserPicker() {
    showUserPicker = false;
    userSearchQuery = '';
  }

  function isUserAlreadySelected(userId: string): boolean {
    if (!pickerIsSingle) {
      const current = assignedUsers[pickerRoleKey] || [];
      return current.some((u: any) => u.id === userId);
    }
    return false;
  }

  async function saveDefaults() {
    if (!selectedBranchId) return;
    
    try {
      isSaving = true;
      saveSuccess = '';
      saveError = '';

      const posData: any = {
        branch_id: selectedBranchId,
        branch_manager_user_id: assignedUsers['branch_manager_user_id']?.id || null,
        purchasing_manager_user_id: assignedUsers['purchasing_manager_user_id']?.id || null,
        inventory_manager_user_id: assignedUsers['inventory_manager_user_id']?.id || null,
        accountant_user_id: assignedUsers['accountant_user_id']?.id || null,
        night_supervisor_user_ids: (assignedUsers['night_supervisor_user_ids'] || []).map((u: any) => u.id),
        warehouse_handler_user_id: assignedUsers['warehouse_handler_user_id']?.id || null,
      };

      const { error } = await supabase
        .from('branch_default_positions')
        .upsert(posData, { onConflict: 'branch_id' });

      if (error) throw error;

      saveSuccess = `Default positions saved for ${selectedBranchName}!`;
      
      // Reload to confirm
      await loadDefaultPositions();
    } catch (err: any) {
      console.error('Error saving default positions:', err);
      saveError = 'Failed to save: ' + err.message;
    } finally {
      isSaving = false;
    }
  }

  function changeBranch() {
    selectedBranchId = null;
    selectedBranchName = '';
    defaultPositions = null;
    assignedUsers = {};
    saveSuccess = '';
    saveError = '';
  }
</script>

<div class="default-positions-container">
  <div class="header">
    <h2>🏢 Default Positions</h2>
    <p class="subtitle">Assign default staff positions per branch for the receiving process</p>
  </div>

  <!-- Branch Selection -->
  {#if !selectedBranchId}
    <div class="branch-selection-section">
      <h3>Select Branch</h3>
      {#if isLoadingBranches}
        <div class="loading-state">
          <div class="spinner"></div>
          <span>Loading branches...</span>
        </div>
      {:else if branches.length === 0}
        <div class="empty-state">
          <span class="empty-icon">📭</span>
          <p>No active branches found</p>
        </div>
      {:else}
        <div class="branch-grid">
          {#each branches as branch}
            <button class="branch-card" on:click={() => selectBranch(branch.id)}>
              <span class="branch-icon">🏪</span>
              <span class="branch-name">{branch.name_en}</span>
              <span class="branch-id">ID: {branch.id}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>
  {:else}
    <!-- Selected Branch Header -->
    <div class="selected-branch-header">
      <div class="branch-info">
        <span class="branch-icon-large">🏪</span>
        <div>
          <h3>{selectedBranchName}</h3>
          <span class="branch-id-label">Branch ID: {selectedBranchId}</span>
        </div>
      </div>
      <button class="change-branch-btn" on:click={changeBranch}>
        Change Branch
      </button>
    </div>

    <!-- Position Cards -->
    {#if isLoadingPositions}
      <div class="loading-state">
        <div class="spinner"></div>
        <span>Loading positions...</span>
      </div>
    {:else}
      <div class="positions-grid">
        {#each positionRoles as role}
          <div class="position-card">
            <div class="position-header">
              <span class="position-icon">{role.icon}</span>
              <h4>{role.label}</h4>
              {#if !role.single}
                <span class="multi-badge">Multiple</span>
              {/if}
            </div>

            <div class="position-body">
              {#if role.single}
                <!-- Single user assignment -->
                {#if assignedUsers[role.key]}
                  <div class="assigned-user">
                    <div class="user-info-card">
                      <span class="user-avatar">👤</span>
                      <div class="user-details">
                        <span class="user-name">{assignedUsers[role.key].displayName || assignedUsers[role.key].username}</span>
                      </div>
                    </div>
                    <div class="user-actions">
                      <button class="change-btn" on:click={() => openUserPicker(role.key, role.label, role.single)} title="Change user">
                        🔄
                      </button>
                      <button class="remove-btn" on:click={() => removeUser(role.key)} title="Remove user">
                        ✕
                      </button>
                    </div>
                  </div>
                {:else}
                  <div class="no-assignment">
                    <span class="no-user-text">No user assigned</span>
                    <button class="assign-btn" on:click={() => openUserPicker(role.key, role.label, role.single)}>
                      + Assign User
                    </button>
                  </div>
                {/if}
              {:else}
                <!-- Multi user assignment (Night Supervisors) -->
                {#if assignedUsers[role.key] && assignedUsers[role.key].length > 0}
                  <div class="assigned-users-list">
                    {#each assignedUsers[role.key] as user}
                      <div class="assigned-user compact">
                        <div class="user-info-card">
                          <span class="user-avatar">👤</span>
                          <div class="user-details">
                            <span class="user-name">{user.displayName || user.username}</span>
                          </div>
                        </div>
                        <button class="remove-btn" on:click={() => removeUser(role.key, user.id)} title="Remove">
                          ✕
                        </button>
                      </div>
                    {/each}
                  </div>
                  <button class="assign-btn add-more" on:click={() => openUserPicker(role.key, role.label, role.single)}>
                    + Add Another
                  </button>
                {:else}
                  <div class="no-assignment">
                    <span class="no-user-text">No users assigned</span>
                    <button class="assign-btn" on:click={() => openUserPicker(role.key, role.label, role.single)}>
                      + Assign User
                    </button>
                  </div>
                {/if}
              {/if}
            </div>
          </div>
        {/each}
      </div>

      <!-- Save Section -->
      <div class="save-section">
        {#if saveSuccess}
          <div class="save-success">✅ {saveSuccess}</div>
        {/if}
        {#if saveError}
          <div class="save-error">❌ {saveError}</div>
        {/if}
        <button class="save-btn" on:click={saveDefaults} disabled={isSaving}>
          {#if isSaving}
            <div class="spinner-small"></div> Saving...
          {:else}
            💾 Save Default Positions
          {/if}
        </button>
      </div>
    {/if}
  {/if}
</div>

<!-- User Picker Modal -->
{#if showUserPicker}
  <div class="modal-overlay" on:click={closeUserPicker}>
    <div class="user-picker-modal" on:click|stopPropagation>
      <div class="modal-header">
        <h3>Select {pickerRoleLabel}</h3>
        <button class="close-btn" on:click={closeUserPicker}>✕</button>
      </div>
      
      <div class="modal-search">
        <input 
          type="text" 
          placeholder="Search by name or employee ID..." 
          bind:value={userSearchQuery}
          class="search-input"
        />
        {#if userSearchQuery}
          <button class="clear-search" on:click={() => userSearchQuery = ''}>✕</button>
        {/if}
      </div>

      <div class="modal-body">
        {#if isLoadingUsers}
          <div class="loading-state">
            <div class="spinner"></div>
            <span>Loading users...</span>
          </div>
        {:else if filteredUsers.length === 0}
          <div class="empty-state">
            <span class="empty-icon">🔍</span>
            <p>No users found</p>
          </div>
        {:else}
          <div class="users-list">
            <div class="search-results-info">
              Showing {filteredUsers.length} of {allUsers.length} users
            </div>
            {#each filteredUsers as user}
              {@const alreadySelected = isUserAlreadySelected(user.id)}
              <button 
                class="user-row" 
                class:already-selected={alreadySelected}
                on:click={() => !alreadySelected && selectUser(user)}
                disabled={alreadySelected}
              >
                <span class="user-avatar">👤</span>
                <div class="user-row-info">
                  <span class="user-row-name">{user.displayName || user.username}</span>
                  <span class="user-row-meta">
                    {user.username}
                  </span>
                </div>
                {#if alreadySelected}
                  <span class="selected-badge">✓ Selected</span>
                {/if}
              </button>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .default-positions-container {
    padding: 1.5rem;
    max-width: 100%;
    height: 100%;
    overflow-y: auto;
  }

  .header {
    margin-bottom: 1.5rem;
  }

  .header h2 {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1a202c;
    margin: 0 0 0.25rem 0;
  }

  .subtitle {
    color: #718096;
    font-size: 0.9rem;
    margin: 0;
  }

  /* Branch Selection */
  .branch-selection-section h3 {
    font-size: 1.1rem;
    font-weight: 600;
    color: #2d3748;
    margin-bottom: 1rem;
  }

  .branch-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 1rem;
  }

  .branch-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding: 1.25rem;
    background: white;
    border: 2px solid #e2e8f0;
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .branch-card:hover {
    border-color: #3182ce;
    background: #ebf8ff;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(49, 130, 206, 0.15);
  }

  .branch-icon {
    font-size: 2rem;
  }

  .branch-name {
    font-weight: 600;
    color: #2d3748;
    text-align: center;
    font-size: 0.95rem;
  }

  .branch-id {
    font-size: 0.75rem;
    color: #a0aec0;
  }

  /* Selected Branch Header */
  .selected-branch-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: linear-gradient(135deg, #ebf8ff, #e6fffa);
    padding: 1rem 1.5rem;
    border-radius: 12px;
    margin-bottom: 1.5rem;
    border: 1px solid #bee3f8;
  }

  .branch-info {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .branch-icon-large {
    font-size: 2rem;
  }

  .branch-info h3 {
    margin: 0;
    font-size: 1.2rem;
    font-weight: 700;
    color: #2d3748;
  }

  .branch-id-label {
    font-size: 0.8rem;
    color: #718096;
  }

  .change-branch-btn {
    padding: 0.5rem 1rem;
    background: white;
    border: 1px solid #cbd5e0;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.85rem;
    color: #4a5568;
    transition: all 0.2s;
  }

  .change-branch-btn:hover {
    background: #f7fafc;
    border-color: #a0aec0;
  }

  /* Positions Grid */
  .positions-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 1rem;
    margin-bottom: 1.5rem;
  }

  .position-card {
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    overflow: hidden;
    transition: box-shadow 0.2s;
  }

  .position-card:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }

  .position-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: #f7fafc;
    border-bottom: 1px solid #e2e8f0;
  }

  .position-icon {
    font-size: 1.3rem;
  }

  .position-header h4 {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 600;
    color: #2d3748;
    flex: 1;
  }

  .multi-badge {
    font-size: 0.7rem;
    background: #805ad5;
    color: white;
    padding: 0.15rem 0.5rem;
    border-radius: 10px;
    font-weight: 500;
  }

  .position-body {
    padding: 1rem;
  }

  /* Assigned User */
  .assigned-user {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.5rem;
    background: #f0fff4;
    border: 1px solid #c6f6d5;
    border-radius: 8px;
  }

  .assigned-user.compact {
    margin-bottom: 0.5rem;
  }

  .user-info-card {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .user-avatar {
    font-size: 1.2rem;
  }

  .user-details {
    display: flex;
    flex-direction: column;
  }

  .user-name {
    font-weight: 600;
    font-size: 0.9rem;
    color: #2d3748;
  }

  .user-position {
    font-size: 0.75rem;
    color: #718096;
  }

  .user-actions {
    display: flex;
    gap: 0.25rem;
  }

  .change-btn, .remove-btn {
    width: 30px;
    height: 30px;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }

  .change-btn {
    background: #ebf8ff;
    color: #3182ce;
  }

  .change-btn:hover {
    background: #bee3f8;
  }

  .remove-btn {
    background: #fed7d7;
    color: #e53e3e;
  }

  .remove-btn:hover {
    background: #feb2b2;
  }

  /* No Assignment */
  .no-assignment {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem;
    background: #fffbeb;
    border: 1px dashed #f6e05e;
    border-radius: 8px;
  }

  .no-user-text {
    color: #b7791f;
    font-size: 0.85rem;
    font-style: italic;
  }

  .assign-btn {
    padding: 0.4rem 0.75rem;
    background: #3182ce;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 500;
    transition: background 0.2s;
  }

  .assign-btn:hover {
    background: #2b6cb0;
  }

  .assign-btn.add-more {
    margin-top: 0.5rem;
    background: #805ad5;
    width: 100%;
  }

  .assign-btn.add-more:hover {
    background: #6b46c1;
  }

  .assigned-users-list {
    max-height: 200px;
    overflow-y: auto;
  }

  /* Save Section */
  .save-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
    padding: 1.5rem;
    background: #f7fafc;
    border-radius: 12px;
    border: 1px solid #e2e8f0;
  }

  .save-btn {
    padding: 0.75rem 2rem;
    background: #38a169;
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: 600;
    transition: background 0.2s;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .save-btn:hover:not(:disabled) {
    background: #2f855a;
  }

  .save-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .save-success {
    padding: 0.5rem 1rem;
    background: #f0fff4;
    color: #276749;
    border: 1px solid #c6f6d5;
    border-radius: 8px;
    font-size: 0.9rem;
  }

  .save-error {
    padding: 0.5rem 1rem;
    background: #fff5f5;
    color: #c53030;
    border: 1px solid #fed7d7;
    border-radius: 8px;
    font-size: 0.9rem;
  }

  /* Loading & Empty States */
  .loading-state {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    padding: 2rem;
    color: #718096;
  }

  .spinner {
    width: 24px;
    height: 24px;
    border: 3px solid #e2e8f0;
    border-top-color: #3182ce;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .spinner-small {
    width: 16px;
    height: 16px;
    border: 2px solid rgba(255,255,255,0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding: 2rem;
    color: #a0aec0;
  }

  .empty-icon {
    font-size: 2rem;
  }

  /* Modal Overlay */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
  }

  .user-picker-modal {
    background: white;
    border-radius: 16px;
    width: 90%;
    max-width: 500px;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e2e8f0;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 1.1rem;
    font-weight: 600;
    color: #2d3748;
  }

  .close-btn {
    width: 32px;
    height: 32px;
    border: none;
    background: #f7fafc;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1rem;
    color: #718096;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }

  .close-btn:hover {
    background: #edf2f7;
    color: #e53e3e;
  }

  .modal-search {
    position: relative;
    padding: 0.75rem 1.5rem;
    border-bottom: 1px solid #e2e8f0;
  }

  .modal-search .search-input {
    width: 100%;
    padding: 0.6rem 2rem 0.6rem 0.75rem;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.9rem;
    outline: none;
    transition: border-color 0.2s;
  }

  .modal-search .search-input:focus {
    border-color: #3182ce;
    box-shadow: 0 0 0 3px rgba(49, 130, 206, 0.1);
  }

  .clear-search {
    position: absolute;
    right: 2rem;
    top: 50%;
    transform: translateY(-50%);
    border: none;
    background: none;
    color: #a0aec0;
    cursor: pointer;
    font-size: 1rem;
  }

  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 0.5rem;
  }

  .search-results-info {
    font-size: 0.75rem;
    color: #a0aec0;
    padding: 0.25rem 0.75rem;
    margin-bottom: 0.25rem;
  }

  .users-list {
    display: flex;
    flex-direction: column;
  }

  .user-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.65rem 0.75rem;
    border: none;
    background: transparent;
    cursor: pointer;
    text-align: left;
    width: 100%;
    border-radius: 8px;
    transition: background 0.15s;
  }

  .user-row:hover:not(:disabled) {
    background: #ebf8ff;
  }

  .user-row:disabled {
    cursor: default;
  }

  .user-row.already-selected {
    background: #f0fff4;
    opacity: 0.7;
  }

  .user-row-info {
    display: flex;
    flex-direction: column;
    flex: 1;
  }

  .user-row-name {
    font-weight: 600;
    font-size: 0.9rem;
    color: #2d3748;
  }

  .user-row-meta {
    font-size: 0.75rem;
    color: #a0aec0;
  }

  .selected-badge {
    font-size: 0.75rem;
    color: #38a169;
    font-weight: 600;
  }
</style>
