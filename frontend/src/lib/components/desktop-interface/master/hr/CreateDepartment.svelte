<script lang="ts">
	import { onMount } from 'svelte';
	import { t, currentLocale } from '$lib/i18n';

	let supabase: any = null;

	let departments: any[] = [];
	let loading = false;
	let saving = false;
	let error = '';
	let successMsg = '';

	let search = '';
	let page = 1;
	const LIMIT = 20;

	// Form state
	let isEditing = false;
	let editId: string | null = null;
	let nameEn = '';
	let nameAr = '';
	let isActive = true;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadDepartments();
	});

	async function loadDepartments() {
		loading = true;
		error = '';
		try {
			const { data, error: err } = await supabase.rpc('get_hr_departments_list', {
				p_search: search.trim(),
				p_page: page,
				p_limit: LIMIT
			});
			if (err) throw err;
			departments = data || [];
		} catch (e: any) {
			error = e.message || 'Failed to load departments';
		} finally {
			loading = false;
		}
	}

	async function save() {
		if (!nameEn.trim() || !nameAr.trim()) {
			error = $currentLocale === 'ar' ? 'يرجى ملء جميع الحقول' : 'Please fill all fields';
			return;
		}
		saving = true;
		error = '';
		successMsg = '';
		try {
			const args: any = {
				p_name_en: nameEn.trim(),
				p_name_ar: nameAr.trim(),
				p_is_active: isActive
			};
			if (!isEditing) {
				// new
			} else {
				args.p_id = editId;
			}
			const { error: err } = await supabase.rpc('upsert_hr_department', args);
			if (err) throw err;
			successMsg = $currentLocale === 'ar' ? 'تم الحفظ بنجاح' : 'Saved successfully';
			resetForm();
			await loadDepartments();
		} catch (e: any) {
			error = e.message || 'Failed to save';
		} finally {
			saving = false;
		}
	}

	function editDepartment(dept: any) {
		isEditing = true;
		editId = dept.id;
		nameEn = dept.department_name_en || '';
		nameAr = dept.department_name_ar || '';
		isActive = dept.is_active ?? true;
		error = '';
		successMsg = '';
	}

	function resetForm() {
		isEditing = false;
		editId = null;
		nameEn = '';
		nameAr = '';
		isActive = true;
		error = '';
	}

	$: isRTL = $currentLocale === 'ar';
</script>

<div class="create-dept" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Form -->
	<div class="section-card">
		<h3 class="section-title">{isEditing ? (isRTL ? 'تعديل القسم' : 'Edit Department') : (isRTL ? 'إنشاء قسم جديد' : 'Create New Department')}</h3>

		{#if error}
			<div class="msg error">{error}</div>
		{/if}
		{#if successMsg}
			<div class="msg success">{successMsg}</div>
		{/if}

		<div class="form-grid">
			<div class="field">
				<label>{isRTL ? 'الاسم (إنجليزي)' : 'Name (English)'}</label>
				<input bind:value={nameEn} placeholder="e.g. Human Resources" class="input" />
			</div>
			<div class="field">
				<label>{isRTL ? 'الاسم (عربي)' : 'Name (Arabic)'}</label>
				<input bind:value={nameAr} placeholder="مثال: الموارد البشرية" class="input" dir="rtl" />
			</div>
		</div>

		<div class="checkbox-row">
			<input type="checkbox" id="isActive" bind:checked={isActive} />
			<label for="isActive">{isRTL ? 'نشط' : 'Active'}</label>
		</div>

		<div class="btn-row">
			<button class="btn-primary" on:click={save} disabled={saving}>
				{saving ? (isRTL ? 'جاري الحفظ...' : 'Saving...') : (isEditing ? (isRTL ? 'تحديث' : 'Update') : (isRTL ? 'إنشاء' : 'Create'))}
			</button>
			{#if isEditing}
				<button class="btn-secondary" on:click={resetForm}>{isRTL ? 'إلغاء' : 'Cancel'}</button>
			{/if}
		</div>
	</div>

	<!-- List -->
	<div class="section-card">
		<div class="list-header">
			<h3 class="section-title">{isRTL ? 'الأقسام' : 'Departments'}</h3>
			<input bind:value={search} on:input={() => { page = 1; loadDepartments(); }} placeholder={isRTL ? 'بحث...' : 'Search...'} class="input search-input" />
		</div>

		{#if loading}
			<div class="loading">{isRTL ? 'جاري التحميل...' : 'Loading...'}</div>
		{:else if departments.length === 0}
			<div class="empty">{isRTL ? 'لا توجد أقسام' : 'No departments found'}</div>
		{:else}
			<table class="table">
				<thead>
					<tr>
						<th>{isRTL ? 'الاسم (إنجليزي)' : 'Name (EN)'}</th>
						<th>{isRTL ? 'الاسم (عربي)' : 'Name (AR)'}</th>
						<th>{isRTL ? 'الحالة' : 'Status'}</th>
						<th>{isRTL ? 'إجراء' : 'Action'}</th>
					</tr>
				</thead>
				<tbody>
					{#each departments as dept}
						<tr>
							<td>{dept.department_name_en}</td>
							<td dir="rtl">{dept.department_name_ar}</td>
							<td><span class="badge" class:active={dept.is_active}>{dept.is_active ? (isRTL ? 'نشط' : 'Active') : (isRTL ? 'غير نشط' : 'Inactive')}</span></td>
							<td><button class="btn-edit" on:click={() => editDepartment(dept)}>{isRTL ? 'تعديل' : 'Edit'}</button></td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<style>
	.create-dept {
		padding: 1.25rem;
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
		background: #0f172a;
		min-height: 100%;
		color: #e2e8f0;
	}

	.section-card {
		background: #1e293b;
		border-radius: 10px;
		padding: 1.25rem;
		border: 1px solid #334155;
	}

	.section-title {
		font-size: 1rem;
		font-weight: 600;
		color: #f1f5f9;
		margin: 0 0 1rem;
	}

	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.field {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}

	.field label {
		font-size: 0.8rem;
		color: #94a3b8;
		font-weight: 500;
	}

	.input {
		background: #0f172a;
		border: 1px solid #334155;
		border-radius: 6px;
		color: #e2e8f0;
		padding: 0.5rem 0.75rem;
		font-size: 0.9rem;
		outline: none;
		transition: border-color 0.15s;
	}

	.input:focus {
		border-color: #6366f1;
	}

	.search-input {
		width: 220px;
	}

	.checkbox-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-top: 0.75rem;
		font-size: 0.9rem;
		color: #94a3b8;
	}

	.btn-row {
		display: flex;
		gap: 0.75rem;
		margin-top: 1rem;
	}

	.btn-primary {
		background: #6366f1;
		color: #fff;
		border: none;
		border-radius: 6px;
		padding: 0.5rem 1.25rem;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.15s;
	}

	.btn-primary:hover:not(:disabled) { background: #4f46e5; }
	.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }

	.btn-secondary {
		background: #334155;
		color: #e2e8f0;
		border: none;
		border-radius: 6px;
		padding: 0.5rem 1.25rem;
		font-size: 0.9rem;
		cursor: pointer;
	}

	.btn-secondary:hover { background: #475569; }

	.btn-edit {
		background: #1e3a5f;
		color: #60a5fa;
		border: 1px solid #2d5f9e;
		border-radius: 4px;
		padding: 0.25rem 0.6rem;
		font-size: 0.8rem;
		cursor: pointer;
	}

	.btn-edit:hover { background: #2d4a6f; }

	.msg {
		border-radius: 6px;
		padding: 0.5rem 0.75rem;
		font-size: 0.85rem;
		margin-bottom: 0.75rem;
	}

	.msg.error { background: rgba(239,68,68,0.15); color: #f87171; border: 1px solid rgba(239,68,68,0.3); }
	.msg.success { background: rgba(34,197,94,0.15); color: #4ade80; border: 1px solid rgba(34,197,94,0.3); }

	.list-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.table th {
		text-align: start;
		padding: 0.5rem 0.75rem;
		color: #64748b;
		font-weight: 500;
		border-bottom: 1px solid #334155;
	}

	.table td {
		padding: 0.6rem 0.75rem;
		border-bottom: 1px solid #1e293b;
		color: #cbd5e1;
	}

	.table tr:hover td { background: #1a2744; }

	.badge {
		padding: 0.2rem 0.5rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		background: #334155;
		color: #94a3b8;
	}

	.badge.active { background: rgba(34,197,94,0.15); color: #4ade80; }

	.loading, .empty {
		text-align: center;
		color: #64748b;
		padding: 2rem;
	}
</style>
