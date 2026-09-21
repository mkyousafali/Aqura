<script lang="ts">
	// Control Center > App Permissions > Default Entry Task Users.
	// One default ERP Entry Task assignee per branch, stored in the existing
	// branch_default_positions.entry_task_user_id column (UNIQUE(branch_id), so one row per branch
	// already). That row also holds the vendor-master position users, so removing a default only
	// nulls this one column -- it never deletes the row. The Send popup in ERP Ledgers reads this
	// value as its pre-selection; changing the assignee there does not write back here.
	import { onMount } from 'svelte';
	import { locale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { loadSelectableUsers, userDisplayName, type SelectableUser } from '$lib/utils/entryTaskUsers';
	import EntryTaskUserPicker from '$lib/components/desktop-interface/common/EntryTaskUserPicker.svelte';

	interface BranchRow {
		id: number;
		name_en: string;
		name_ar: string;
	}

	$: isArabic = $locale === 'ar';
	// Reactive so template calls re-render when the language is switched.
	$: L = (en: string, ar: string) => (isArabic ? ar : en);

	let branches: BranchRow[] = [];
	let users: SelectableUser[] = [];
	// branch_id -> user id, only for branches that currently have a default
	let defaults: Record<number, string> = {};

	let loading = true;
	let loadError = '';

	let showModal = false;
	let formBranchId: number | null = null;
	let formUserId: string | null = null;
	let saving = false;
	let formError = '';

	let successMessage = '';
	let successTimer: ReturnType<typeof setTimeout> | null = null;

	$: userById = new Map(users.map((u) => [u.id, u]));
	$: configuredRows = branches
		.filter((b) => defaults[b.id])
		.map((b) => ({ branch: b, userId: defaults[b.id] }));
	$: formCurrentUserId = formBranchId != null ? defaults[formBranchId] || null : null;

	onMount(loadAll);

	async function loadAll() {
		loading = true;
		loadError = '';
		try {
			const [branchRes, defaultsRes, userList] = await Promise.all([
				supabase.from('branches').select('id, name_en, name_ar').eq('is_active', true).order('name_en'),
				supabase.from('branch_default_positions').select('branch_id, entry_task_user_id'),
				loadSelectableUsers()
			]);
			if (branchRes.error) throw branchRes.error;
			if (defaultsRes.error) throw defaultsRes.error;
			branches = (branchRes.data || []) as BranchRow[];
			users = userList;
			const next: Record<number, string> = {};
			for (const row of defaultsRes.data || []) {
				if (row.entry_task_user_id) next[Number(row.branch_id)] = row.entry_task_user_id;
			}
			defaults = next;
		} catch (err: any) {
			console.error('Error loading default entry task users:', err);
			loadError = err.message || L('Failed to load', 'فشل التحميل');
		} finally {
			loading = false;
		}
	}

	function branchName(b: BranchRow): string {
		return (isArabic ? b.name_ar || b.name_en : b.name_en || b.name_ar) || `#${b.id}`;
	}

	function openModal(branchId: number | null = null) {
		formBranchId = branchId;
		formUserId = branchId != null ? defaults[branchId] || null : null;
		formError = '';
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		formBranchId = null;
		formUserId = null;
		formError = '';
		saving = false;
	}

	function onBranchChange() {
		// Switching branch in the form starts from that branch's current default (if any).
		formUserId = formBranchId != null ? defaults[formBranchId] || null : null;
		formError = '';
	}

	function flashSuccess(message: string) {
		successMessage = message;
		if (successTimer) clearTimeout(successTimer);
		successTimer = setTimeout(() => (successMessage = ''), 3000);
	}

	async function save() {
		if (formBranchId == null) {
			formError = L('Select a branch', 'اختر الفرع');
			return;
		}
		if (!formUserId) {
			formError = L('Select a user', 'اختر المستخدم');
			return;
		}
		saving = true;
		formError = '';
		try {
			// Upsert on the unique branch_id: only the columns sent are updated, so the position
			// users already saved on this branch's row are left untouched.
			const { error } = await supabase
				.from('branch_default_positions')
				.upsert({ branch_id: formBranchId, entry_task_user_id: formUserId }, { onConflict: 'branch_id' });
			if (error) throw error;
			const branch = branches.find((b) => b.id === formBranchId);
			await loadAll();
			closeModal();
			flashSuccess(L(`Default saved for ${branch ? branchName(branch) : ''}`, `تم حفظ المستخدم الافتراضي لـ ${branch ? branchName(branch) : ''}`));
		} catch (err: any) {
			console.error('Error saving default entry task user:', err);
			formError = err.message || L('Failed to save', 'فشل الحفظ');
		} finally {
			saving = false;
		}
	}

	async function removeDefault(branch: BranchRow) {
		if (!confirm(L(`Remove the default Entry Task user for ${branchName(branch)}?`, `إزالة المستخدم الافتراضي لمهام الإدخال في ${branchName(branch)}؟`))) return;
		try {
			const { error } = await supabase
				.from('branch_default_positions')
				.update({ entry_task_user_id: null })
				.eq('branch_id', branch.id);
			if (error) throw error;
			await loadAll();
			flashSuccess(L('Default removed', 'تمت إزالة المستخدم الافتراضي'));
		} catch (err: any) {
			console.error('Error removing default entry task user:', err);
			loadError = err.message || L('Failed to remove', 'فشلت الإزالة');
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden" dir={isArabic ? 'rtl' : 'ltr'}>
	<div class="flex items-center justify-between px-6 py-4 bg-white border-b border-slate-200">
		<div>
			<h2 class="text-lg font-black text-slate-800">{L('Default Entry Task Users', 'المستخدمون الافتراضيون لمهام الإدخال')}</h2>
			<p class="text-sm text-slate-500">
				{L(
					'The user pre-selected when an ERP Entry Task is sent for a branch. One default per branch; the sender can still pick someone else for an individual task.',
					'المستخدم المحدد مسبقاً عند إرسال مهمة إدخال ERP لفرع ما. مستخدم افتراضي واحد لكل فرع، ويمكن للمرسل اختيار مستخدم آخر لمهمة معينة.'
				)}
			</p>
		</div>
		<button
			type="button"
			class="w-10 h-10 rounded-full bg-red-500 hover:bg-red-600 text-white text-2xl font-bold shadow flex items-center justify-center disabled:opacity-50"
			title={L('Add default user', 'إضافة مستخدم افتراضي')}
			disabled={loading || branches.length === 0}
			on:click={() => openModal()}
		>+</button>
	</div>

	{#if successMessage}
		<div class="mx-6 mt-4 px-4 py-2 rounded-lg bg-green-50 border border-green-200 text-green-700 text-sm font-semibold">✅ {successMessage}</div>
	{/if}
	{#if loadError}
		<div class="mx-6 mt-4 px-4 py-2 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm font-semibold">{loadError}</div>
	{/if}

	<div class="flex-1 min-h-0 overflow-auto p-6">
		{#if loading}
			<div class="text-center text-slate-400 py-12">{L('Loading...', 'جارٍ التحميل...')}</div>
		{:else if configuredRows.length === 0}
			<div class="text-center text-slate-400 py-12">
				<div class="text-4xl mb-2">👤</div>
				<p class="font-semibold">{L('No default Entry Task users configured yet', 'لم يتم تحديد مستخدمين افتراضيين لمهام الإدخال بعد')}</p>
				<p class="text-sm">{L('Press + to assign one to a branch.', 'اضغط + لتعيين مستخدم لفرع.')}</p>
			</div>
		{:else}
			<div class="bg-white border border-slate-200 rounded-xl overflow-hidden">
				<table class="w-full text-sm">
					<thead class="bg-slate-50 text-slate-500 text-xs uppercase">
						<tr>
							<th class="px-4 py-3 text-start">{L('Branch', 'الفرع')}</th>
							<th class="px-4 py-3 text-start">{L('Default user', 'المستخدم الافتراضي')}</th>
							<th class="px-4 py-3 w-24"></th>
						</tr>
					</thead>
					<tbody>
						{#each configuredRows as row (row.branch.id)}
							{@const user = userById.get(row.userId)}
							<tr class="border-t border-slate-100">
								<td class="px-4 py-3 font-semibold text-slate-700">{branchName(row.branch)}</td>
								<td class="px-4 py-3 text-slate-700">
									{#if user}
										{userDisplayName(user, isArabic)}
										<span class="text-xs text-slate-400 ms-1">{user.username}</span>
									{:else}
										<span class="text-amber-600">{L('Inactive or unknown user', 'مستخدم غير نشط أو غير معروف')}</span>
									{/if}
								</td>
								<td class="px-4 py-3">
									<div class="flex items-center gap-1 justify-end">
										<button type="button" class="px-2 py-1 rounded hover:bg-slate-100" title={L('Change', 'تغيير')} on:click={() => openModal(row.branch.id)}>✏️</button>
										<button type="button" class="px-2 py-1 rounded hover:bg-red-50 text-red-500" title={L('Remove', 'إزالة')} on:click={() => removeDefault(row.branch)}>🗑️</button>
									</div>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</div>
</div>

{#if showModal}
	<div class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" on:click={closeModal}>
		<div class="bg-white rounded-xl shadow-2xl w-[480px] max-w-full" dir={isArabic ? 'rtl' : 'ltr'} on:click|stopPropagation>
			<div class="flex items-center justify-between px-5 py-4 border-b border-slate-200">
				<h3 class="font-black text-slate-800">{L('Set default Entry Task user', 'تحديد المستخدم الافتراضي لمهام الإدخال')}</h3>
				<button type="button" class="text-slate-400 hover:text-slate-600" on:click={closeModal}>✕</button>
			</div>

			<div class="p-5 flex flex-col gap-4">
				<div class="flex flex-col gap-1.5">
					<label class="text-xs font-bold text-slate-600" for="det-branch">{L('Branch', 'الفرع')}</label>
					<select
						id="det-branch"
						class="px-3 py-2 rounded-lg border border-slate-300 text-sm bg-white focus:outline-none focus:border-red-500"
						bind:value={formBranchId}
						on:change={onBranchChange}
					>
						<option value={null} disabled selected>{L('Select a branch', 'اختر الفرع')}</option>
						{#each branches as b (b.id)}
							<option value={b.id}>{branchName(b)}</option>
						{/each}
					</select>
					{#if formCurrentUserId}
						<span class="text-xs text-amber-600">
							{L('This branch already has a default:', 'لهذا الفرع مستخدم افتراضي حالياً:')}
							{userDisplayName(userById.get(formCurrentUserId), isArabic) || '-'}. {L('Saving replaces it.', 'الحفظ سيستبدله.')}
						</span>
					{/if}
				</div>

				<div class="flex flex-col gap-1.5">
					<label class="text-xs font-bold text-slate-600" for="det-user">{L('User', 'المستخدم')}</label>
					<EntryTaskUserPicker
						inputId="det-user"
						{users}
						bind:value={formUserId}
						placeholder={L('Search and select a user', 'ابحث واختر مستخدماً')}
					/>
				</div>

				{#if formError}
					<div class="text-sm text-red-600 font-semibold">{formError}</div>
				{/if}
			</div>

			<div class="flex justify-end gap-2 px-5 py-4 border-t border-slate-200">
				<button type="button" class="px-4 py-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-600 text-sm font-bold" on:click={closeModal}>{L('Cancel', 'إلغاء')}</button>
				<button type="button" class="px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-bold disabled:opacity-60" disabled={saving} on:click={save}>
					{saving ? L('Saving...', 'جارٍ الحفظ...') : L('Save', 'حفظ')}
				</button>
			</div>
		</div>
	</div>
{/if}
