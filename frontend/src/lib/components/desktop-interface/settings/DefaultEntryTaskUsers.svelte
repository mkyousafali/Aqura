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
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
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
	let bankDefaults: Record<number, { ledgerId: number; ledgerName: string }> = {};
	let showBankModal = false;
	let bankFormBranchId: number | null = null;
	let bankLedgers: Array<{ ledgerId: number; ledgerName: string; groupName: string }> = [];
	let bankLedgerSearch = '';
	let bankFormLedgerId: number | null = null;
	let loadingBankLedgers = false;
	let bankFormError = '';
	let savingBankDefault = false;

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
	$: configuredBankRows = branches.filter((b) => bankDefaults[b.id]).map((b) => ({ branch: b, account: bankDefaults[b.id] }));
	$: filteredBankLedgers = bankLedgerSearch.trim()
		? bankLedgers.filter((ledger) => ledger.ledgerName.toLowerCase().includes(bankLedgerSearch.trim().toLowerCase()))
		: bankLedgers;

	onMount(loadAll);

	async function loadAll() {
		loading = true;
		loadError = '';
		try {
			const [branchRes, defaultsRes, userList] = await Promise.all([
				supabase.from('branches').select('id, name_en, name_ar').eq('is_active', true).order('name_en'),
				supabase.from('branch_default_positions').select('branch_id, entry_task_user_id, bank_delivery_ledger_id, bank_delivery_ledger_name'),
				loadSelectableUsers()
			]);
			if (branchRes.error) throw branchRes.error;
			if (defaultsRes.error) throw defaultsRes.error;
			branches = (branchRes.data || []) as BranchRow[];
			users = userList;
			const next: Record<number, string> = {};
			const nextBank: Record<number, { ledgerId: number; ledgerName: string }> = {};
			for (const row of defaultsRes.data || []) {
				if (row.entry_task_user_id) next[Number(row.branch_id)] = row.entry_task_user_id;
				if (row.bank_delivery_ledger_id && row.bank_delivery_ledger_name) nextBank[Number(row.branch_id)] = { ledgerId: Number(row.bank_delivery_ledger_id), ledgerName: row.bank_delivery_ledger_name };
			}
			defaults = next;
			bankDefaults = nextBank;
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

	async function openBankModal(branchId: number | null = null) {
		showBankModal = true;
		bankFormBranchId = branchId;
		bankFormLedgerId = branchId != null ? bankDefaults[branchId]?.ledgerId || null : null;
		bankLedgerSearch = branchId != null ? bankDefaults[branchId]?.ledgerName || '' : '';
		bankFormError = '';
		bankLedgers = [];
		if (branchId != null) await loadBankLedgers(branchId);
	}

	function closeBankModal() {
		showBankModal = false;
		bankFormBranchId = null;
		bankFormLedgerId = null;
		bankLedgerSearch = '';
		bankLedgers = [];
		bankFormError = '';
	}

	async function loadBankLedgers(branchId: number) {
		loadingBankLedgers = true;
		bankFormError = '';
		bankFormLedgerId = bankDefaults[branchId]?.ledgerId || null;
		bankLedgerSearch = bankDefaults[branchId]?.ledgerName || '';
		try {
			const { data: connection, error } = await supabase.from('erp_connections').select('erp_branch_id').eq('branch_id', branchId).eq('is_active', true).maybeSingle();
			if (error) throw error;
			if (!connection?.erp_branch_id) throw new Error(L('No active ERP connection for this branch', 'لا يوجد اتصال ERP نشط لهذا الفرع'));
			const sql = `SELECT l.LedgerID, l.LedgerName, g.AccGroupName FROM AccLedgers l LEFT JOIN AccGroups g ON g.AccGroupID = l.AccGroupID AND g.BranchID = l.BranchID WHERE l.BranchID = ${Number(connection.erp_branch_id)} AND l.IsActive = 1 AND LOWER(COALESCE(g.AccGroupName, '')) LIKE '%bank%' ORDER BY l.LedgerName`;
			const response = await authenticatedFetch('/api/erp-products', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'query', branchId, sql }) });
			const result = await response.json();
			if (!result.success) throw new Error(result.error || 'Failed to load bank ledgers');
			bankLedgers = (result.recordset || []).map((row: any) => ({ ledgerId: Number(row.LedgerID), ledgerName: String(row.LedgerName || '').trim(), groupName: String(row.AccGroupName || '') }));
		} catch (err: any) {
			bankFormError = err.message || L('Failed to load bank ledgers', 'فشل تحميل حسابات البنك');
		} finally { loadingBankLedgers = false; }
	}

	function selectBankLedger(ledger: { ledgerId: number; ledgerName: string }) {
		bankFormLedgerId = ledger.ledgerId;
		bankLedgerSearch = ledger.ledgerName;
	}

	async function saveBankDefault() {
		if (bankFormBranchId == null || bankFormLedgerId == null) { bankFormError = L('Select a branch and bank ledger', 'اختر الفرع وحساب البنك'); return; }
		const ledger = bankLedgers.find((item) => item.ledgerId === bankFormLedgerId);
		if (!ledger) { bankFormError = L('Select a bank ledger from the results', 'اختر حساب بنك من نتائج البحث'); return; }
		savingBankDefault = true;
		try {
			const { error } = await supabase.from('branch_default_positions').upsert({ branch_id: bankFormBranchId, bank_delivery_ledger_id: ledger.ledgerId, bank_delivery_ledger_name: ledger.ledgerName }, { onConflict: 'branch_id' });
			if (error) throw error;
			await loadAll(); closeBankModal(); flashSuccess(L('Default bank account saved', 'تم حفظ حساب البنك الافتراضي'));
		} catch (err: any) { bankFormError = err.message || L('Failed to save', 'فشل الحفظ'); } finally { savingBankDefault = false; }
	}

	async function removeBankDefault(branch: BranchRow) {
		const { error } = await supabase.from('branch_default_positions').update({ bank_delivery_ledger_id: null, bank_delivery_ledger_name: null }).eq('branch_id', branch.id);
		if (error) { loadError = error.message; return; }
		await loadAll(); flashSuccess(L('Default bank account removed', 'تمت إزالة حساب البنك الافتراضي'));
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

		<div class="mt-8 flex items-center justify-between">
			<div>
				<h3 class="text-base font-black text-slate-800">{L('Default Bank on Delivery Accounts', 'حسابات البنك الافتراضية للدفع عند الاستلام')}</h3>
				<p class="text-xs text-slate-500">{L('Select one default bank ledger for each branch.', 'حدد حساب بنك افتراضي واحد لكل فرع.')}</p>
			</div>
			<button type="button" class="w-9 h-9 rounded-full bg-blue-600 hover:bg-blue-700 text-white text-xl font-bold" on:click={() => openBankModal()}>+</button>
		</div>
		<div class="mt-3 bg-white border border-slate-200 rounded-xl overflow-hidden">
			<table class="w-full text-sm">
				<thead class="bg-slate-50 text-slate-500 text-xs uppercase"><tr><th class="px-4 py-3 text-start">{L('Branch', 'الفرع')}</th><th class="px-4 py-3 text-start">{L('Default bank ledger', 'حساب البنك الافتراضي')}</th><th class="px-4 py-3 w-24"></th></tr></thead>
				<tbody>
					{#if configuredBankRows.length === 0}<tr><td colspan="3" class="px-4 py-8 text-center text-slate-400">{L('No default bank accounts configured yet', 'لم يتم إعداد حسابات بنك افتراضية بعد')}</td></tr>{/if}
					{#each configuredBankRows as row (row.branch.id)}
						<tr class="border-t border-slate-100"><td class="px-4 py-3 font-semibold text-slate-700">{branchName(row.branch)}</td><td class="px-4 py-3 text-slate-700">{row.account.ledgerName}</td><td class="px-4 py-3"><div class="flex justify-end gap-1"><button class="px-2 py-1 rounded hover:bg-slate-100" on:click={() => openBankModal(row.branch.id)} title={L('Change', 'تغيير')}>✏️</button><button class="px-2 py-1 rounded hover:bg-red-50 text-red-500" on:click={() => removeBankDefault(row.branch)} title={L('Remove', 'إزالة')}>🗑️</button></div></td></tr>
					{/each}
				</tbody>
			</table>
		</div>
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

{#if showBankModal}
	<div class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" on:click={closeBankModal}>
		<div class="bg-white rounded-xl shadow-2xl w-[560px] max-w-full" dir={isArabic ? 'rtl' : 'ltr'} on:click|stopPropagation>
			<div class="flex items-center justify-between px-5 py-4 border-b border-slate-200"><h3 class="font-black text-slate-800">{L('Set default Bank on Delivery account', 'تحديد حساب البنك الافتراضي للدفع عند الاستلام')}</h3><button on:click={closeBankModal}>✕</button></div>
			<div class="p-5 flex flex-col gap-4">
				<div class="flex flex-col gap-1.5"><label class="text-xs font-bold text-slate-600">{L('Branch', 'الفرع')}</label><select class="px-3 py-2 rounded-lg border border-slate-300 bg-white" bind:value={bankFormBranchId} on:change={() => bankFormBranchId != null && loadBankLedgers(bankFormBranchId)}><option value={null} disabled>{L('Select a branch', 'اختر الفرع')}</option>{#each branches as branch (branch.id)}<option value={branch.id}>{branchName(branch)}</option>{/each}</select></div>
				<div class="flex flex-col gap-1.5 relative"><label class="text-xs font-bold text-slate-600">{L('Bank ledger', 'حساب البنك')}</label><input class="px-3 py-2 rounded-lg border border-slate-300" type="search" bind:value={bankLedgerSearch} placeholder={L('Search and select bank ledger', 'ابحث واختر حساب البنك')} disabled={bankFormBranchId == null || loadingBankLedgers} on:input={() => bankFormLedgerId = null} />
					{#if bankFormBranchId != null && !loadingBankLedgers}<div class="max-h-52 overflow-auto border border-slate-200 rounded-lg">{#each filteredBankLedgers as ledger (ledger.ledgerId)}<button type="button" class="w-full px-3 py-2 text-start hover:bg-blue-50 border-b border-slate-100" on:click={() => selectBankLedger(ledger)}><div class="font-semibold text-slate-700">{ledger.ledgerName}</div><div class="text-xs text-slate-400">{ledger.groupName}</div></button>{/each}{#if filteredBankLedgers.length === 0}<div class="px-3 py-5 text-center text-slate-400">{L('No bank ledgers found', 'لم يتم العثور على حسابات بنك')}</div>{/if}</div>{/if}
				</div>
				{#if loadingBankLedgers}<div class="text-sm text-slate-400">{L('Loading bank ledgers...', 'جاري تحميل حسابات البنك...')}</div>{/if}
				{#if bankFormError}<div class="text-sm text-red-600 font-semibold">{bankFormError}</div>{/if}
			</div>
			<div class="flex justify-end gap-2 px-5 py-4 border-t border-slate-200"><button class="px-4 py-2 rounded-lg bg-slate-100 text-sm font-bold" on:click={closeBankModal}>{L('Cancel', 'إلغاء')}</button><button class="px-4 py-2 rounded-lg bg-blue-600 text-white text-sm font-bold disabled:opacity-60" disabled={savingBankDefault} on:click={saveBankDefault}>{savingBankDefault ? L('Saving...', 'جاري الحفظ...') : L('Save', 'حفظ')}</button></div>
		</div>
	</div>
{/if}
