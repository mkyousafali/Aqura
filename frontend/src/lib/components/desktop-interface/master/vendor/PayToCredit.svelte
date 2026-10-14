<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';

	let branches: any[] = [];
	let selectedBranchId = '';
	let loading = true;
	let error = '';
	let vendorLedgers: any[] = [];
	let vendorSearch = '';
	let selectedVendorLedgerId: number | null = null;
	let loadingVendors = false;
	let paymentAccountType = '';
	let amount = '';
	let scanRequest: any = null;
	let sendingScanRequest = false;
	let gettingAmount = false;
	let scanChannel: any = null;
	let scanRefreshTimer: ReturnType<typeof setInterval> | null = null;
	let transactions: any[] = [];
	let loadingTransactions = true;
	let entryTaskBranchIds = new Set<number>();
	let editingTransactionId = '';
	let editingAmount = '';
	let savingEditedAmount = false;
	let savingCashTransaction = false;
	$: canChangeBranch = !!$currentUser?.isMasterAdmin;
	$: filteredVendorLedgers = vendorSearch.trim()
		? vendorLedgers.filter((vendor) => `${vendor.vendor_name || ''} ${vendor.erp_vendor_id || ''}`.toLowerCase().includes(vendorSearch.trim().toLowerCase())).slice(0, 50)
		: [];

	function loggedUserBranchId(): number | null {
		const branchId = Number($currentUser?.branch_id);
		return Number.isInteger(branchId) && branchId > 0 ? branchId : null;
	}

	function permittedBranchId(): number | null {
		if (!$currentUser?.isMasterAdmin) return loggedUserBranchId();
		const branchId = Number(selectedBranchId);
		return Number.isInteger(branchId) && branchId > 0 ? branchId : null;
	}

	onMount(async () => {
		const ownBranchId = loggedUserBranchId();
		selectedBranchId = ownBranchId ? String(ownBranchId) : '';
		let branchQuery = supabase
			.from('branches')
			.select('id,name_en,name_ar,location_en,location_ar')
			.order('name_en');
		if ($currentUser?.isMasterAdmin) branchQuery = branchQuery.eq('is_active', true);
		else branchQuery = branchQuery.eq('id', ownBranchId ?? -1);
		const { data, error: loadError } = await branchQuery;
		if (loadError) error = loadError.message;
		else branches = data || [];
		if (!$currentUser?.isMasterAdmin) selectedBranchId = ownBranchId ? String(ownBranchId) : '';
		else if (!branches.some((branch) => Number(branch.id) === ownBranchId)) selectedBranchId = '';
		loading = false;
		if (permittedBranchId()) await loadVendorLedgers();
		await loadEditPermissions();
		await loadTransactions();
		setupPayToCreditRealtime();
	});

	onDestroy(() => {
		if (scanChannel) supabase.removeChannel(scanChannel);
		if (scanRefreshTimer) clearInterval(scanRefreshTimer);
	});

	async function refreshCurrentScanRequest() {
		if (!scanRequest?.id || scanRequest.status !== 'pending') return;
		const { data } = await supabase.from('pos_scan_requests')
			.select('id,status,photo_url,request_label,created_at')
			.eq('id', scanRequest.id)
			.maybeSingle();
		if (data) {
			scanRequest = data;
			await loadTransactions();
		}
		if (data?.status === 'completed' && scanRefreshTimer) {
			clearInterval(scanRefreshTimer);
			scanRefreshTimer = null;
		}
	}

	async function loadTransactions() {
		if (!$currentUser?.id) { loadingTransactions = false; return; }
		loadingTransactions = true;
		let transactionQuery = supabase.from('pos_scan_requests')
			.select('id,status,photo_url,request_label,created_at,completed_at,branch_id,extracted_amount,payment_account_type')
			.eq('requested_by', $currentUser.id)
			.eq('request_type', 'pay_to_credit_slip')
			.in('status', ['pending', 'completed'])
			.order('created_at', { ascending: false });
		if (!$currentUser?.isMasterAdmin) {
			transactionQuery = transactionQuery.eq('branch_id', loggedUserBranchId() ?? -1);
		}
		const { data, error: transactionError } = await transactionQuery;
		if (transactionError) error = transactionError.message;
		else transactions = data || [];
		loadingTransactions = false;
	}

	async function loadEditPermissions() {
		if (!$currentUser?.id || $currentUser?.isMasterAdmin || $currentUser?.isAdmin) return;
		const { data } = await supabase.from('branch_default_positions')
			.select('branch_id')
			.eq('entry_task_user_id', $currentUser.id);
		entryTaskBranchIds = new Set((data || []).map((row: any) => Number(row.branch_id)));
	}

	function canEditTransaction(transaction: any) {
		if ($currentUser?.isMasterAdmin) return true;
		const transactionBranchId = Number(transaction.branch_id);
		if (transactionBranchId !== loggedUserBranchId()) return false;
		return !!($currentUser?.isAdmin || entryTaskBranchIds.has(transactionBranchId));
	}

	function beginEditAmount(transaction: any) {
		editingTransactionId = transaction.id;
		editingAmount = transaction.extracted_amount == null ? '' : String(transaction.extracted_amount);
	}

	async function saveEditedTransactionAmount(transaction: any) {
		if (!canEditTransaction(transaction) || savingEditedAmount) return;
		const nextAmount = Number(editingAmount);
		if (!Number.isFinite(nextAmount) || nextAmount < 0) {
			error = 'Enter a valid amount.';
			return;
		}
		savingEditedAmount = true;
		error = '';
		const { error: updateError } = await supabase.from('pos_scan_requests')
			.update({ extracted_amount: nextAmount, updated_at: new Date().toISOString() })
			.eq('id', transaction.id);
		if (updateError) error = updateError.message;
		else {
			transactions = transactions.map((item) => item.id === transaction.id ? { ...item, extracted_amount: nextAmount } : item);
			if (scanRequest?.id === transaction.id) {
				scanRequest = { ...scanRequest, extracted_amount: nextAmount };
				amount = String(nextAmount);
			}
			editingTransactionId = '';
			editingAmount = '';
		}
		savingEditedAmount = false;
	}

	async function saveCashTransaction() {
		const branchId = permittedBranchId();
		if (!$currentUser?.id || !branchId || selectedVendorLedgerId === null || savingCashTransaction) return;
		const cashAmount = Number(amount);
		if (!Number.isFinite(cashAmount) || cashAmount <= 0) return;
		savingCashTransaction = true;
		error = '';
		const values = {
			branch_id: branchId, requested_by: $currentUser.id,
			request_type: 'pay_to_credit_slip', payment_account_type: 'cash',
			request_label: `Pay to Credit · ${vendorSearch}`, status: 'completed',
			extracted_amount: cashAmount, completed_by: $currentUser.id,
			completed_at: new Date().toISOString(), updated_at: new Date().toISOString()
		};
		const result = await supabase.from('pos_scan_requests')
			.insert({ ...values, box_operation_id: null, receiving_record_id: null })
			.select('id').single();
		if (result.error) error = result.error.message;
		else {
			await loadTransactions();
			amount = '';
		}
		savingCashTransaction = false;
	}

	function startScanRequestRefresh() {
		if (scanRefreshTimer) clearInterval(scanRefreshTimer);
		scanRefreshTimer = setInterval(refreshCurrentScanRequest, 2000);
	}

	function setupPayToCreditRealtime() {
		if (!$currentUser?.id) return;
		scanChannel = supabase.channel(`pay-to-credit-scan-${$currentUser.id}`).on('postgres_changes', {
			event: '*', schema: 'public', table: 'pos_scan_requests', filter: `requested_by=eq.${$currentUser.id}`
		}, (payload: any) => {
			const row = payload.new || payload.old;
			if (row?.request_type === 'pay_to_credit_slip') {
				if (scanRequest?.id === row.id) scanRequest = row;
				loadTransactions();
			}
		}).subscribe();
	}

	async function sendScanRequest() {
		const branchId = permittedBranchId();
		if (!$currentUser?.id || !branchId || selectedVendorLedgerId === null || sendingScanRequest) return;
		sendingScanRequest = true;
		error = '';
		try {
			const { data, error: requestError } = await supabase.from('pos_scan_requests').insert({
				box_operation_id: null, receiving_record_id: null, branch_id: branchId,
				requested_by: $currentUser.id, request_type: 'pay_to_credit_slip', payment_account_type: 'bank', status: 'pending',
				request_label: `Pay to Credit · ${vendorSearch}`
			}).select('id,status,photo_url,request_label,created_at').single();
			if (requestError) throw requestError;
			scanRequest = data;
			await loadTransactions();
			startScanRequestRefresh();
		} catch (requestError: any) {
			error = requestError.message || 'Failed to send scan request.';
		} finally { sendingScanRequest = false; }
	}

	async function getAmountFromSlip(transaction = scanRequest) {
		if (!transaction?.photo_url) transaction = scanRequest;
		if (!transaction?.photo_url || gettingAmount) return;
		scanRequest = transaction;
		gettingAmount = true;
		error = '';
		try {
			const photoResponse = await fetch(transaction.photo_url);
			if (!photoResponse.ok) throw new Error('Could not load the uploaded slip photo.');
			const blob = await photoResponse.blob();
			const dataUrl = await new Promise<string>((resolve, reject) => {
				const reader = new FileReader(); reader.onload = () => resolve(String(reader.result)); reader.onerror = reject; reader.readAsDataURL(blob);
			});
			const response = await fetch('/api/scan-request-extract', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ imageBase64: dataUrl.split(',')[1], mimeType: blob.type, mode: 'amount' })
			});
			const result = await response.json();
			if (!response.ok || result.error || !result.amount) throw new Error(result.error || 'Amount was not found on the slip.');
			amount = String(result.amount);
			const extractedAmount = Number(result.amount);
			const { error: saveAmountError } = await supabase.from('pos_scan_requests')
				.update({ extracted_amount: extractedAmount, updated_at: new Date().toISOString() })
				.eq('id', transaction.id);
			if (saveAmountError) throw saveAmountError;
			transactions = transactions.map((item) => item.id === transaction.id ? { ...item, extracted_amount: extractedAmount } : item);
			scanRequest = { ...transaction, extracted_amount: extractedAmount };
		} catch (amountError: any) {
			error = amountError.message || 'Failed to read the slip amount.';
		} finally { gettingAmount = false; }
	}

	async function loadVendorLedgers() {
		const branchId = permittedBranchId();
		if (!$currentUser?.isMasterAdmin) selectedBranchId = branchId ? String(branchId) : '';
		vendorLedgers = [];
		vendorSearch = '';
		selectedVendorLedgerId = null;
		scanRequest = null;
		amount = '';
		if (!branchId) return;
		loadingVendors = true;
		error = '';
		try {
			const { data: connection, error: connectionError } = await supabase
				.from('erp_connections')
				.select('erp_branch_id')
				.eq('branch_id', branchId)
				.eq('is_active', true)
				.maybeSingle();
			if (connectionError) throw connectionError;
			if (!connection?.erp_branch_id) throw new Error('No active Polosys connection is configured for this branch.');
			const sql = `
				SELECT DISTINCT l.LedgerID, l.LedgerName, p.PartyCode
				FROM Parties p
				INNER JOIN AccLedgers l ON l.LedgerCode = p.PartyCode AND l.BranchID = p.BranchID
				WHERE p.BranchID = ${Number(connection.erp_branch_id)} AND l.IsActive = 1
				ORDER BY l.LedgerName
			`;
			const response = await authenticatedFetch('/api/erp-products', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'query', branchId, sql })
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Failed to load vendor ledgers from Polosys.');
			vendorLedgers = (result.recordset || []).map((row: any) => ({
				erp_vendor_id: Number(row.LedgerID),
				vendor_name: String(row.LedgerName || '').trim(),
				party_code: String(row.PartyCode || '').trim()
			}));
		} catch (loadError: any) {
			error = loadError.message || 'Failed to load vendor ledgers from Polosys.';
		}
		loadingVendors = false;
	}

	function selectVendorLedger(vendor: any) {
		selectedVendorLedgerId = Number(vendor.erp_vendor_id);
		vendorSearch = vendor.vendor_name;
		scanRequest = null;
		amount = '';
	}

	function handlePaymentAccountTypeChange() {
		scanRequest = null;
		amount = '';
	}
</script>


<div class="h-full w-full bg-white p-6">
	<div class="grid grid-cols-1 lg:grid-cols-3 gap-5 items-start">
		<div>
		<label for="pay-credit-branch" class="block text-sm font-semibold text-slate-700 mb-2">
			{$currentLocale === 'ar' ? 'الفرع' : 'Branch'}
		</label>
		<select id="pay-credit-branch" class="w-full px-3 py-2.5 border border-slate-300 rounded-lg bg-white text-slate-800 disabled:bg-slate-100 disabled:text-slate-500" bind:value={selectedBranchId} disabled={loading || !canChangeBranch} on:change={loadVendorLedgers}>
			<option value="">{loading ? ($currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...') : ($currentLocale === 'ar' ? 'اختر الفرع' : 'Select branch')}</option>
			{#each branches as branch (branch.id)}
				<option value={String(branch.id)}>{($currentLocale === 'ar' ? branch.name_ar : branch.name_en) || branch.name_en || branch.name_ar}{#if ($currentLocale === 'ar' ? branch.location_ar : branch.location_en)} - {($currentLocale === 'ar' ? branch.location_ar : branch.location_en)}{/if}</option>
			{/each}
		</select>
		{#if !canChangeBranch && selectedBranchId}<p class="mt-2 text-xs text-slate-500">{$currentLocale === 'ar' ? 'تم تحديد فرع المستخدم تلقائيًا.' : 'Your assigned branch is selected automatically.'}</p>{/if}
		</div>

		<div class="relative">
			<label for="pay-credit-vendor" class="block text-sm font-semibold text-slate-700 mb-2">
				{$currentLocale === 'ar' ? 'حساب المورد' : 'Vendor Ledger'}
			</label>
			<input id="pay-credit-vendor" type="search" class="w-full px-3 py-2.5 border border-slate-300 rounded-lg bg-white text-slate-800 disabled:bg-slate-100" bind:value={vendorSearch} on:input={() => selectedVendorLedgerId = null} disabled={!selectedBranchId || loadingVendors} placeholder={loadingVendors ? ($currentLocale === 'ar' ? 'جاري تحميل الموردين...' : 'Loading vendor ledgers...') : ($currentLocale === 'ar' ? 'ابحث باسم المورد أو رقم الحساب' : 'Search vendor name or ledger ID')} />
			{#if vendorSearch.trim() && selectedVendorLedgerId === null}
				<div class="absolute z-20 left-0 right-0 mt-1 max-h-64 overflow-auto border border-slate-200 rounded-lg bg-white shadow-sm">
					{#each filteredVendorLedgers as vendor (vendor.erp_vendor_id)}
						<button type="button" class="w-full px-3 py-2 text-start border-b border-slate-100 hover:bg-blue-50" on:click={() => selectVendorLedger(vendor)}>
							<div class="font-semibold text-slate-700">{vendor.vendor_name}</div>
							<div class="text-xs text-slate-400">ID: {vendor.erp_vendor_id}</div>
						</button>
					{/each}
					{#if filteredVendorLedgers.length === 0}<div class="px-3 py-5 text-center text-sm text-slate-400">{$currentLocale === 'ar' ? 'لم يتم العثور على مورد' : 'No vendor ledger found'}</div>{/if}
				</div>
			{/if}
		</div>

		<div>
			<label for="pay-credit-account-type" class="block text-sm font-semibold text-slate-700 mb-2">
				{$currentLocale === 'ar' ? 'نوع حساب الدفع' : 'Payment Account Type'}
			</label>
			<select id="pay-credit-account-type" class="w-full px-3 py-2.5 border border-slate-300 rounded-lg bg-white text-slate-800" bind:value={paymentAccountType} on:change={handlePaymentAccountTypeChange}>
				<option value="">{$currentLocale === 'ar' ? 'اختر البنك أو النقد' : 'Select Bank or Cash'}</option>
				<option value="bank">{$currentLocale === 'ar' ? 'بنك' : 'Bank'}</option>
				<option value="cash">{$currentLocale === 'ar' ? 'نقد' : 'Cash'}</option>
			</select>
		</div>
		{#if error}<p class="mt-2 text-sm text-red-600">{error}</p>{/if}
	</div>

	{#if paymentAccountType === 'cash'}
		<div class="mt-5 max-w-xl">
			<label for="pay-credit-amount" class="block text-sm font-semibold text-slate-700 mb-2">{$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}</label>
			<div class="flex gap-2">
				<input id="pay-credit-amount" type="number" min="0" step="0.01" class="flex-1 px-3 py-2.5 border border-slate-300 rounded-lg" bind:value={amount} placeholder="0.00" />
				<button type="button" class="px-5 py-2.5 rounded-lg bg-emerald-600 text-white font-semibold disabled:opacity-50" on:click={saveCashTransaction} disabled={savingCashTransaction || !selectedBranchId || selectedVendorLedgerId === null || !(Number(amount) > 0)}>
					{savingCashTransaction ? ($currentLocale === 'ar' ? 'جاري الحفظ...' : 'Saving...') : ($currentLocale === 'ar' ? 'حفظ' : 'Save')}
				</button>
			</div>
		</div>
	{:else if paymentAccountType === 'bank'}
		<div class="mt-5 max-w-xl"><label for="pay-credit-bank-amount" class="block text-sm font-semibold text-slate-700 mb-2">{$currentLocale === 'ar' ? 'المبلغ' : 'Amount'}</label><div class="flex gap-2"><input id="pay-credit-bank-amount" type="number" min="0" step="0.01" class="flex-1 px-3 py-2.5 border border-slate-300 rounded-lg" bind:value={amount} placeholder="0.00" /><button type="button" class="px-4 py-2.5 rounded-lg bg-blue-600 text-white font-semibold disabled:opacity-50" on:click={sendScanRequest} disabled={sendingScanRequest || scanRequest?.status === 'pending' || !selectedBranchId || selectedVendorLedgerId === null}>{sendingScanRequest ? 'Sending...' : scanRequest?.status === 'pending' ? 'Waiting for Photo' : 'Send Request'}</button>{#if scanRequest?.status === 'completed' && scanRequest?.photo_url}<button type="button" class="px-4 py-2.5 rounded-lg bg-emerald-600 text-white font-semibold disabled:opacity-50" on:click={getAmountFromSlip} disabled={gettingAmount}>{gettingAmount ? 'Reading...' : 'Get Amount'}</button>{/if}</div></div>
	{/if}

	{#if paymentAccountType === 'bank' && scanRequest?.status === 'pending'}
		<p class="mt-3 text-sm font-medium text-amber-700">Waiting for the mobile user to upload the payment slip.</p>
	{:else if paymentAccountType === 'bank' && scanRequest?.status === 'completed' && scanRequest?.photo_url}
		<div class="mt-4 max-w-xl rounded-xl border border-emerald-200 bg-emerald-50 p-3">
			<p class="mb-3 text-sm font-semibold text-emerald-700">Payment slip uploaded for this transaction.</p>
			<img src={scanRequest.photo_url} alt="Uploaded payment slip" class="max-h-80 max-w-full rounded-lg border border-slate-200 bg-white object-contain" />
		</div>
	{/if}

	<div class="mt-8 overflow-hidden rounded-xl border border-slate-200 bg-white">
		<div class="border-b border-slate-200 bg-slate-50 px-4 py-3">
			<h3 class="font-bold text-slate-800">Pay to Credit Transactions</h3>
		</div>
		{#if loadingTransactions}
			<div class="p-6 text-center text-sm text-slate-500">Loading transactions...</div>
		{:else if transactions.length === 0}
			<div class="p-6 text-center text-sm text-slate-500">No Pay to Credit transactions yet.</div>
		{:else}
			<div class="overflow-x-auto">
				<table class="w-full border-collapse text-sm">
					<thead class="bg-slate-50 text-left text-xs uppercase text-slate-500">
						<tr><th class="px-4 py-3">Date</th><th class="px-4 py-3">Transaction</th><th class="px-4 py-3">Amount</th><th class="px-4 py-3">Status</th><th class="px-4 py-3">Slip</th><th class="px-4 py-3">Action</th></tr>
					</thead>
					<tbody>
						{#each transactions as transaction (transaction.id)}
							<tr class="border-t border-slate-100">
								<td class="whitespace-nowrap px-4 py-3 text-slate-600">{new Date(transaction.created_at).toLocaleString()}</td>
								<td class="px-4 py-3 font-semibold text-slate-800">{transaction.request_label || 'Pay to Credit'}</td>
								<td class="whitespace-nowrap px-4 py-3 font-bold text-slate-800">
									{#if editingTransactionId === transaction.id}
										<input type="number" min="0" step="0.01" class="w-28 rounded-lg border border-slate-300 px-2 py-1.5" bind:value={editingAmount} />
									{:else}
										{transaction.extracted_amount == null ? '—' : Number(transaction.extracted_amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
									{/if}
								</td>
								<td class="px-4 py-3"><span class={transaction.status === 'completed' ? 'rounded-full bg-emerald-100 px-2 py-1 text-xs font-bold text-emerald-700' : 'rounded-full bg-amber-100 px-2 py-1 text-xs font-bold text-amber-700'}>{transaction.status === 'completed' ? 'Uploaded' : 'Waiting for photo'}</span></td>
								<td class="px-4 py-3">{#if transaction.photo_url}<img src={transaction.photo_url} alt="Payment slip" class="h-14 w-20 rounded border border-slate-200 object-cover" />{:else}<span class="text-slate-400">—</span>{/if}</td>
								<td class="px-4 py-3">
									<div class="flex flex-wrap gap-2">
										{#if transaction.status === 'completed' && transaction.photo_url}<button type="button" class="rounded-lg bg-emerald-600 px-3 py-2 font-semibold text-white disabled:opacity-50" on:click={() => getAmountFromSlip(transaction)} disabled={gettingAmount}>{gettingAmount && scanRequest?.id === transaction.id ? 'Reading...' : 'Get Amount'}</button>{:else}<span class="text-slate-400">Pending</span>{/if}
										{#if canEditTransaction(transaction)}
											{#if editingTransactionId === transaction.id}
												<button type="button" class="rounded-lg bg-blue-600 px-3 py-2 font-semibold text-white disabled:opacity-50" on:click={() => saveEditedTransactionAmount(transaction)} disabled={savingEditedAmount}>{savingEditedAmount ? 'Saving...' : 'Save'}</button>
												<button type="button" class="rounded-lg border border-slate-300 bg-white px-3 py-2 font-semibold text-slate-600" on:click={() => { editingTransactionId = ''; editingAmount = ''; }}>Cancel</button>
											{:else}
												<button type="button" class="rounded-lg border border-blue-300 bg-blue-50 px-3 py-2 font-semibold text-blue-700" on:click={() => beginEditAmount(transaction)}>Edit</button>
											{/if}
										{/if}
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
