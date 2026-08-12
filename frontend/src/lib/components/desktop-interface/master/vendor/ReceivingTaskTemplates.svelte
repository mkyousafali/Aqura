<!-- ReceivingTaskTemplates.svelte -->
<!-- View/create/edit receiving_task_templates (no schema changes) -->
<script lang="ts">
  import { supabase } from '$lib/utils/supabase';
  import { onMount } from 'svelte';
  import { locale } from '$lib/i18n';

  const ALL_ROLES = [
    { value: 'branch_manager',    icon: '👔', en: 'Branch Manager',    ar: 'مدير الفرع' },
    { value: 'purchase_manager',  icon: '🛒', en: 'Purchase Manager',  ar: 'مدير المشتريات' },
    { value: 'inventory_manager', icon: '📦', en: 'Inventory Manager', ar: 'مدير المخزون' },
    { value: 'night_supervisor',  icon: '🌙', en: 'Night Supervisor',  ar: 'المشرف الليلي' },
    { value: 'warehouse_handler', icon: '🏭', en: 'Warehouse Handler', ar: 'مسؤول المستودع' },
    { value: 'shelf_stocker',     icon: '🗄️', en: 'Shelf Stocker',     ar: 'مسؤول ترتيب الأرفف' },
    { value: 'accountant',        icon: '💰', en: 'Accountant',        ar: 'المحاسب' }
  ];

  const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

  let templates: any[] = [];
  let isLoading = false;
  let loadError = '';

  let showForm = false;
  let isEditing = false;
  let isSaving = false;
  let saveError = '';
  let saveSuccess = '';

  // form state
  let formId: string | null = null;
  let formRoleType = '';
  let formTitleEn = '';
  let formTitleAr = '';
  let formDescEn = '';
  let formDescAr = '';
  let formPriority = 'high';
  let formDeadlineHours = 24;
  let formRequireErp = false;
  let formRequireBill = false;
  let formRequireFinishedMark = true;
  let formRequirePhoto = false;
  let formDependsOn: string[] = [];

  $: isRTL = $locale === 'ar';
  $: usedRoleTypes = new Set(templates.map(t => t.role_type));
  $: availableRolesForCreate = ALL_ROLES.filter(r => !usedRoleTypes.has(r.value));

  onMount(async () => {
    await loadTemplates();
  });

  async function loadTemplates() {
    try {
      isLoading = true;
      loadError = '';
      const { data, error } = await supabase
        .from('receiving_task_templates')
        .select('*')
        .order('role_type');
      if (error) throw error;
      templates = data || [];
    } catch (err: any) {
      console.error('Error loading receiving task templates:', err);
      loadError = err.message;
    } finally {
      isLoading = false;
    }
  }

  function roleMeta(roleType: string) {
    return ALL_ROLES.find(r => r.value === roleType) || { value: roleType, icon: '📋', en: roleType, ar: roleType };
  }

  function roleLabel(roleType: string) {
    const meta = roleMeta(roleType);
    return isRTL ? meta.ar : meta.en;
  }

  function splitBilingual(value: string | null): { en: string; ar: string } {
    if (!value) return { en: '', ar: '' };
    const parts = value.split('|||');
    return { en: parts[0] || '', ar: parts[1] || '' };
  }

  function joinBilingual(en: string, ar: string): string {
    return `${en}|||${ar}`;
  }

  function openCreateForm() {
    isEditing = false;
    formId = null;
    formRoleType = availableRolesForCreate[0]?.value || '';
    formTitleEn = '';
    formTitleAr = '';
    formDescEn = '';
    formDescAr = '';
    formPriority = 'high';
    formDeadlineHours = 24;
    formRequireErp = false;
    formRequireBill = false;
    formRequireFinishedMark = true;
    formRequirePhoto = false;
    formDependsOn = [];
    saveError = '';
    saveSuccess = '';
    showForm = true;
  }

  function openEditForm(template: any) {
    isEditing = true;
    formId = template.id;
    formRoleType = template.role_type;
    const title = splitBilingual(template.title_template);
    const desc = splitBilingual(template.description_template);
    formTitleEn = title.en;
    formTitleAr = title.ar;
    formDescEn = desc.en;
    formDescAr = desc.ar;
    formPriority = template.priority || 'high';
    formDeadlineHours = template.deadline_hours || 24;
    formRequireErp = !!template.require_erp_reference;
    formRequireBill = !!template.require_original_bill_upload;
    formRequireFinishedMark = template.require_task_finished_mark !== false;
    formRequirePhoto = !!template.require_photo_upload;
    formDependsOn = Array.isArray(template.depends_on_role_types) ? [...template.depends_on_role_types] : [];
    saveError = '';
    saveSuccess = '';
    showForm = true;
  }

  function closeForm() {
    showForm = false;
  }

  function toggleDependsOn(roleValue: string) {
    if (formDependsOn.includes(roleValue)) {
      formDependsOn = formDependsOn.filter(r => r !== roleValue);
    } else {
      formDependsOn = [...formDependsOn, roleValue];
    }
  }

  async function saveTemplate() {
    if (!formRoleType) {
      saveError = 'Please select a role type';
      return;
    }
    if (!formTitleEn.trim() || !formDescEn.trim()) {
      saveError = 'Title and description (English) are required';
      return;
    }
    try {
      isSaving = true;
      saveError = '';
      const payload: any = {
        role_type: formRoleType,
        title_template: joinBilingual(formTitleEn.trim(), formTitleAr.trim()),
        description_template: joinBilingual(formDescEn.trim(), formDescAr.trim()),
        priority: formPriority,
        deadline_hours: formDeadlineHours,
        require_erp_reference: formRequireErp,
        require_original_bill_upload: formRequireBill,
        require_task_finished_mark: formRequireFinishedMark,
        require_photo_upload: formRequirePhoto,
        depends_on_role_types: formDependsOn
      };

      if (isEditing && formId) {
        const { error } = await supabase
          .from('receiving_task_templates')
          .update(payload)
          .eq('id', formId);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('receiving_task_templates')
          .insert(payload);
        if (error) throw error;
      }

      saveSuccess = isEditing ? 'Template updated ✅' : 'Template created ✅';
      await loadTemplates();
      showForm = false;
    } catch (err: any) {
      console.error('Error saving template:', err);
      saveError = err.message;
    } finally {
      isSaving = false;
    }
  }
</script>

<div class="rtt-container">
  <div class="rtt-header">
    <div class="rtt-title">📋 {isRTL ? 'قوالب مهام الاستلام' : 'Receiving Task Templates'}</div>
    <button class="add-btn" on:click={openCreateForm} disabled={availableRolesForCreate.length === 0}>
      ➕ {isRTL ? 'إضافة قالب' : 'Add Template'}
    </button>
  </div>

  {#if loadError}
    <div class="alert error">❌ {loadError}</div>
  {/if}

  {#if isLoading}
    <div class="state-center">
      <div class="spinner"></div>
      <span>{isRTL ? 'جارٍ التحميل...' : 'Loading...'}</span>
    </div>
  {:else if templates.length === 0}
    <div class="state-center muted">
      <span>📭</span>
      <p>{isRTL ? 'لا توجد قوالب بعد' : 'No templates yet'}</p>
    </div>
  {:else}
    <div class="templates-grid">
      {#each templates as template (template.id)}
        {@const meta = roleMeta(template.role_type)}
        {@const title = splitBilingual(template.title_template)}
        <div class="template-card">
          <div class="tc-header">
            <span class="tc-icon">{meta.icon}</span>
            <span class="tc-role">{roleLabel(template.role_type)}</span>
            <span class="priority-chip priority-{template.priority}">{template.priority}</span>
          </div>
          <div class="tc-body">
            <div class="tc-title">{isRTL ? (title.ar || title.en) : title.en}</div>
            <div class="tc-meta-row">
              <span class="tc-meta">⏱️ {template.deadline_hours}h</span>
              {#if template.require_erp_reference}<span class="tc-flag">ERP</span>{/if}
              {#if template.require_original_bill_upload}<span class="tc-flag">Bill</span>{/if}
              {#if template.require_photo_upload}<span class="tc-flag">Photo</span>{/if}
            </div>
            {#if template.depends_on_role_types && template.depends_on_role_types.length > 0}
              <div class="tc-depends">
                {isRTL ? 'يعتمد على:' : 'Depends on:'}
                {#each template.depends_on_role_types as dep}
                  <span class="dep-chip">{roleLabel(dep)}</span>
                {/each}
              </div>
            {/if}
          </div>
          <div class="tc-footer">
            <button class="edit-btn" on:click={() => openEditForm(template)}>✏️ {isRTL ? 'تعديل' : 'Edit'}</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<!-- Create/Edit Modal -->
{#if showForm}
  <div class="modal-overlay" on:click={closeForm}>
    <div class="form-modal" on:click|stopPropagation>
      <div class="form-header">
        <h3>{isEditing ? (isRTL ? 'تعديل القالب' : 'Edit Template') : (isRTL ? 'قالب جديد' : 'New Template')}</h3>
        <button class="close-btn" on:click={closeForm}>✕</button>
      </div>

      <div class="form-body">
        {#if saveError}
          <div class="alert error">❌ {saveError}</div>
        {/if}

        <label class="field-label">{isRTL ? 'نوع الدور' : 'Role Type'}</label>
        {#if isEditing}
          <div class="readonly-value">{roleMeta(formRoleType).icon} {roleLabel(formRoleType)}</div>
        {:else}
          <select class="field-input" bind:value={formRoleType}>
            {#each availableRolesForCreate as role}
              <option value={role.value}>{role.icon} {isRTL ? role.ar : role.en}</option>
            {/each}
          </select>
        {/if}

        <div class="field-row">
          <div class="field-col">
            <label class="field-label">Title (English)</label>
            <input class="field-input" type="text" bind:value={formTitleEn} placeholder="Task title in English" />
          </div>
          <div class="field-col">
            <label class="field-label">العنوان (عربي)</label>
            <input class="field-input" type="text" bind:value={formTitleAr} placeholder="عنوان المهمة بالعربية" dir="rtl" />
          </div>
        </div>

        <div class="field-row">
          <div class="field-col">
            <label class="field-label">Description (English)</label>
            <textarea class="field-input" rows="4" bind:value={formDescEn} placeholder="Task description in English"></textarea>
          </div>
          <div class="field-col">
            <label class="field-label">الوصف (عربي)</label>
            <textarea class="field-input" rows="4" bind:value={formDescAr} placeholder="وصف المهمة بالعربية" dir="rtl"></textarea>
          </div>
        </div>

        <div class="field-row">
          <div class="field-col">
            <label class="field-label">{isRTL ? 'الأولوية' : 'Priority'}</label>
            <select class="field-input" bind:value={formPriority}>
              {#each PRIORITIES as p}
                <option value={p}>{p}</option>
              {/each}
            </select>
          </div>
          <div class="field-col">
            <label class="field-label">{isRTL ? 'المهلة (ساعات)' : 'Deadline (hours)'}</label>
            <input class="field-input" type="number" min="1" max="168" bind:value={formDeadlineHours} />
          </div>
        </div>

        <label class="field-label">{isRTL ? 'المتطلبات' : 'Requirements'}</label>
        <div class="checkbox-grid">
          <label class="checkbox-item">
            <input type="checkbox" bind:checked={formRequireErp} />
            {isRTL ? 'مرجع ERP' : 'ERP Reference'}
          </label>
          <label class="checkbox-item">
            <input type="checkbox" bind:checked={formRequireBill} />
            {isRTL ? 'رفع الفاتورة الأصلية' : 'Original Bill Upload'}
          </label>
          <label class="checkbox-item">
            <input type="checkbox" bind:checked={formRequirePhoto} />
            {isRTL ? 'رفع صورة' : 'Photo Upload'}
          </label>
          <label class="checkbox-item">
            <input type="checkbox" bind:checked={formRequireFinishedMark} />
            {isRTL ? 'علامة الإنجاز' : 'Finished Mark'}
          </label>
        </div>

        <label class="field-label">{isRTL ? 'يعتمد على أدوار أخرى' : 'Depends on other roles'}</label>
        <div class="checkbox-grid">
          {#each ALL_ROLES.filter(r => r.value !== formRoleType) as role}
            <label class="checkbox-item">
              <input
                type="checkbox"
                checked={formDependsOn.includes(role.value)}
                on:change={() => toggleDependsOn(role.value)}
              />
              {role.icon} {isRTL ? role.ar : role.en}
            </label>
          {/each}
        </div>
      </div>

      <div class="form-footer">
        <button class="cancel-btn" on:click={closeForm}>{isRTL ? 'إلغاء' : 'Cancel'}</button>
        <button class="save-btn" on:click={saveTemplate} disabled={isSaving}>
          {#if isSaving}
            <div class="spinner-sm"></div> {isRTL ? 'جارٍ الحفظ...' : 'Saving...'}
          {:else}
            💾 {isRTL ? 'حفظ' : 'Save'}
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .rtt-container {
    padding: 0.75rem 1rem;
    height: 100%;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    background: linear-gradient(135deg, #e8f0fe 0%, #f0f7ff 50%, #e8f4f8 100%);
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  }

  .rtt-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: rgba(255, 255, 255, 0.72);
    backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 14px;
    padding: 0.75rem 1.25rem;
    box-shadow: 0 4px 20px rgba(59, 130, 246, 0.08);
  }
  .rtt-title { font-weight: 700; font-size: 1rem; color: #1e293b; }

  .add-btn {
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 600;
  }
  .add-btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .templates-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 0.75rem;
  }

  .template-card {
    background: rgba(255, 255, 255, 0.75);
    backdrop-filter: blur(16px);
    border: 1px solid rgba(255, 255, 255, 0.9);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(59, 130, 246, 0.06);
    display: flex;
    flex-direction: column;
  }

  .tc-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.6rem 0.9rem;
    background: rgba(241, 245, 249, 0.9);
    border-bottom: 1px solid #e2e8f0;
  }
  .tc-icon { font-size: 1.15rem; }
  .tc-role { font-weight: 600; font-size: 0.88rem; color: #1e293b; flex: 1; }

  .priority-chip {
    font-size: 0.68rem;
    padding: 0.12rem 0.5rem;
    border-radius: 10px;
    font-weight: 700;
    text-transform: uppercase;
  }
  .priority-low { background: #f1f5f9; color: #64748b; }
  .priority-medium { background: #fef9c3; color: #a16207; }
  .priority-high { background: #fee2e2; color: #dc2626; }
  .priority-urgent { background: #7c2d12; color: white; }

  .tc-body { padding: 0.75rem; flex: 1; }
  .tc-title { font-weight: 600; font-size: 0.86rem; color: #1e293b; margin-bottom: 0.5rem; }
  .tc-meta-row { display: flex; gap: 0.4rem; flex-wrap: wrap; margin-bottom: 0.4rem; }
  .tc-meta { font-size: 0.75rem; color: #64748b; }
  .tc-flag {
    font-size: 0.68rem;
    background: #dbeafe;
    color: #1d4ed8;
    padding: 0.1rem 0.4rem;
    border-radius: 6px;
    font-weight: 600;
  }
  .tc-depends { font-size: 0.75rem; color: #7c3aed; display: flex; gap: 0.3rem; flex-wrap: wrap; align-items: center; }
  .dep-chip {
    background: #ede9fe;
    border: 1px solid #ddd6fe;
    padding: 0.1rem 0.4rem;
    border-radius: 8px;
    font-size: 0.7rem;
  }

  .tc-footer { padding: 0.5rem 0.75rem; border-top: 1px solid #e2e8f0; }
  .edit-btn {
    width: 100%;
    padding: 0.4rem;
    background: #eff6ff;
    color: #1d4ed8;
    border: 1px solid #bfdbfe;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.8rem;
    font-weight: 600;
  }
  .edit-btn:hover { background: #dbeafe; }

  .state-center {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding: 2rem;
    color: #64748b;
  }
  .state-center.muted { color: #94a3b8; }
  .spinner {
    width: 28px; height: 28px;
    border: 3px solid #dbeafe;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  .spinner-sm {
    width: 14px; height: 14px;
    border: 2px solid rgba(255,255,255,0.4);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    display: inline-block;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .alert {
    padding: 0.45rem 1rem;
    border-radius: 8px;
    font-size: 0.88rem;
    font-weight: 500;
  }
  .alert.error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }

  /* Modal */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  .form-modal {
    background: white;
    border-radius: 14px;
    width: 90%;
    max-width: 640px;
    max-height: 85vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
  }
  .form-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #e2e8f0;
  }
  .form-header h3 { margin: 0; font-size: 1.05rem; color: #1e293b; }
  .close-btn {
    background: none; border: none; font-size: 1.1rem; cursor: pointer; color: #64748b;
  }
  .form-body { padding: 1rem 1.25rem; overflow-y: auto; flex: 1; }
  .form-footer {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    padding: 1rem 1.25rem;
    border-top: 1px solid #e2e8f0;
  }

  .field-label {
    display: block;
    font-weight: 600;
    font-size: 0.82rem;
    color: #475569;
    margin: 0.75rem 0 0.35rem;
  }
  .field-input {
    width: 100%;
    padding: 0.5rem 0.65rem;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    font-size: 0.85rem;
    box-sizing: border-box;
    font-family: inherit;
  }
  .readonly-value {
    padding: 0.5rem 0.65rem;
    background: #f1f5f9;
    border-radius: 8px;
    font-size: 0.85rem;
    color: #475569;
  }
  .field-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }
  .checkbox-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 0.5rem;
  }
  .checkbox-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.82rem;
    color: #334155;
  }

  .cancel-btn {
    padding: 0.5rem 1.1rem;
    background: #f1f5f9;
    color: #475569;
    border: 1px solid #cbd5e1;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 600;
  }
  .save-btn {
    padding: 0.5rem 1.4rem;
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .save-btn:disabled { opacity: 0.6; cursor: not-allowed; }
</style>
