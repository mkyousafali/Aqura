<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import EntryTaskUserPicker from '$lib/components/desktop-interface/common/EntryTaskUserPicker.svelte';
	import type { SelectableUser } from '$lib/utils/entryTaskUsers';

	interface BranchOption {
		branch_id: number;
		branch_name_en: string;
		branch_name_ar: string;
		location_en: string;
		location_ar: string;
		tunnel_url: string;
		erp_branch_id: number;
	}

	interface LedgerOption {
		ledgerId: number;
		ledgerName: string;
		groupName: string;
	}

	interface LedgerTxn {
		date: string;
		voucherType: string;
		voucherTypeName: string;
		voucherNumber: string;
		// The supplier's own invoice number, held in AccTransactionMaster.ReferenceNumber -- confirmed
		// live it's populated specifically for Purchase Invoice (PI) rows, so only shown for those.
		billNumber: string | null;
		narration: string;
		debit: number;
		credit: number;
		balance: number;
	}

	let branches: BranchOption[] = [];
	let selectedBranchId: number | null = null;
	let loadingBranches = true;

	let ledgers: LedgerOption[] = [];
	let loadingLedgers = false;
	let ledgerSearch = '';
	let selectedLedgerId: number | null = null;
	let showLedgerDropdown = false;

	function toDateInput(d: Date): string {
		return d.toISOString().split('T')[0];
	}
	const today = new Date();
	const thirtyDaysAgo = new Date(today);
	thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
	let dateFrom = toDateInput(thirtyDaysAgo);
	let dateTo = toDateInput(today);

	let openingBalance = 0;
	let transactions: LedgerTxn[] = [];
	let loading = false;
	let hasRun = false;
	let errorMessage = '';
	let exporting = false;

	// Send popup (PI rows only) -- creates an ERP Entry Task via create_erp_entry_task().
	let showSendModal = false;
	let sendModalRow: LedgerTxn | null = null;
	let sendBillAmount = '';
	let sendPaymentType: 'cash' | 'bank' | 'jv' = 'bank';
	let sendBankLedgerId: number | null = null;
	// JV: the credit account can be any ledger of the branch, chosen with search (not just bank ledgers).
	let sendJvLedgerId: number | null = null;
	let sendJvSearch = '';
	let showJvDropdown = false;
	let sendSubmitting = false;
	let sendError = '';
	// Assignee for this one task. Pre-selected from the branch's default Entry Task user (set in
	// App Permissions > Default Entry Task Users), but only ever a local choice: changing it here
	// never writes back to that saved default. No default => left empty, sender must pick.
	let sendUsers: SelectableUser[] = [];
	let sendUsersLoading = false;
	let sendAssigneeId: string | null = null;
	let sendDefaultAssigneeId: string | null = null;

	// Ledgers whose ERP group indicates a bank account (e.g. "Bank Accounts", "Bank OD A/c"),
	// drawn from the same branch-wide ledger list already loaded for the ledger-search field above.
	$: bankLedgers = ledgers.filter((l) => l.groupName.toLowerCase().includes('bank'));

	// Credit-account candidates for a JV: every branch ledger except the supplier being paid.
	$: jvCandidates = ledgers.filter(
		(l) =>
			l.ledgerId !== selectedLedgerId &&
			(!sendJvSearch.trim() || l.ledgerName.toLowerCase().includes(sendJvSearch.trim().toLowerCase()))
	);

	// Table-only filters -- applied client-side on the already-fetched `transactions` for the current
	// branch/ledger/date period. They never trigger a re-fetch and never touch the opening/closing
	// balance or totals below, which stay computed from the full unfiltered period on purpose.
	let filterDebitCredit: '' | 'debit' | 'credit' = '';
	let filterAmount = '';
	let filterVoucherType = '';

	const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

	$: selectedLedger = ledgers.find((l) => l.ledgerId === selectedLedgerId) || null;
	$: filteredLedgers = ledgerSearch.trim()
		? ledgers.filter((l) => l.ledgerName.toLowerCase().includes(ledgerSearch.trim().toLowerCase()))
		: ledgers;
	$: totalDebit = transactions.reduce((sum, r) => sum + r.debit, 0);
	$: totalCredit = transactions.reduce((sum, r) => sum + r.credit, 0);
	$: closingBalance = transactions.length ? transactions[transactions.length - 1].balance : openingBalance;

	// Voucher-type dropdown only ever lists types actually present in the loaded period, not the ERP's
	// full ~50-code catalog, since these filters work on already-loaded data.
	$: voucherTypeFilterOptions = Array.from(
		new Map(transactions.map((r) => [r.voucherType, r.voucherTypeName])).entries()
	).sort((a, b) => a[1].localeCompare(b[1]));

	$: filteredTransactions = transactions.filter((r) => {
		if (filterDebitCredit === 'debit' && !(r.debit > 0)) return false;
		if (filterDebitCredit === 'credit' && !(r.credit > 0)) return false;
		if (filterVoucherType && r.voucherType !== filterVoucherType) return false;
		const amountQuery = filterAmount.trim();
		if (amountQuery) {
			// Substring match on the formatted amount -- typing "50" should find 500.00, 1500.25, 50.00,
			// etc. rather than requiring the exact figure.
			const matches = formatAmount(r.debit).includes(amountQuery) || formatAmount(r.credit).includes(amountQuery);
			if (!matches) return false;
		}
		return true;
	});

	// Reloads the ledger list whenever the branch changes -- per spec, ledgers load automatically,
	// there's no separate "load ledgers" button.
	$: if (selectedBranchId != null) loadLedgers(selectedBranchId);

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: erpConns, error: erpErr } = await supabase
				.from('erp_connections')
				.select('branch_id, branch_name, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_id');

			if (erpErr) throw erpErr;
			const branchIds = (erpConns || []).map((connection: any) => connection.branch_id);
			const { data: branchData, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.in('id', branchIds);
			if (branchError) throw branchError;
			const branchById = new Map((branchData || []).map((branch: any) => [Number(branch.id), branch]));

			branches = (erpConns || [])
				.filter((c: any) => c.tunnel_url)
				.map((c: any) => {
					const branch = branchById.get(Number(c.branch_id)) as any;
					return {
						branch_id: Number(c.branch_id),
						branch_name_en: branch?.name_en || c.branch_name || `Branch ${c.branch_id}`,
						branch_name_ar: branch?.name_ar || branch?.name_en || c.branch_name || `فرع ${c.branch_id}`,
						location_en: branch?.location_en || '',
						location_ar: branch?.location_ar || branch?.location_en || '',
						tunnel_url: c.tunnel_url,
						erp_branch_id: c.erp_branch_id
					};
				});

			if (branches.length > 0 && !selectedBranchId) {
				selectedBranchId = branches[0].branch_id;
			}
		} catch (err: any) {
			console.error('Error loading branches:', err);
			errorMessage = err.message || $t('erpLedgers.failedToLoadBranches');
		} finally {
			loadingBranches = false;
		}
	}

	function getBranchDisplayName(branch: BranchOption): string {
		const isArabic = $currentLocale === 'ar';
		const name = isArabic ? (branch.branch_name_ar || branch.branch_name_en) : (branch.branch_name_en || branch.branch_name_ar);
		const location = isArabic ? (branch.location_ar || branch.location_en) : (branch.location_en || branch.location_ar);
		return location ? `${name} - ${location}` : name;
	}

	async function runQuery(sql: string, branchId: number): Promise<any[]> {
		const response = await fetch('/api/erp-products', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'query', branchId, sql })
		});
		const data = await response.json();
		if (!data.success) throw new Error(data.error || $t('erpLedgers.queryFailed'));
		return data.recordset || [];
	}

	// Ledger names in this ERP are frequently bilingual composites already ("Cash-الصندوق الرئيسى"),
	// unlike Products (which has separate ProductName/ItemNameinSecondLanguage columns meant for
	// per-locale switching) -- confirmed live only ~22% of ledgers even have a populated ArabicName
	// column. So this shows LedgerName/AccGroupName as-is, the same way counter names are shown
	// raw elsewhere in this app, rather than attempting an unreliable locale swap.
	async function loadLedgers(branchId: number) {
		const branch = branches.find((b) => b.branch_id === branchId);
		if (!branch) return;
		loadingLedgers = true;
		selectedLedgerId = null;
		ledgerSearch = '';
		transactions = [];
		hasRun = false;
		errorMessage = '';
		try {
			const sql = `
				SELECT l.LedgerID, l.LedgerName, g.AccGroupName
				FROM AccLedgers l
				LEFT JOIN AccGroups g ON g.AccGroupID = l.AccGroupID AND g.BranchID = l.BranchID
				WHERE l.BranchID = ${branch.erp_branch_id} AND l.IsActive = 1
				ORDER BY l.LedgerName
			`;
			const rows = await runQuery(sql, branch.branch_id);
			ledgers = rows.map((r: any) => ({
				ledgerId: Number(r.LedgerID),
				ledgerName: (r.LedgerName || '-').trim(),
				groupName: r.AccGroupName || '-'
			}));
		} catch (err: any) {
			console.error('Error loading ledgers:', err);
			errorMessage = err.message || $t('erpLedgers.failedToLoadLedgers');
			ledgers = [];
		} finally {
			loadingLedgers = false;
		}
	}

	function selectLedger(ledger: LedgerOption) {
		selectedLedgerId = ledger.ledgerId;
		ledgerSearch = ledger.ledgerName;
		showLedgerDropdown = false;
	}

	function onLedgerSearchInput() {
		showLedgerDropdown = true;
		if (selectedLedgerId != null) selectedLedgerId = null;
	}

	// Delayed so a click on a dropdown option (which also fires blur) still registers before the
	// dropdown closes.
	function onLedgerSearchBlur() {
		setTimeout(() => (showLedgerDropdown = false), 150);
	}

	async function getDetails() {
		if (!selectedBranchId || selectedLedgerId == null) return;
		if (!DATE_RE.test(dateFrom) || !DATE_RE.test(dateTo)) {
			errorMessage = $t('erpLedgers.invalidDateFormat');
			return;
		}
		const branch = branches.find((b) => b.branch_id === selectedBranchId);
		if (!branch) return;

		loading = true;
		errorMessage = '';
		transactions = [];
		filterDebitCredit = '';
		filterAmount = '';
		filterVoucherType = '';
		try {
			// Opening balance = every posted entry on this ledger before the range start, so the running
			// balance column reflects the ledger's real position going into the period, not just the
			// period's own movement.
			const openingSql = `
				SELECT ISNULL(SUM(ad.Debit), 0) AS TotalDebit, ISNULL(SUM(ad.Credit), 0) AS TotalCredit
				FROM AccTransactionDetails ad
				INNER JOIN AccTransactionMaster m ON m.AccTransactionMasterID = ad.AccTransactionMasterID AND m.BranchID = ad.BranchID
				WHERE ad.BranchID = ${branch.erp_branch_id} AND ad.LedgerID = ${selectedLedgerId}
				  AND m.TransactionDate < '${dateFrom}' AND m.IsActive = 1
			`;
			// VoucherTypeName is the ERP's own lookup table for the full name behind a voucher code (e.g.
			// CP -> "Cash Payment") -- confirmed live it carries a generic BranchID=0 row for every code
			// plus per-branch overrides, so the APPLY prefers a branch-specific name and falls back to the
			// generic one.
			const txnSql = `
				SELECT m.TransactionDate, m.VoucherType, m.VoucherPrefix, m.VoucherNumber, m.ReferenceNumber, ad.Debit, ad.Credit, ad.Narration,
					COALESCE(vtn.VoucherTypeName, m.VoucherType) AS VoucherTypeFullName
				FROM AccTransactionDetails ad
				INNER JOIN AccTransactionMaster m ON m.AccTransactionMasterID = ad.AccTransactionMasterID AND m.BranchID = ad.BranchID
				OUTER APPLY (
					SELECT TOP 1 v.VoucherTypeName
					FROM VoucherTypeName v
					WHERE v.VoucherType = m.VoucherType AND v.BranchID IN (0, ${branch.erp_branch_id})
					ORDER BY CASE WHEN v.BranchID = ${branch.erp_branch_id} THEN 0 ELSE 1 END
				) vtn
				WHERE ad.BranchID = ${branch.erp_branch_id} AND ad.LedgerID = ${selectedLedgerId}
				  AND m.TransactionDate BETWEEN '${dateFrom}' AND '${dateTo}' AND m.IsActive = 1
				ORDER BY m.TransactionDate ASC, ad.AccTransactionDetailID ASC
			`;
			const [openingRows, txnRows] = await Promise.all([
				runQuery(openingSql, branch.branch_id),
				runQuery(txnSql, branch.branch_id)
			]);

			const opening = openingRows[0] || { TotalDebit: 0, TotalCredit: 0 };
			openingBalance = (Number(opening.TotalDebit) || 0) - (Number(opening.TotalCredit) || 0);

			let running = openingBalance;
			transactions = txnRows.map((row: any) => {
				const debit = Number(row.Debit) || 0;
				const credit = Number(row.Credit) || 0;
				running += debit - credit;
				return {
					date: row.TransactionDate,
					voucherType: row.VoucherType || '-',
					voucherTypeName: row.VoucherTypeFullName || row.VoucherType || '-',
					voucherNumber: [row.VoucherPrefix, row.VoucherNumber]
						.filter((v) => v !== null && v !== undefined && v !== '')
						.join('') || '-',
					billNumber: row.VoucherType === 'PI' && row.ReferenceNumber ? String(row.ReferenceNumber) : null,
					narration: row.Narration || '-',
					debit,
					credit,
					balance: running
				};
			});
			hasRun = true;
		} catch (err: any) {
			console.error('Error loading ledger details:', err);
			errorMessage = err.message || $t('erpLedgers.failedToLoadDetails');
		} finally {
			loading = false;
		}
	}

	function formatAmount(n: number): string {
		return (n || 0).toFixed(2);
	}

	// Opens the Send popup for a PI row, prefilled from that transaction.
	function openSendModal(row: LedgerTxn) {
		sendModalRow = row;
		sendBillAmount = formatAmount(row.debit || row.credit);
		sendPaymentType = 'bank';
		sendBankLedgerId = null;
		sendJvLedgerId = null;
		sendJvSearch = '';
		showJvDropdown = false;
		sendAssigneeId = null;
		sendDefaultAssigneeId = null;
		showSendModal = true;
		loadSendAssignee(row);
	}

	// Loads the selectable users and the branch's default Entry Task user, and pre-selects that
	// default unless the sender already picked someone while this was loading. A default that is
	// no longer an active user is ignored (field stays empty) rather than assigned to a dead account.
	async function loadSendAssignee(row: LedgerTxn) {
		if (selectedBranchId == null) return;
		const branchId = selectedBranchId;
		sendUsersLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { loadSelectableUsers } = await import('$lib/utils/entryTaskUsers');
			const [users, defaultRes] = await Promise.all([
				sendUsers.length ? Promise.resolve(sendUsers) : loadSelectableUsers(),
				supabase
					.from('branch_default_positions')
					.select('entry_task_user_id')
					.eq('branch_id', branchId)
					.maybeSingle()
			]);
			sendUsers = users;
			if (sendModalRow !== row) return;
			if (defaultRes.error) throw defaultRes.error;
			const defaultId: string | null = defaultRes.data?.entry_task_user_id ?? null;
			if (defaultId && users.some((u) => u.id === defaultId)) {
				sendDefaultAssigneeId = defaultId;
				if (sendAssigneeId == null) sendAssigneeId = defaultId;
			}
		} catch (err) {
			console.error('Error loading ERP entry task assignee:', err);
		} finally {
			sendUsersLoading = false;
		}
	}

	function closeSendModal() {
		showSendModal = false;
		sendModalRow = null;
		sendBillAmount = '';
		sendPaymentType = 'bank';
		sendBankLedgerId = null;
		sendJvLedgerId = null;
		sendJvSearch = '';
		showJvDropdown = false;
		sendSubmitting = false;
		sendError = '';
		sendAssigneeId = null;
		sendDefaultAssigneeId = null;
	}

	function selectJvLedger(ledger: LedgerOption) {
		sendJvLedgerId = ledger.ledgerId;
		sendJvSearch = ledger.ledgerName;
		showJvDropdown = false;
	}

	function onJvSearchInput() {
		showJvDropdown = true;
		if (sendJvLedgerId != null) sendJvLedgerId = null;
	}

	// Delayed so a click on an option (which also blurs the input) still registers first.
	function onJvSearchBlur() {
		setTimeout(() => (showJvDropdown = false), 150);
	}

	// Creates an ERP Entry Task via create_erp_entry_task(): plugs into the same generic
	// tasks/task_assignments engine the rest of the app's Tasks system uses, so this shows up
	// in My Tasks / mobile Tasks / Branch Performance like any other task. Completion (entering
	// the payment voucher number) happens later from there, via the shared TaskCompletionModal.
	async function submitSend() {
		if (!sendModalRow || sendSubmitting) return;
		sendError = '';

		const amount = Number(sendBillAmount);
		if (!amount || amount <= 0) {
			sendError = 'Enter a valid bill amount';
			return;
		}
		if (sendPaymentType === 'bank' && sendBankLedgerId == null) {
			sendError = 'Select a bank account';
			return;
		}
		if (sendPaymentType === 'jv' && sendJvLedgerId == null) {
			sendError = 'Select a credit account';
			return;
		}
		if (!sendAssigneeId) {
			sendError = 'Select a user to assign the task to';
			return;
		}
		const user = $currentUser;
		if (!user) {
			sendError = 'Not logged in';
			return;
		}

		sendSubmitting = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			// Credit side: the bank ledger for bank, the searched-and-picked ledger for JV, none for cash.
			const creditLedger =
				sendPaymentType === 'bank'
					? bankLedgers.find((b) => b.ledgerId === sendBankLedgerId)
					: sendPaymentType === 'jv'
						? ledgers.find((l) => l.ledgerId === sendJvLedgerId)
						: null;

			const { data, error } = await supabase.rpc('create_erp_entry_task', {
				p_branch_id: selectedBranchId,
				p_ledger_name: selectedLedger?.ledgerName || '-',
				p_bill_number: sendModalRow.billNumber,
				p_voucher_number: sendModalRow.voucherNumber,
				p_bill_amount: amount,
				p_payment_type: sendPaymentType,
				p_bank_ledger_id: creditLedger?.ledgerId ?? null,
				p_bank_ledger_name: creditLedger?.ledgerName ?? null,
				p_created_by: user.id,
				p_created_by_name: user.employeeName || user.username,
				p_original_bill_amount: sendModalRow.debit || sendModalRow.credit,
				p_assigned_to: sendAssigneeId
			});

			if (error) throw error;
			if (data?.success === false) throw new Error(data?.error || 'Failed to create ERP entry task');

			// The RPC only creates the in-app notification row; actual push delivery is client-driven
			// (same as every other notification in the app), via the send-push-notification edge function.
			if (data?.notification_id) {
				try {
					const { sendPushForNotification } = await import('$lib/utils/pushNotificationSender');
					await sendPushForNotification(
						data.notification_id,
						'ERP Entry Task | مهمة إدخال ERP',
						'You have an ERP Entry task. --- لديك مهمة إدخال ERP.',
						{ url: `/notifications?id=${data.notification_id}`, type: 'task_assigned' },
						{
							titleEn: 'ERP Entry Task',
							bodyEn: 'You have an ERP Entry task.',
							titleAr: 'مهمة إدخال ERP',
							bodyAr: 'لديك مهمة إدخال ERP.'
						}
					);
				} catch (pushErr) {
					console.error('Failed to send ERP entry push notification:', pushErr);
				}
			}

			closeSendModal();
		} catch (err: any) {
			console.error('Error creating ERP entry task:', err);
			sendError = err.message || 'Failed to send';
		} finally {
			sendSubmitting = false;
		}
	}

	// Signed running balance shown with the accounting Dr/Cr suffix instead of a +/- sign.
	function formatBalance(n: number): string {
		const abs = Math.abs(n || 0).toFixed(2);
		if (Math.abs(n || 0) < 0.005) return abs;
		return n > 0 ? `${abs} ${$t('erpLedgers.dr')}` : `${abs} ${$t('erpLedgers.cr')}`;
	}

	function formatDate(iso: string): string {
		const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || '');
		if (!match) return iso;
		const [, year, month, day] = match;
		return `${day}-${month}-${year}`;
	}

	// Exports exactly what's currently on screen (post Debit/Credit/Voucher-Type/Amount filters), not
	// the full unfiltered period -- matches what the user is looking at, same as
	// UserActionReports.svelte's exportCanceledProducts.
	async function exportToExcel() {
		if (exporting || loading || !filteredTransactions.length) return;
		exporting = true;
		try {
			const XLSX = await import('xlsx');
			const workbook = XLSX.utils.book_new();
			const rows = filteredTransactions.map((r) => ({
				Date: formatDate(r.date),
				'Voucher Type': r.voucherTypeName,
				'Voucher Code': r.voucherType,
				'Voucher #': r.voucherNumber,
				'Bill #': r.billNumber || '',
				Narration: r.narration,
				Debit: r.debit,
				Credit: r.credit,
				Balance: r.balance
			}));
			const sheet = XLSX.utils.json_to_sheet(rows);
			sheet['!cols'] = Object.keys(rows[0] || {}).map((key) => ({
				wch: key === 'Narration' ? 45 : key === 'Voucher Type' ? 22 : 14
			}));
			if (sheet['!ref']) sheet['!autofilter'] = { ref: sheet['!ref'] };
			XLSX.utils.book_append_sheet(workbook, sheet, $t('erpLedgers.transactions'));
			const ledgerNamePart = (selectedLedger?.ledgerName || 'ledger').replace(/[\\/:*?"<>|]+/g, ' ').trim().slice(0, 40);
			XLSX.writeFile(workbook, `${ledgerNamePart}_${dateFrom}_${dateTo}.xlsx`);
		} catch (err) {
			console.error('Error exporting ledger to Excel:', err);
			errorMessage = $t('erpLedgers.exportFailed');
		} finally {
			exporting = false;
		}
	}
</script>

<div class="erp-ledgers">
	<div class="bg-blob blob-1"></div>
	<div class="bg-blob blob-2"></div>

	<div class="filters-panel">
		<div class="filter-field">
			<label for="ledger-branch-select">{$t('common.branch')}</label>
			<select id="ledger-branch-select" bind:value={selectedBranchId} disabled={loadingBranches}>
				{#each branches as b}
					<option value={b.branch_id}>{getBranchDisplayName(b)}</option>
				{/each}
			</select>
		</div>

		<div class="filter-field ledger-search-field">
			<label for="ledger-search">{$t('erpLedgers.ledger')}</label>
			<div class="ledger-search-wrap">
				<input
					id="ledger-search"
					type="text"
					autocomplete="off"
					placeholder={loadingLedgers ? $t('erpLedgers.loadingLedgers') : $t('erpLedgers.searchLedgerPlaceholder')}
					bind:value={ledgerSearch}
					on:focus={() => (showLedgerDropdown = true)}
					on:input={onLedgerSearchInput}
					on:blur={onLedgerSearchBlur}
					disabled={loadingLedgers || ledgers.length === 0}
				/>
				{#if showLedgerDropdown && filteredLedgers.length > 0}
					<div class="ledger-dropdown">
						{#each filteredLedgers.slice(0, 50) as ledger (ledger.ledgerId)}
							<button type="button" class="ledger-option" on:click={() => selectLedger(ledger)}>
								<span class="ledger-option-name">{ledger.ledgerName}</span>
								<span class="ledger-option-type">{ledger.groupName}</span>
							</button>
						{/each}
						{#if filteredLedgers.length > 50}
							<div class="ledger-option-more">{$t('erpLedgers.moreResults')}</div>
						{/if}
					</div>
				{/if}
			</div>
		</div>

		<div class="filter-field">
			<label for="ledger-date-from">{$t('erpLedgers.fromLabel')}</label>
			<input id="ledger-date-from" type="date" bind:value={dateFrom} />
		</div>
		<div class="filter-field">
			<label for="ledger-date-to">{$t('erpLedgers.toLabel')}</label>
			<input id="ledger-date-to" type="date" bind:value={dateTo} />
		</div>

		<button class="run-btn" on:click={getDetails} disabled={loading || selectedLedgerId == null}>
			{loading ? $t('erpLedgers.fetching') : $t('erpLedgers.getDetails')}
		</button>
	</div>

	{#if selectedLedger}
		<div class="selected-ledger-banner">
			<strong>{selectedLedger.ledgerName}</strong>
			<span class="selected-ledger-type">{selectedLedger.groupName}</span>
		</div>
	{/if}

	{#if errorMessage}
		<div class="error-banner">{errorMessage}</div>
	{/if}

	{#if hasRun}
		<div class="summary-cards">
			<div class="summary-card">
				<span class="summary-label">{$t('erpLedgers.openingBalance')}</span>
				<span class="summary-value">{formatBalance(openingBalance)}</span>
			</div>
			<div class="summary-card">
				<span class="summary-label">{$t('erpLedgers.totalDebit')}</span>
				<span class="summary-value">{formatAmount(totalDebit)}</span>
			</div>
			<div class="summary-card">
				<span class="summary-label">{$t('erpLedgers.totalCredit')}</span>
				<span class="summary-value">{formatAmount(totalCredit)}</span>
			</div>
			<div class="summary-card highlight">
				<span class="summary-label">{$t('erpLedgers.closingBalance')}</span>
				<span class="summary-value">{formatBalance(closingBalance)}</span>
			</div>
		</div>

		<div class="section-block">
			<div class="section-title-row">
				<h3 class="section-title">{$t('erpLedgers.transactions')}</h3>
				{#if transactions.length > 0}
					<div class="table-filters">
						<select bind:value={filterDebitCredit} title={$t('erpLedgers.filterByDebitCredit')}>
							<option value="">{$t('erpLedgers.filterAll')}</option>
							<option value="debit">{$t('erpLedgers.filterDebitOnly')}</option>
							<option value="credit">{$t('erpLedgers.filterCreditOnly')}</option>
						</select>
						<select bind:value={filterVoucherType} title={$t('erpLedgers.filterByVoucherType')}>
							<option value="">{$t('erpLedgers.allVoucherTypes')}</option>
							{#each voucherTypeFilterOptions as [code, name] (code)}
								<option value={code}>{name}</option>
							{/each}
						</select>
						<input
							type="text"
							inputmode="decimal"
							class="amount-filter-input"
							placeholder={$t('erpLedgers.filterAmountPlaceholder')}
							bind:value={filterAmount}
						/>
						<button class="export-btn" type="button" on:click={exportToExcel} disabled={exporting || filteredTransactions.length === 0}>
							{exporting ? $t('erpLedgers.exporting') : $t('erpLedgers.exportToExcel')}
						</button>
					</div>
				{/if}
			</div>
			{#if transactions.length === 0}
				<div class="empty-state">{$t('erpLedgers.noTransactions')}</div>
			{:else if filteredTransactions.length === 0}
				<div class="empty-state">{$t('erpLedgers.noFilterResults')}</div>
			{:else}
				<div class="table-wrapper">
					<table>
						<thead>
							<tr>
								<th>{$t('erpLedgers.colDate')}</th>
								<th>{$t('erpLedgers.colVoucherType')}</th>
								<th>{$t('erpLedgers.colVoucherNumber')}</th>
								<th>{$t('erpLedgers.colNarration')}</th>
								<th>{$t('erpLedgers.colDebit')}</th>
								<th>{$t('erpLedgers.colCredit')}</th>
								<th>{$t('erpLedgers.colBalance')}</th>
								<th>{$currentLocale === 'ar' ? 'المهمة' : 'Task'}</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredTransactions as row}
								<tr>
									<td>{formatDate(row.date)}</td>
									<td>
										{row.voucherTypeName}
										{#if row.voucherTypeName !== row.voucherType}
											<span class="voucher-code">({row.voucherType})</span>
										{/if}
										{#if row.billNumber}
											<br /><span class="bill-number">{$t('erpLedgers.billNumberLine', { number: row.billNumber })}</span>
										{/if}
									</td>
									<td>{row.voucherNumber}</td>
									<td>{row.narration}</td>
									<td class="amount-cell">{row.debit ? formatAmount(row.debit) : '-'}</td>
									<td class="amount-cell">{row.credit ? formatAmount(row.credit) : '-'}</td>
									<td class="amount-cell">{formatBalance(row.balance)}</td>
									<td>
										{#if row.voucherType === 'PI'}
											<button class="send-btn" type="button" on:click={() => openSendModal(row)}>Send</button>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{:else if !loading}
		<div class="empty-state">
			{ledgers.length === 0 && !loadingLedgers
				? $t('erpLedgers.noLedgersForBranch')
				: $t('erpLedgers.selectLedgerPrompt')}
		</div>
	{/if}
</div>

{#if showSendModal && sendModalRow}
	<div class="modal-overlay" on:click={closeSendModal}>
		<div class="modal-content send-modal" on:click={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<h3>Send</h3>
				<button class="modal-close-btn" type="button" on:click={closeSendModal}>✕</button>
			</div>

			<div class="modal-body">
				<div class="form-group">
					<label for="send-ledger-name">Ledger Name</label>
					<input id="send-ledger-name" type="text" value={selectedLedger?.ledgerName || '-'} readonly />
				</div>
				<div class="form-group">
					<label for="send-bill-number">Bill Number</label>
					<input id="send-bill-number" type="text" value={sendModalRow.billNumber || '-'} readonly />
				</div>
				<div class="form-group">
					<label for="send-voucher-number">Voucher Number</label>
					<input id="send-voucher-number" type="text" value={sendModalRow.voucherNumber} readonly />
				</div>
				<div class="form-group">
					<label for="send-bill-amount">Bill Amount</label>
					<input id="send-bill-amount" type="number" step="0.01" bind:value={sendBillAmount} />
				</div>
				<div class="form-group">
					<label>Payment Type</label>
					<div class="payment-type-toggle">
						<button
							type="button"
							class="payment-type-btn"
							class:active={sendPaymentType === 'cash'}
							on:click={() => (sendPaymentType = 'cash')}
						>
							Cash
						</button>
						<button
							type="button"
							class="payment-type-btn"
							class:active={sendPaymentType === 'bank'}
							on:click={() => (sendPaymentType = 'bank')}
						>
							Bank
						</button>
						<button
							type="button"
							class="payment-type-btn"
							class:active={sendPaymentType === 'jv'}
							on:click={() => (sendPaymentType = 'jv')}
						>
							JV
						</button>
					</div>
				</div>
				{#if sendPaymentType === 'jv'}
					<div class="form-group">
						<label for="send-jv-ledger">Credit Account</label>
						<div class="jv-search-wrap">
							<input
								id="send-jv-ledger"
								type="text"
								autocomplete="off"
								placeholder={loadingLedgers ? 'Loading ledgers...' : 'Search and select a ledger'}
								bind:value={sendJvSearch}
								on:focus={() => (showJvDropdown = true)}
								on:input={onJvSearchInput}
								on:blur={onJvSearchBlur}
								disabled={loadingLedgers || ledgers.length === 0}
							/>
							{#if showJvDropdown && jvCandidates.length > 0}
								<div class="ledger-dropdown jv-dropdown">
									{#each jvCandidates.slice(0, 50) as ledger (ledger.ledgerId)}
										<button type="button" class="ledger-option" on:click={() => selectJvLedger(ledger)}>
											<span class="ledger-option-name">{ledger.ledgerName}</span>
											<span class="ledger-option-type">{ledger.groupName}</span>
										</button>
									{/each}
									{#if jvCandidates.length > 50}
										<div class="ledger-option-more">{$t('erpLedgers.moreResults')}</div>
									{/if}
								</div>
							{/if}
						</div>
					</div>
				{/if}
				{#if sendPaymentType === 'bank'}
					<div class="form-group">
						<label for="send-bank-ledger">Bank Account</label>
						<select id="send-bank-ledger" bind:value={sendBankLedgerId}>
							<option value={null} disabled selected>Select bank account</option>
							{#each bankLedgers as bank (bank.ledgerId)}
								<option value={bank.ledgerId}>{bank.ledgerName}</option>
							{/each}
						</select>
						{#if bankLedgers.length === 0}
							<div class="no-bank-ledgers">No bank account ledgers found for this branch</div>
						{/if}
					</div>
				{/if}
				<div class="form-group">
					<label for="send-assignee">Assign To</label>
					<EntryTaskUserPicker
						inputId="send-assignee"
						users={sendUsers}
						loading={sendUsersLoading}
						bind:value={sendAssigneeId}
						placeholder="Search and select a user"
					/>
					{#if sendAssigneeId && sendAssigneeId === sendDefaultAssigneeId}
						<div class="assignee-hint">Default Entry Task user for this branch</div>
					{:else if sendAssigneeId}
						<div class="assignee-hint">Selected for this task only (branch default unchanged)</div>
					{:else if !sendUsersLoading}
						<div class="assignee-hint warn">
							{sendDefaultAssigneeId === null ? 'No default Entry Task user is set for this branch. ' : ''}Select who this task is assigned to.
						</div>
					{/if}
				</div>
			</div>

			<div class="modal-footer">
				{#if sendError}
					<div class="send-error">{sendError}</div>
				{/if}
				<button class="send-modal-btn" type="button" on:click={submitSend} disabled={sendSubmitting}>
					{sendSubmitting ? 'Sending...' : 'Send'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.erp-ledgers {
		position: relative;
		width: 100%;
		height: 100%;
		overflow: hidden;
		padding: 1.25rem;
		background: linear-gradient(135deg, #fff5f5 0%, #fff0f0 50%, #fef2f2 100%);
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.bg-blob {
		position: fixed;
		border-radius: 50%;
		pointer-events: none;
		filter: blur(60px);
		opacity: 0.35;
		z-index: 0;
	}
	.blob-1 { width: 300px; height: 300px; background: rgba(239, 68, 68, 0.25); top: -80px; right: -60px; }
	.blob-2 { width: 260px; height: 260px; background: rgba(252, 165, 165, 0.3); bottom: -60px; left: -60px; }

	.filters-panel, .summary-cards, .section-block, .error-banner, .empty-state, .selected-ledger-banner {
		position: relative;
		z-index: 1;
	}
	/* .filters-panel hosts the ledger search dropdown, which is absolutely positioned and extends past
	   the panel's own bottom edge -- it must out-stack every sibling below it (summary-cards,
	   section-block, empty-state, etc.), not just match their z-index. Two siblings at the same z-index
	   stack by DOM order, so whichever of those renders (e.g. the "select a ledger" empty-state) was
	   sitting on TOP of the dropdown and silently eating clicks on any ledger row that fell under it. */
	.filters-panel {
		z-index: 5;
	}

	/* Everything above the transactions table is fixed height and never scrolls -- only
	   .table-wrapper below does, so a long statement doesn't push the filters off-screen. */
	.filters-panel, .selected-ledger-banner, .error-banner, .summary-cards {
		flex-shrink: 0;
	}

	.filters-panel {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: 0.85rem;
		padding: 1rem 1.25rem;
		background: rgba(255, 255, 255, 0.5);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(254, 202, 202, 0.6);
		border-radius: 16px;
		box-shadow: 0 6px 18px rgba(220, 38, 38, 0.06);
	}

	.filter-field { display: flex; flex-direction: column; gap: 0.3rem; min-width: 140px; }
	.ledger-search-field { min-width: 260px; flex: 1 1 260px; position: relative; }
	.filter-field label {
		font-size: 0.72rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; color: #b91c1c;
	}
	.filter-field select, .filter-field input {
		padding: 0.5rem 0.7rem;
		border-radius: 10px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		background: rgba(255, 255, 255, 0.8);
		font-size: 0.85rem;
		color: #7f1d1d;
		width: 100%;
		box-sizing: border-box;
	}
	.filter-field select:focus, .filter-field input:focus {
		outline: none;
		border-color: #ef4444;
	}

	.ledger-search-wrap { position: relative; }
	.ledger-dropdown {
		position: absolute;
		top: calc(100% + 4px);
		left: 0;
		right: 0;
		max-height: 280px;
		overflow-y: auto;
		background: #fff;
		border: 1px solid rgba(252, 165, 165, 0.8);
		border-radius: 10px;
		box-shadow: 0 10px 30px rgba(127, 29, 29, 0.18);
		z-index: 20;
	}
	.ledger-option {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		width: 100%;
		padding: 0.5rem 0.75rem;
		border: none;
		background: none;
		cursor: pointer;
		text-align: left;
		border-bottom: 1px solid rgba(254, 202, 202, 0.5);
	}
	.ledger-option:hover { background: rgba(254, 226, 226, 0.6); }
	.ledger-option-name { font-size: 0.82rem; font-weight: 600; color: #7f1d1d; }
	.ledger-option-type { font-size: 0.68rem; color: #b91c1c; opacity: 0.8; }
	.ledger-option-more { padding: 0.4rem 0.75rem; font-size: 0.7rem; color: #b91c1c; opacity: 0.7; }

	.run-btn {
		padding: 0.6rem 1.4rem;
		border: none;
		border-radius: 10px;
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: #fff;
		font-weight: 700;
		font-size: 0.85rem;
		cursor: pointer;
	}
	.run-btn:disabled { opacity: 0.55; cursor: not-allowed; }

	.selected-ledger-banner {
		display: flex;
		align-items: baseline;
		gap: 0.6rem;
		padding: 0.6rem 1.1rem;
		background: rgba(254, 226, 226, 0.55);
		border: 1px solid rgba(252, 165, 165, 0.7);
		border-radius: 12px;
		color: #7f1d1d;
		font-size: 0.85rem;
	}
	.selected-ledger-type { font-size: 0.72rem; color: #b91c1c; opacity: 0.8; }

	.error-banner {
		padding: 0.75rem 1rem;
		background: rgba(254, 226, 226, 0.7);
		border: 1px solid #fca5a5;
		border-radius: 12px;
		color: #b91c1c;
		font-size: 0.85rem;
		font-weight: 600;
	}

	.summary-cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
		gap: 0.75rem;
	}
	.summary-card {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		padding: 0.85rem 1rem;
		background: rgba(255, 255, 255, 0.6);
		border: 1px solid rgba(254, 202, 202, 0.6);
		border-radius: 14px;
	}
	.summary-card.highlight {
		background: rgba(239, 68, 68, 0.08);
		border-color: rgba(239, 68, 68, 0.35);
	}
	.summary-label {
		font-size: 0.68rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		color: #b91c1c;
	}
	.summary-value { font-size: 1.1rem; font-weight: 700; color: #7f1d1d; }

	.section-block {
		background: rgba(255, 255, 255, 0.55);
		border: 1px solid rgba(254, 202, 202, 0.6);
		border-radius: 16px;
		padding: 1rem 1.1rem;
		position: relative;
		z-index: 1;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
	}
	.section-title { margin: 0; font-size: 0.95rem; font-weight: 700; color: #7f1d1d; }
	.section-title-row {
		flex-shrink: 0;
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: 0.6rem;
		margin-bottom: 0.75rem;
	}
	.table-filters { display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem; }
	.table-filters select,
	.table-filters .amount-filter-input {
		padding: 0.4rem 0.6rem;
		border-radius: 8px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		background: rgba(255, 255, 255, 0.8);
		font-size: 0.78rem;
		color: #7f1d1d;
	}
	.table-filters .amount-filter-input { width: 140px; }
	.table-filters select:focus,
	.table-filters .amount-filter-input:focus { outline: none; border-color: #ef4444; }
	.export-btn {
		padding: 0.4rem 0.9rem;
		border: none;
		border-radius: 8px;
		background: linear-gradient(135deg, #16a34a, #15803d);
		color: #fff;
		font-weight: 700;
		font-size: 0.76rem;
		cursor: pointer;
	}
	.export-btn:disabled { opacity: 0.55; cursor: not-allowed; }
	.voucher-code { font-size: 0.72rem; color: #b91c1c; opacity: 0.75; }
	.bill-number { font-size: 0.72rem; color: #7c2d12; font-weight: 600; }
	.send-btn {
		padding: 0.32rem 0.75rem;
		border: none;
		border-radius: 8px;
		background: linear-gradient(135deg, #2563eb, #1d4ed8);
		color: #fff;
		font-weight: 700;
		font-size: 0.74rem;
		cursor: pointer;
	}

	.table-wrapper { flex: 1; min-height: 0; overflow: auto; border-radius: 12px; border: 1px solid rgba(254, 202, 202, 0.6); }
	table { width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 0.82rem; }
	/* Fixed layout so Debit/Credit/Balance stay evenly spaced instead of bunching against
	   Narration's leftover width -- percentages sum to 100%. */
	th:nth-child(1), td:nth-child(1) { width: 9%; }
	th:nth-child(2), td:nth-child(2) { width: 15%; }
	th:nth-child(3), td:nth-child(3) { width: 8%; }
	th:nth-child(4), td:nth-child(4) { width: 21%; }
	th:nth-child(5), td:nth-child(5) { width: 11%; }
	th:nth-child(6), td:nth-child(6) { width: 11%; }
	th:nth-child(7), td:nth-child(7) { width: 15%; }
	th:nth-child(8), td:nth-child(8) { width: 10%; }
	thead th {
		position: sticky;
		top: 0;
		z-index: 2;
		text-align: left;
		padding: 0.55rem 0.7rem;
		background: #fee2e2;
		color: #991b1b;
		font-weight: 700;
		text-transform: uppercase;
		font-size: 0.68rem;
		letter-spacing: 0.3px;
		border-right: 1px solid rgba(252, 165, 165, 0.6);
		border-bottom: 1px solid rgba(252, 165, 165, 0.6);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	thead th:last-child { border-right: none; }
	tbody td {
		padding: 0.5rem 0.7rem;
		border-bottom: 1px solid rgba(254, 202, 202, 0.4);
		border-right: 1px solid rgba(254, 202, 202, 0.4);
		color: #7f1d1d;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	tbody td:last-child { border-right: none; }
	/* Narration is the one column worth reading in full -- wrap it instead of ellipsis-ing it away. */
	tbody td:nth-child(2), tbody td:nth-child(4) { white-space: normal; overflow-wrap: break-word; }
	.amount-cell { font-weight: 700; text-align: right; }

	.empty-state {
		text-align: center;
		padding: 2rem;
		color: #b91c1c;
		font-size: 0.9rem;
		opacity: 0.85;
	}

	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}
	.modal-content.send-modal {
		background: #fff;
		border-radius: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		display: flex;
		flex-direction: column;
		width: 520px;
		max-width: 92vw;
	}
	.jv-search-wrap { position: relative; }
	.jv-dropdown { max-height: 220px; }
	.modal-header {
		padding: 16px 20px;
		background: linear-gradient(135deg, #ef4444, #b91c1c);
		color: #fff;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-radius: 12px 12px 0 0;
	}
	.modal-header h3 { margin: 0; font-size: 16px; font-weight: 700; }
	.modal-close-btn {
		background: rgba(255, 255, 255, 0.2);
		border: none;
		color: #fff;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		font-size: 15px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.modal-close-btn:hover { background: rgba(255, 255, 255, 0.3); }
	.modal-body {
		padding: 20px;
		display: flex;
		flex-direction: column;
		gap: 14px;
	}
	.form-group { display: flex; flex-direction: column; gap: 6px; }
	.form-group label { font-size: 0.78rem; font-weight: 700; color: #7f1d1d; }
	.form-group input {
		padding: 0.5rem 0.7rem;
		border-radius: 8px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		font-size: 0.85rem;
		color: #7f1d1d;
	}
	.form-group input:focus { outline: none; border-color: #ef4444; }
	.form-group input[readonly] { background: #fef2f2; color: #991b1b; cursor: not-allowed; }
	.form-group select {
		padding: 0.5rem 0.7rem;
		border-radius: 8px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		font-size: 0.85rem;
		color: #7f1d1d;
		background: #fff;
	}
	.form-group select:focus { outline: none; border-color: #ef4444; }
	.no-bank-ledgers { font-size: 0.74rem; color: #b91c1c; opacity: 0.8; }
	.assignee-hint { font-size: 0.72rem; color: #15803d; }
	.assignee-hint.warn { color: #b45309; }
	.payment-type-toggle { display: flex; gap: 8px; }
	.payment-type-btn {
		flex: 1;
		padding: 0.5rem 0.7rem;
		border-radius: 8px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		background: #fff;
		color: #7f1d1d;
		font-weight: 700;
		font-size: 0.82rem;
		cursor: pointer;
	}
	.payment-type-btn.active {
		background: linear-gradient(135deg, #ef4444, #b91c1c);
		border-color: #b91c1c;
		color: #fff;
	}
	.modal-footer {
		padding: 16px 20px;
		border-top: 1px solid rgba(254, 202, 202, 0.6);
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: 12px;
	}
	.send-error { font-size: 0.78rem; color: #dc2626; font-weight: 600; flex: 1; }
	.send-modal-btn {
		padding: 0.5rem 1.2rem;
		border: none;
		border-radius: 8px;
		background: linear-gradient(135deg, #2563eb, #1d4ed8);
		color: #fff;
		font-weight: 700;
		font-size: 0.85rem;
		cursor: pointer;
	}
	.send-modal-btn:disabled { opacity: 0.6; cursor: not-allowed; }
</style>
