<!-- DefaultPositions.svelte -->
<!-- Manage default position assignments per branch for receiving tasks -->
<script lang="ts">
  import { supabase } from '$lib/utils/supabase';
  import { onMount } from 'svelte';
  import { t, locale } from '$lib/i18n';

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

  // Position definitions — label keys map to i18n
  const positionRoles = [
    { key: 'branch_manager_user_id',    labelKey: 'branchManager',       icon: '👔', single: true },
    { key: 'purchasing_manager_user_id', labelKey: 'purchasingManager',   icon: '🛒', single: true },
    { key: 'inventory_manager_user_id',  labelKey: 'inventoryManager',    icon: '📦', single: true },
    { key: 'accountant_user_id',         labelKey: 'accountant',          icon: '💰', single: true },
    { key: 'night_supervisor_user_ids',  labelKey: 'nightSupervisor',     icon: '🌙', single: false },
    { key: 'warehouse_handler_user_id',  labelKey: 'warehouseHandler',    icon: '🏭', single: true },
  ];

  // Assigned users (resolved from IDs)
  let assignedUsers: Record<string, any> = {};

  // User picker state
  let showUserPicker = false;
  let pickerRoleKey = '';
  let pickerRoleLabelKey = '';
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
        .select('id, name_en, name_ar')
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

  function getBranchName(branch: any) {
    return $locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en;
  }

  async function selectBranch(branchId: number) {
    selectedBranchId = branchId;
    const branch = branches.find(b => b.id === branchId);
    selectedBranchName = branch ? getBranchName(branch) : '';
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
            .select('user_id, name_en, name_ar, id')
            .in('user_id', userIds);
          if (!usersError && employees) {
            const userMap: Record<string, any> = {};
            employees.forEach(emp => {
              userMap[emp.user_id] = { id: emp.user_id, username: emp.id, name_en: emp.name_en, name_ar: emp.name_ar };
            });
            for (const role of positionRoles) {
              if (role.single) {
                if (data[role.key] && userMap[data[role.key]]) assignedUsers[role.key] = userMap[data[role.key]];
              } else {
                if (data[role.key] && Array.isArray(data[role.key])) {
                  assignedUsers[role.key] = data[role.key].filter((id: string) => userMap[id]).map((id: string) => userMap[id]);
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

  function openUserPicker(roleKey: string, roleLabelKey: string, isSingle: boolean) {
    pickerRoleKey = roleKey;
    pickerRoleLabelKey = roleLabelKey;
    pickerIsSingle = isSingle;
    userSearchQuery = '';
    showUserPicker = true;
    loadAllUsers();
  }

  async function loadAllUsers() {
    try {
      isLoadingUsers = true;
      const { data, error } = await supabase
        .from('hr_employee_master')
        .select('user_id, name_en, name_ar, id')
        .order('name_en');
      if (error) throw error;
      const { data: inactiveUsers } = await supabase.from('users').select('id').neq('status', 'active');
      const inactiveIds = new Set((inactiveUsers || []).map((u: any) => u.id));
      allUsers = (data || [])
        .filter(emp => emp.user_id && !inactiveIds.has(emp.user_id))
        .map(emp => ({ id: emp.user_id, username: emp.id, name_en: emp.name_en, name_ar: emp.name_ar }));
      filteredUsers = allUsers;
    } catch (err: any) {
      console.error('Error loading users:', err);
    } finally {
      isLoadingUsers = false;
    }
  }

  function getUserName(user: any): string {
    if (!user) return '';
    return ($locale === 'ar' ? (user.name_ar || user.name_en) : (user.name_en || user.name_ar)) || user.username || '';
  }

  function handleUserSearch() {
    if (!userSearchQuery.trim()) { filteredUsers = allUsers; return; }
    const q = userSearchQuery.toLowerCase();
    filteredUsers = allUsers.filter(u =>
      (u.username && u.username.toLowerCase().includes(q)) ||
      (u.name_en && u.name_en.toLowerCase().includes(q)) ||
      (u.name_ar && u.name_ar.toLowerCase().includes(q))
    );
  }

  $: if (userSearchQuery !== undefined) { handleUserSearch(); }

  function selectUser(user: any) {
    if (pickerIsSingle) {
      assignedUsers[pickerRoleKey] = user;
      assignedUsers = { ...assignedUsers };
    } else {
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
      const current = assignedUsers[roleKey] || [];
      assignedUsers[roleKey] = current.filter((u: any) => u.id !== userId);
      assignedUsers = { ...assignedUsers };
    }
  }

  function closeUserPicker() { showUserPicker = false; userSearchQuery = ''; }

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
        branch_manager_user_id:     assignedUsers['branch_manager_user_id']?.id || null,
        purchasing_manager_user_id:  assignedUsers['purchasing_manager_user_id']?.id || null,
        inventory_manager_user_id:   assignedUsers['inventory_manager_user_id']?.id || null,
        accountant_user_id:          assignedUsers['accountant_user_id']?.id || null,
        night_supervisor_user_ids:   (assignedUsers['night_supervisor_user_ids'] || []).map((u: any) => u.id),
        warehouse_handler_user_id:   assignedUsers['warehouse_handler_user_id']?.id || null,
      };
      const { error } = await supabase.from('branch_default_positions').upsert(posData, { onConflict: 'branch_id' });
      if (error) throw error;
      saveSuccess = t('defaultPositions.saveDefaults') + ' ✅';
      await loadDefaultPositions();
    } catch (err: any) {
      console.error('Error saving default positions:', err);
      saveError = err.message;
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

<div class="dp-container">

  <!-- Branch Selection -->
  {#if !selectedBranchId}
    <div class="branch-selection-card">
      <div class="section-label">🏢 {t('defaultPositions.selectBranch')}</div>

      {#if isLoadingBranches}
        <div class="state-center">
          <div class="spinner"></div>
          <span>{t('defaultPositions.loadingBranches')}</span>
        </div>
      {:else if branches.length === 0}
        <div class="state-center muted">
          <span>📭</span>
          <p>{t('defaultPositions.noBranches')}</p>
        </div>
      {:else}
        <div class="branch-grid">
          {#each branches as branch}
            <button class="branch-card" on:click={() => selectBranch(branch.id)}>
              <span class="branch-card-icon">🏪</span>
              <span class="branch-card-name">{getBranchName(branch)}</span>
              <span class="branch-card-id">{t('defaultPositions.branchId')}: {branch.id}</span>
            </button>
          {/each}
        </div>
      {/if}
    </div>

  {:else}
    <!-- Selected Branch Header -->
    <div class="branch-header-bar">
      <div class="branch-header-info">
        <span class="bh-icon">🏪</span>
        <div>
          <div class="bh-name">{selectedBranchName}</div>
          <div class="bh-id">{t('defaultPositions.branchId')}: {selectedBranchId}</div>
        </div>
      </div>
      <button class="change-btn" on:click={changeBranch}>{t('defaultPositions.changeBranch')}</button>
    </div>

    <!-- Position Cards -->
    {#if isLoadingPositions}
      <div class="state-center">
        <div class="spinner"></div>
        <span>{t('defaultPositions.loadingPositions')}</span>
      </div>
    {:else}
      <div class="positions-grid">
        {#each positionRoles as role}
          <div class="position-card">
            <div class="pos-header">
              <span class="pos-icon">{role.icon}</span>
              <span class="pos-label">{t('defaultPositions.roles.' + role.labelKey)}</span>
              {#if !role.single}
                <span class="multi-chip">{t('defaultPositions.multiple')}</span>
              {/if}
            </div>

            <div class="pos-body">
              {#if role.single}
                {#if assignedUsers[role.key]}
                  <div class="assigned-row">
                    <div class="user-chip">
                      <span class="user-chip-avatar">👤</span>
                      <span class="user-chip-name">{getUserName(assignedUsers[role.key])}</span>
                    </div>
                    <div class="row-actions">
                      <button class="icon-btn blue" on:click={() => openUserPicker(role.key, role.labelKey, role.single)} title="Change">🔄</button>
                      <button class="icon-btn red"  on:click={() => removeUser(role.key)} title="Remove">✕</button>
                    </div>
                  </div>
                {:else}
                  <div class="no-assignment-row">
                    <span class="no-assign-text">{t('defaultPositions.noAssignment')}</span>
                    <button class="assign-btn" on:click={() => openUserPicker(role.key, role.labelKey, role.single)}>
                      {t('defaultPositions.assignUser')}
                    </button>
                  </div>
                {/if}
              {:else}
                {#if assignedUsers[role.key] && assignedUsers[role.key].length > 0}
                  <div class="multi-list">
                    {#each assignedUsers[role.key] as user}
                      <div class="assigned-row compact">
                        <div class="user-chip">
                          <span class="user-chip-avatar">👤</span>
                          <span class="user-chip-name">{getUserName(user)}</span>
                        </div>
                        <button class="icon-btn red" on:click={() => removeUser(role.key, user.id)} title="Remove">✕</button>
                      </div>
                    {/each}
                  </div>
                  <button class="assign-btn purple full-w" on:click={() => openUserPicker(role.key, role.labelKey, role.single)}>
                    {t('defaultPositions.addAnother')}
                  </button>
                {:else}
                  <div class="no-assignment-row">
                    <span class="no-assign-text">{t('defaultPositions.noAssignment')}</span>
                    <button class="assign-btn" on:click={() => openUserPicker(role.key, role.labelKey, role.single)}>
                      {t('defaultPositions.assignUser')}
                    </button>
                  </div>
                {/if}
              {/if}
            </div>
          </div>
        {/each}
      </div>

      <!-- Save Section -->
      <div class="save-bar">
        {#if saveSuccess}
          <div class="alert success">✅ {saveSuccess}</div>
        {/if}
        {#if saveError}
          <div class="alert error">❌ {saveError}</div>
        {/if}
        <button class="save-btn" on:click={saveDefaults} disabled={isSaving}>
          {#if isSaving}
            <div class="spinner-sm"></div> {t('defaultPositions.saving')}
          {:else}
            💾 {t('defaultPositions.saveDefaults')}
          {/if}
        </button>
      </div>
    {/if}
  {/if}
</div>

<!-- User Picker Modal -->
{#if showUserPicker}
  <div class="modal-overlay" on:click={closeUserPicker}>
    <div class="picker-modal" on:click|stopPropagation>
      <div class="picker-header">
        <h3>{t('defaultPositions.roles.' + pickerRoleLabelKey)}</h3>
        <button class="close-btn" on:click={closeUserPicker}>✕</button>
      </div>

      <div class="picker-search">
        <span class="search-icon">🔍</span>
        <input
          type="text"
          placeholder={t('defaultPositions.searchUsers')}
          bind:value={userSearchQuery}
          class="picker-input"
        />
        {#if userSearchQuery}
          <button class="clear-x" on:click={() => userSearchQuery = ''}>✕</button>
        {/if}
      </div>

      <div class="picker-body">
        {#if isLoadingUsers}
          <div class="state-center">
            <div class="spinner"></div>
            <span>{t('defaultPositions.loadingUsers')}</span>
          </div>
        {:else if filteredUsers.length === 0}
          <div class="state-center muted">
            <span>🔍</span>
            <p>{t('defaultPositions.noUsers')}</p>
          </div>
        {:else}
          <div class="results-info">
            {t('defaultPositions.showingUsers', { shown: filteredUsers.length, total: allUsers.length })}
          </div>
          {#each filteredUsers as user}
            {@const alreadySelected = isUserAlreadySelected(user.id)}
            <button
              class="user-row"
              class:already-selected={alreadySelected}
              on:click={() => !alreadySelected && selectUser(user)}
              disabled={alreadySelected}
            >
              <span class="ur-avatar">👤</span>
              <div class="ur-info">
                <span class="ur-name">{getUserName(user)}</span>
                <span class="ur-id">{user.username}</span>
              </div>
              {#if alreadySelected}
                <span class="selected-tag">{t('defaultPositions.selected')}</span>
              {/if}
            </button>
          {/each}
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  /* ===================== CONTAINER ===================== */
  .dp-container {
    padding: 0.75rem 1rem;
    height: 100%;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    background: linear-gradient(135deg, #e8f0fe 0%, #f0f7ff 50%, #e8f4f8 100%);
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  }

  /* ===================== BRANCH SELECTION ===================== */
  .branch-selection-card {
    background: rgba(255, 255, 255, 0.72);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 14px;
    padding: 1.25rem;
    box-shadow: 0 4px 20px rgba(59, 130, 246, 0.08);
  }

  .section-label {
    font-weight: 700;
    font-size: 1rem;
    color: #1e293b;
    margin-bottom: 1rem;
  }

  .branch-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
    gap: 0.75rem;
  }

  .branch-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.4rem;
    padding: 1rem 0.75rem;
    background: rgba(255, 255, 255, 0.7);
    border: 1.5px solid rgba(0, 0, 0, 0.08);
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s;
  }
  .branch-card:hover {
    border-color: #3b82f6;
    background: #eff6ff;
    transform: translateY(-2px);
    box-shadow: 0 4px 14px rgba(59, 130, 246, 0.15);
  }
  .branch-card-icon { font-size: 1.8rem; }
  .branch-card-name { font-weight: 600; font-size: 0.88rem; color: #1e293b; text-align: center; }
  .branch-card-id  { font-size: 0.72rem; color: #94a3b8; }

  /* ===================== BRANCH HEADER BAR ===================== */
  .branch-header-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(255, 255, 255, 0.72);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 14px;
    padding: 0.75rem 1.25rem;
    box-shadow: 0 4px 20px rgba(59, 130, 246, 0.08);
    flex-shrink: 0;
  }
  .branch-header-info { display: flex; align-items: center; gap: 0.75rem; }
  .bh-icon { font-size: 1.6rem; }
  .bh-name { font-weight: 700; font-size: 1rem; color: #1e293b; }
  .bh-id  { font-size: 0.75rem; color: #94a3b8; }

  .change-btn {
    padding: 0.4rem 0.9rem;
    background: rgba(255, 255, 255, 0.8);
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.82rem;
    color: #475569;
    font-weight: 500;
    transition: all 0.2s;
  }
  .change-btn:hover { background: #f1f5f9; border-color: #94a3b8; }

  /* ===================== POSITIONS GRID ===================== */
  .positions-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 0.75rem;
  }

  .position-card {
    background: rgba(255, 255, 255, 0.75);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(59, 130, 246, 0.06);
    transition: box-shadow 0.2s;
  }
  .position-card:hover { box-shadow: 0 4px 18px rgba(59, 130, 246, 0.12); }

  .pos-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.6rem 0.9rem;
    background: rgba(241, 245, 249, 0.9);
    border-bottom: 1px solid #e2e8f0;
  }
  .pos-icon  { font-size: 1.15rem; }
  .pos-label { font-weight: 600; font-size: 0.88rem; color: #1e293b; flex: 1; }
  .multi-chip {
    font-size: 0.68rem;
    background: #ede9fe;
    color: #7c3aed;
    border: 1px solid #ddd6fe;
    padding: 0.12rem 0.45rem;
    border-radius: 10px;
    font-weight: 600;
  }

  .pos-body { padding: 0.75rem; }

  /* Assigned row */
  .assigned-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.45rem 0.6rem;
    background: #f0fdf4;
    border: 1px solid #bbf7d0;
    border-radius: 8px;
  }
  .assigned-row.compact { margin-bottom: 0.4rem; }

  .user-chip {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .user-chip-avatar { font-size: 1rem; }
  .user-chip-name {
    font-weight: 600;
    font-size: 0.84rem;
    color: #166534;
  }

  .row-actions { display: flex; gap: 0.25rem; }

  .icon-btn {
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.8rem;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
    font-weight: 600;
  }
  .icon-btn.blue { background: #dbeafe; color: #1d4ed8; }
  .icon-btn.blue:hover { background: #bfdbfe; }
  .icon-btn.red  { background: #fee2e2; color: #dc2626; }
  .icon-btn.red:hover  { background: #fecaca; }

  /* No assignment */
  .no-assignment-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.55rem 0.7rem;
    background: #fffbeb;
    border: 1px dashed #fde68a;
    border-radius: 8px;
  }
  .no-assign-text { color: #92400e; font-size: 0.82rem; font-style: italic; }

  .assign-btn {
    padding: 0.35rem 0.7rem;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.8rem;
    font-weight: 600;
    transition: background 0.2s;
    white-space: nowrap;
  }
  .assign-btn:hover  { background: #2563eb; }
  .assign-btn.purple { background: #7c3aed; }
  .assign-btn.purple:hover { background: #6d28d9; }
  .assign-btn.full-w { width: 100%; margin-top: 0.4rem; justify-content: center; display: flex; }

  .multi-list { display: flex; flex-direction: column; max-height: 200px; overflow-y: auto; }

  /* ===================== SAVE BAR ===================== */
  .save-bar {
    background: rgba(255, 255, 255, 0.72);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 14px;
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.6rem;
    box-shadow: 0 4px 20px rgba(59, 130, 246, 0.08);
    flex-shrink: 0;
  }

  .alert {
    padding: 0.45rem 1rem;
    border-radius: 8px;
    font-size: 0.88rem;
    font-weight: 500;
  }
  .alert.success { background: #f0fdf4; color: #166534; border: 1px solid #bbf7d0; }
  .alert.error   { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }

  .save-btn {
    padding: 0.55rem 1.75rem;
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.9rem;
    font-weight: 700;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    box-shadow: 0 2px 8px rgba(16, 185, 129, 0.22);
  }
  .save-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #059669, #047857);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.32);
  }
  .save-btn:disabled { opacity: 0.55; cursor: not-allowed; }

  /* ===================== STATE HELPERS ===================== */
  .state-center {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 2rem;
    color: #64748b;
    font-size: 0.88rem;
  }
  .state-center.muted { color: #94a3b8; }
  .state-center span:first-child { font-size: 2rem; }

  .spinner {
    width: 22px; height: 22px;
    border: 3px solid #e2e8f0;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  .spinner-sm {
    width: 14px; height: 14px;
    border: 2px solid rgba(255,255,255,0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  /* ===================== PICKER MODAL ===================== */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.4);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
  }

  .picker-modal {
    background: rgba(255, 255, 255, 0.97);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 16px;
    width: 90%;
    max-width: 480px;
    max-height: 78vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
    overflow: hidden;
  }

  .picker-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.9rem 1.25rem;
    border-bottom: 1px solid #f1f5f9;
  }
  .picker-header h3 { margin: 0; font-size: 1rem; font-weight: 700; color: #1e293b; }

  .close-btn {
    width: 30px; height: 30px;
    border: none;
    background: #f8fafc;
    border-radius: 7px;
    cursor: pointer;
    font-size: 0.9rem;
    color: #64748b;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
  }
  .close-btn:hover { background: #fee2e2; color: #dc2626; }

  .picker-search {
    position: relative;
    padding: 0.65rem 1rem;
    border-bottom: 1px solid #f1f5f9;
    display: flex;
    align-items: center;
  }
  .search-icon {
    position: absolute;
    left: 1.6rem;
    color: #94a3b8;
    font-size: 0.85rem;
    pointer-events: none;
  }
  .picker-input {
    width: 100%;
    padding: 0.45rem 2rem 0.45rem 2rem;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.85rem;
    outline: none;
    background: #f8fafc;
    color: #1e293b;
    transition: border-color 0.2s;
  }
  .picker-input:focus { border-color: #3b82f6; background: white; box-shadow: 0 0 0 2px rgba(59,130,246,0.1); }
  .picker-input::placeholder { color: #b0bec5; }
  .clear-x {
    position: absolute;
    right: 1.6rem;
    border: none;
    background: none;
    color: #94a3b8;
    cursor: pointer;
    font-size: 0.9rem;
    line-height: 1;
  }
  .clear-x:hover { color: #dc2626; }

  .picker-body { flex: 1; overflow-y: auto; padding: 0.4rem; }

  .results-info {
    font-size: 0.72rem;
    color: #94a3b8;
    padding: 0.2rem 0.7rem 0.4rem;
  }

  .user-row {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    padding: 0.55rem 0.75rem;
    border: none;
    background: transparent;
    cursor: pointer;
    text-align: left;
    width: 100%;
    border-radius: 8px;
    transition: background 0.15s;
  }
  .user-row:hover:not(:disabled) { background: #eff6ff; }
  .user-row.already-selected { background: #f0fdf4; opacity: 0.75; cursor: default; }
  .user-row:disabled { cursor: default; }

  .ur-avatar { font-size: 1rem; }
  .ur-info { display: flex; flex-direction: column; flex: 1; }
  .ur-name { font-weight: 600; font-size: 0.86rem; color: #1e293b; }
  .ur-id   { font-size: 0.72rem; color: #94a3b8; }

  .selected-tag { font-size: 0.72rem; color: #059669; font-weight: 700; }

  /* ===================== RESPONSIVE ===================== */
  @media (max-width: 600px) {
    .dp-container { padding: 0.5rem; }
    .positions-grid { grid-template-columns: 1fr; }
    .branch-grid { grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); }
  }
</style>
