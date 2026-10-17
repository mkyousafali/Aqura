<script lang="ts">
	import * as XLSX from 'xlsx';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { currentUser } from '$lib/utils/persistentAuth';

	type StatementRow = {
		rowNumber: number; date: unknown; description: string; details: string; reference: string;
		terminalId: string; debit: string; credit: string; balance: string; code: string; children: StatementRow[];
	};

	let bank = '';
	let activeTab: 'process' | 'accounts' | 'bank-accounts' | 'terminals' | 'task-status' = 'process';
	let configuredBankAccounts: any[] = [];
	let selectedStatementBankAccountId = '';
	let showBankAccountForm = false;
	let bankAccountBranchSearch = '';
	let bankAccountBranchId: number | null = null;
	let bankAccountBank = '';
	let bankAccountLedgerChoices: any[] = [];
	let bankAccountLedgerSearch = '';
	let selectedConfiguredLedger: any = null;
	let editingBankAccountId: string | null = null;
	let loadingConfiguredLedgers = false;
	let savingConfiguredBankAccount = false;
	let fileInput: HTMLInputElement;
	let fileName = '';
	let errorMessage = '';
	let isImporting = false;
	let statementRows: StatementRow[] = [];
	let rawTransactionCount = 0;
	let processingFeeCount = 0;
	let vatCount = 0;
	let transactionView = '';
	let transactionViewOptions: { description: string; count: number; isPos: boolean }[] = [];
	let selectedTransactionViewIsPos = false;
	let terminalFilter = '';
	let terminalOptions: string[] = [];
	let dateFilter = '';
	let dateOptions: string[] = [];
	let showFullDateJournal = false;
	let selectedFullJournalBranch = '';
	let savedStatementMjv: any = null;
	let savingStatementMjv = false;
	let postingStatementTasks = false;
	let statementWorkflowMessage = '';
	let taskStatusDate = '';
	let taskStatusMonth = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Riyadh' }).format(new Date()).slice(0, 7);
	let taskGoToDay = '';
	let taskGoToMonth = '';
	let taskGoToYear = '';
	let taskStatusRows: any[] = [];
	let taskMonthConfiguredBankCount = 0;
	let taskMonthCounts: Record<string, number> = {};
	let loadingTaskStatus = false;
	let taskStatusError = '';
	let deletingStatementItem = '';
	let expandedSavedMjvRows = new Set<string>();
	let savedMjvDetails: Record<string, any> = {};
	let loadingSavedMjvId = '';
	let filteredStatementRows: StatementRow[] = [];
	let branches: any[] = [];
	let terminalAccounts: any[] = [];
	let bankAccounts: any[] = [];
	let showAccountForm = false;
	let branchSearch = '';
	let selectedBranchId: number | null = null;
	let activeBranchSearch = '';
	let selectedActiveBranchId: number | null = null;
	let selectedBankLedgerId = '';
	let terminalIdInput = '';
	let accountMessage = '';
	let accountError = '';
	let loadingBankAccounts = false;
	let savingTerminal = false;
	let editingTerminalId: string | null = null;
	let postingAccounts: any[] = [];
	let showPostingForm = false;
	let postingBranchSearch = '';
	let postingBranchId: number | null = null;
	let ledgerChoices: Record<string, any[]> = { vat: [], riyad: [], ahli: [] };
	let ledgerSearches: Record<string, string> = { vat: '', riyad: '', ahli: '' };
	let selectedLedgers: Record<string, any | null> = { vat: null, riyad: null, ahli: null };
	let searchingLedger = '';
	let savingPostingAccounts = false;
	let previewAccounts: any = { pos_accounts: [], cross_branch_accounts: [] };
	let expandedEntryRows = new Set<number>();

	$: terminalOptions = Array.from(new Set(statementRows
		.map((row) => bank === 'riyad' ? row.terminalId.slice(0, 8) : row.terminalId)
		.filter(Boolean))).sort((left, right) => left.localeCompare(right, undefined, { numeric: true }));
	$: dateOptions = Array.from(new Set(statementRows.map((row) => displayDate(row.date)).filter(Boolean)));
	$: transactionViewOptions = Array.from(statementRows.reduce((types, row) => {
		const description = transactionViewLabel(row);
		const existing = types.get(description);
		if (existing) existing.count += 1;
		else types.set(description, { description, count: 1, isPos: isPosTransaction(row) });
		return types;
	}, new Map<string, { description: string; count: number; isPos: boolean }>()).values());
	$: selectedTransactionViewIsPos = transactionViewOptions.find((option) => option.description === transactionView)?.isPos ?? false;
	$: filteredStatementRows = statementRows.filter((row) =>
		transactionViewLabel(row) === transactionView
		&&
		(!terminalFilter || (bank === 'riyad' ? row.terminalId.slice(0, 8) : row.terminalId) === terminalFilter)
		&& (!dateFilter || displayDate(row.date) === dateFilter)
	);

	onMount(async () => {
		const branchResult = await supabase.from('branches').select('id,name_en,name_ar,location_en,location_ar').eq('is_active', true).order('name_en');
		if (!branchResult.error) branches = branchResult.data || [];
		await loadTerminalAccounts();
	});

	async function loadTerminalAccounts() {
		const [terminalResult, postingResult, previewResult, bankAccountResult] = await Promise.all([
			supabase.rpc('get_statement_terminal_accounts'),
			supabase.rpc('get_statement_posting_accounts'),
			supabase.rpc('get_statement_entry_preview_accounts'),
			supabase.rpc('get_statement_bank_accounts')
		]);
		if (terminalResult.error) accountError = terminalResult.error.message;
		else terminalAccounts = terminalResult.data || [];
		if (postingResult.error) accountError = postingResult.error.message;
		else postingAccounts = postingResult.data || [];
		if (!previewResult.error) previewAccounts = previewResult.data || { pos_accounts: [], cross_branch_accounts: [] };
		if (!bankAccountResult.error) configuredBankAccounts = bankAccountResult.data || [];
	}

	async function loadTaskStatus() {
		if (!taskStatusDate) { taskStatusRows = []; return; }
		loadingTaskStatus = true; taskStatusError = '';
		const { data, error } = await supabase.rpc('get_statement_task_status', { p_statement_date: taskStatusDate });
		if (error) { taskStatusError = error.message; taskStatusRows = []; }
		else taskStatusRows = data || [];
		loadingTaskStatus = false;
	}

	async function openTaskStatus() {
		activeTab = 'task-status';
		await Promise.all([loadTaskStatus(), loadTaskMonthCounts()]);
	}

	async function loadTaskMonthCounts() {
		const { data, error } = await supabase.rpc('get_statement_task_month_counts', { p_month: `${taskStatusMonth}-01` });
		if (error) { taskStatusError = error.message; taskMonthConfiguredBankCount = 0; taskMonthCounts = {}; return; }
		taskMonthConfiguredBankCount = Number(data?.configured_bank_count || 0);
		taskMonthCounts = Object.fromEntries((data?.dates || []).map((item: any) => [String(item.date).slice(0, 10), Number(item.saved_bank_count || 0)]));
	}

	function taskCalendarDays(monthValue: string): { iso: string; day: number; currentMonth: boolean }[] {
		const [year, month] = monthValue.split('-').map(Number);
		const first = new Date(year, month - 1, 1);
		const start = new Date(year, month - 1, 1 - first.getDay());
		return Array.from({ length: 42 }, (_, index) => {
			const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index);
			const iso = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
			return { iso, day: date.getDate(), currentMonth: date.getMonth() === month - 1 };
		});
	}

	function taskCalendarMonthLabel(monthValue: string): string {
		const [year, month] = monthValue.split('-').map(Number);
		return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(new Date(year, month - 1, 1));
	}

	function moveTaskStatusMonth(offset: -1 | 1) {
		let [year, month] = taskStatusMonth.split('-').map(Number);
		month += offset;
		if (month < 1) { month = 12; year -= 1; }
		if (month > 12) { month = 1; year += 1; }
		taskStatusMonth = `${year}-${String(month).padStart(2, '0')}`;
		taskMonthCounts = {};
		setTimeout(() => { void loadTaskMonthCounts(); }, 0);
	}

	function showPreviousTaskStatusMonth() { moveTaskStatusMonth(-1); }
	function showNextTaskStatusMonth() { moveTaskStatusMonth(1); }

	function taskGoToYears(monthValue: string): number[] {
		const currentYear = Number(monthValue.slice(0, 4));
		return Array.from({ length: 15 }, (_, index) => currentYear - 7 + index);
	}

	async function goToTaskStatusDate() {
		const year = Number(taskGoToYear); const month = Number(taskGoToMonth); const day = Number(taskGoToDay);
		if (!year || !month || !day) { taskStatusError = 'Select a day, month, and year.'; return; }
		const maximumDay = new Date(year, month, 0).getDate();
		if (day > maximumDay) { taskStatusError = 'The selected day is not valid for this month.'; return; }
		taskStatusMonth = `${year}-${String(month).padStart(2, '0')}`;
		taskStatusDate = `${taskStatusMonth}-${String(day).padStart(2, '0')}`;
		taskMonthCounts = {};
		await Promise.all([loadTaskMonthCounts(), loadTaskStatus()]);
	}

	function clearTaskStatusDate() {
		taskGoToDay = ''; taskGoToMonth = ''; taskGoToYear = '';
		taskStatusDate = ''; taskStatusRows = []; taskStatusError = '';
	}

	async function deleteStatementItem(row: any, item: 'tasks' | 'mjv') {
		if (!$currentUser?.isMasterAdmin || !row.statement_mjv_id || deletingStatementItem) return;
		const message = item === 'tasks'
			? 'Delete all posting tasks for this saved statement MJV? This does not reverse entries already posted in the ERP.'
			: 'Delete this saved statement MJV? This cannot be undone.';
		if (!confirm(message)) return;
		deletingStatementItem = `${row.statement_mjv_id}:${item}`; taskStatusError = '';
		const { error } = await supabase.rpc('master_delete_statement_mjv_item', { p_statement_mjv_id: row.statement_mjv_id, p_item: item });
		if (error) taskStatusError = error.message;
		else await Promise.all([loadTaskStatus(), loadTaskMonthCounts()]);
		deletingStatementItem = '';
	}

	async function toggleSavedMjvDetails(row: any) {
		if (!row.statement_mjv_id) return;
		const id = String(row.statement_mjv_id);
		const next = new Set(expandedSavedMjvRows);
		if (next.has(id)) {
			next.delete(id);
			expandedSavedMjvRows = next;
			return;
		}
		if (!savedMjvDetails[id]) {
			loadingSavedMjvId = id;
			taskStatusError = '';
			const { data, error } = await supabase.rpc('get_statement_mjv', {
				p_bank: row.bank,
				p_bank_account_id: row.bank_account_id,
				p_statement_date: taskStatusDate
			});
			loadingSavedMjvId = '';
			if (error) { taskStatusError = error.message; return; }
			savedMjvDetails = { ...savedMjvDetails, [id]: data };
		}
		next.add(id);
		expandedSavedMjvRows = next;
	}

	function taskDateCountClass(saved: number, configured: number): string {
		if (saved === 0 || configured === 0) return 'none-saved';
		if (saved === configured) return 'all-saved';
		return 'partially-saved';
	}

	async function selectTaskStatusDate(iso: string) {
		taskStatusDate = iso;
		taskStatusMonth = iso.slice(0, 7);
		await loadTaskStatus();
	}

	function numericAmount(value: string): number {
		const number = Number(String(value || '').replace(/,/g, ''));
		return Number.isFinite(number) ? Math.abs(number) : 0;
	}

	function toggleEntryPreview(rowNumber: number) {
		const next = new Set(expandedEntryRows);
		if (next.has(rowNumber)) next.delete(rowNumber); else next.add(rowNumber);
		expandedEntryRows = next;
	}

	function isPosTransaction(row: StatementRow): boolean {
		return row.description.includes('POS Credit') || row.description.includes('POS Bulk Credit');
	}

	function transactionViewLabel(row: StatementRow): string {
		if (isPosTransaction(row)) return 'POS Transactions';
		return transactionDisplayDescription(row);
	}

	function transactionDisplayDescription(row: StatementRow): string {
		if (bank !== 'riyad') return row.description;
		const labels: Record<string, string> = {
			'POS DEBIT': 'POS Card Purchases',
			'OUTGOING INSTANT PAYMENT': 'Instant Payments',
			'Outgoing Transfer': 'Company Transfers',
			'UTILITY BILL PAYMENT': 'SADAD Utility Payments',
			'--': 'Iqama Renewal Payments',
			'OUTGOING TRANSF': 'Local Transfer',
			'ATM DEBIT': 'ATM Withdrawals',
			'INCOMING TRANSFER': 'Incoming Transfers',
			'TRNSFR FROM C/A TO C/A': 'Internal Account Transfer'
		};
		return labels[row.description] || row.description;
	}

	function transactionIdentifierLabel(view: string): string {
		return view === 'Iqama Renewal Payments' ? 'Iqama Number' : 'Terminal ID';
	}

	function transactionIdentifier(row: StatementRow): string {
		if (transactionView === 'Iqama Renewal Payments') return row.details.match(/\bSUB\s*(\d+)/i)?.[1] || '—';
		return row.terminalId;
	}

	function selectTransactionView(description: string) {
		transactionView = description;
		terminalFilter = '';
		showFullDateJournal = false;
		savedStatementMjv = null;
		statementWorkflowMessage = '';
		expandedEntryRows = new Set<number>();
	}

	function previewBranchLabel(branchId: number, fallback: string): string {
		const configuredBranch = branches.find((branch) => Number(branch.id) === Number(branchId));
		return configuredBranch ? branchLabel(configuredBranch) : fallback;
	}

	function entryPreview(row: StatementRow) {
		const terminalKey = bank === 'riyad' ? row.terminalId.slice(0, 8) : row.terminalId;
		const terminal = terminalAccounts.find((item) => item.terminal_id === terminalKey);
		if (!terminal) return { error: `Terminal ${terminalKey || 'ID'} is not configured.`, lines: [], debit: 0, credit: 0 };
		const selectedStatementAccount = configuredBankAccounts.find((item) => item.id === selectedStatementBankAccountId);
		if (!selectedStatementAccount) return { error: 'Select the statement real bank account.', lines: [], debit: 0, credit: 0 };
		if (Number(terminal.branch_id) !== Number(selectedStatementAccount.branch_id) || Number(terminal.bank_ledger_id) !== Number(selectedStatementAccount.ledger_id)) return { error: `Terminal ${terminalKey} belongs to ${terminal.branch_name} — ${terminal.bank_ledger_name}, not the selected statement account.`, lines: [], debit: 0, credit: 0 };
		const posting = postingAccounts.find((item) => Number(item.branch_id) === Number(terminal.active_branch_id));
		if (!posting) return { error: `Posting accounts are not configured for ${terminal.active_branch_name}.`, lines: [], debit: 0, credit: 0 };
		const posAccount = (previewAccounts.pos_accounts || []).find((item: any) => Number(item.branch_id) === Number(terminal.active_branch_id));
		if (!posAccount) return { error: `POS clearing account is not configured for ${terminal.active_branch_name}.`, lines: [], debit: 0, credit: 0 };
		const fee = row.children.filter((child) => childKind(child) === 'fee').reduce((sum, child) => sum + numericAmount(child.debit || child.credit), 0);
		const vat = row.children.filter((child) => childKind(child) === 'vat').reduce((sum, child) => sum + numericAmount(child.debit || child.credit), 0);
		const statementCredit = numericAmount(row.credit);
		const net = bank === 'riyad' ? statementCredit : Math.max(0, statementCredit - fee - vat);
		const gross = bank === 'riyad' ? statementCredit + fee + vat : statementCredit;
		const lines: any[] = [];
		const bankName = bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli Bank';
		const statementDate = displayDate(row.date);
		const reference = row.reference ? `, reference ${row.reference}` : '';
		const accountBranchLabel = previewBranchLabel(terminal.branch_id, terminal.branch_name);
		const activeBranchLabel = previewBranchLabel(terminal.active_branch_id, terminal.active_branch_name);
		const add = (branchId: number, branch: string, account: string, ledgerCode: string, debit: number, credit: number, kind: string, narration: string) => lines.push({ branchId, branch, account, ledgerCode, debit, credit, kind, narration });
		if (Number(terminal.branch_id) === Number(terminal.active_branch_id)) {
			add(Number(terminal.branch_id), accountBranchLabel, terminal.bank_ledger_name, terminal.bank_ledger_code || '', bank === 'al-ahli' ? gross : net, 0, 'Real bank', `${bankName} POS settlement per bank statement dated ${statementDate} for terminal ${terminalKey}${reference}`);
			if (bank === 'al-ahli' && fee) add(Number(terminal.branch_id), accountBranchLabel, terminal.bank_ledger_name, terminal.bank_ledger_code || '', 0, fee, 'Bank fee withdrawal', `${bankName} fee withdrawn from the real bank account for terminal ${terminalKey}${reference}`);
			if (bank === 'al-ahli' && vat) add(Number(terminal.branch_id), accountBranchLabel, terminal.bank_ledger_name, terminal.bank_ledger_code || '', 0, vat, 'Bank VAT withdrawal', `${bankName} fee VAT withdrawn from the real bank account for terminal ${terminalKey}${reference}`);
			if (fee) add(Number(terminal.branch_id), accountBranchLabel, bank === 'riyad' ? posting.riyad_fee_ledger_name : posting.ahli_fee_ledger_name, bank === 'riyad' ? posting.riyad_fee_ledger_code : posting.ahli_fee_ledger_code, fee, 0, 'Processing fee', `${bankName} processing fee for terminal ${terminalKey}${reference}`);
			if (vat) add(Number(terminal.branch_id), accountBranchLabel, posting.input_vat_ledger_name, posting.input_vat_ledger_code || '', vat, 0, 'Input VAT', `Input VAT on ${bankName} processing fee for terminal ${terminalKey}${reference}`);
			add(Number(terminal.branch_id), accountBranchLabel, posAccount.ledger_name, posAccount.ledger_code || '', 0, gross, 'POS clearing', `Clear gross POS sales for terminal ${terminalKey}${reference}`);
		} else {
			const bankSideAdjustment = (previewAccounts.cross_branch_accounts || []).find((item: any) => Number(item.source_branch_id) === Number(terminal.branch_id) && Number(item.target_branch_id) === Number(terminal.active_branch_id));
			const activeSideAdjustment = (previewAccounts.cross_branch_accounts || []).find((item: any) => Number(item.source_branch_id) === Number(terminal.active_branch_id) && Number(item.target_branch_id) === Number(terminal.branch_id));
			if (!bankSideAdjustment || !activeSideAdjustment) return { error: 'Both reciprocal branch adjustment accounts are required.', lines: [], debit: 0, credit: 0 };
			add(Number(terminal.branch_id), accountBranchLabel, terminal.bank_ledger_name, terminal.bank_ledger_code || '', bank === 'al-ahli' ? gross : net, 0, 'Real bank', `${bankName} POS settlement per bank statement dated ${statementDate} for terminal ${terminalKey}${reference}`);
			if (bank === 'al-ahli' && fee) add(Number(terminal.branch_id), accountBranchLabel, terminal.bank_ledger_name, terminal.bank_ledger_code || '', 0, fee, 'Bank fee withdrawal', `${bankName} fee withdrawn from the real bank account for terminal ${terminalKey}${reference}`);
			if (bank === 'al-ahli' && vat) add(Number(terminal.branch_id), accountBranchLabel, terminal.bank_ledger_name, terminal.bank_ledger_code || '', 0, vat, 'Bank VAT withdrawal', `${bankName} fee VAT withdrawn from the real bank account for terminal ${terminalKey}${reference}`);
			add(Number(terminal.branch_id), accountBranchLabel, bankSideAdjustment.ledger_name, '', 0, net, 'Branch adjustment', `Net POS settlement adjustment from ${accountBranchLabel} to ${activeBranchLabel} for terminal ${terminalKey}${reference}`);
			add(Number(terminal.active_branch_id), activeBranchLabel, activeSideAdjustment.ledger_name, '', net, 0, 'Branch adjustment', `Net POS settlement received in ${activeBranchLabel} through ${accountBranchLabel} for terminal ${terminalKey}${reference}`);
			if (fee) add(Number(terminal.active_branch_id), activeBranchLabel, bank === 'riyad' ? posting.riyad_fee_ledger_name : posting.ahli_fee_ledger_name, bank === 'riyad' ? posting.riyad_fee_ledger_code : posting.ahli_fee_ledger_code, fee, 0, 'Processing fee', `${bankName} processing fee for terminal ${terminalKey}${reference}`);
			if (vat) add(Number(terminal.active_branch_id), activeBranchLabel, posting.input_vat_ledger_name, posting.input_vat_ledger_code || '', vat, 0, 'Input VAT', `Input VAT on ${bankName} processing fee for terminal ${terminalKey}${reference}`);
			add(Number(terminal.active_branch_id), activeBranchLabel, posAccount.ledger_name, posAccount.ledger_code || '', 0, gross, 'POS clearing', `Clear gross POS sales for terminal ${terminalKey}${reference}`);
		}
		return { error: '', lines, debit: lines.reduce((sum, line) => sum + line.debit, 0), credit: lines.reduce((sum, line) => sum + line.credit, 0), terminal };
	}

	function fullDateJournalPreview() {
		const transactions = statementRows.filter((row) => isPosTransaction(row) && displayDate(row.date) === dateFilter);
		const lines: any[] = [];
		const errors: string[] = [];
		for (const [index, row] of transactions.entries()) {
			const preview = entryPreview(row);
			if (preview.error) {
				errors.push(`${transactionNumber(index)}: ${preview.error}`);
				continue;
			}
			for (const line of preview.lines) lines.push({ ...line, transaction: transactionNumber(index), description: row.description, reference: row.reference });
		}
		const branchGroups = Array.from(lines.reduce((groups: Map<string, any[]>, line: any) => {
			if (!groups.has(line.branch)) groups.set(line.branch, []);
			groups.get(line.branch)?.push(line);
			return groups;
		}, new Map<string, any[]>())).map(([branch, branchLines]) => ({
			branch,
			branchId: Number(branchLines[0]?.branchId),
			lines: branchLines,
			debit: branchLines.reduce((sum: number, line: any) => sum + line.debit, 0),
			credit: branchLines.reduce((sum: number, line: any) => sum + line.credit, 0)
		}));
		return {
			lines, branchGroups, errors, transactionCount: transactions.length,
			debit: lines.reduce((sum, line) => sum + line.debit, 0),
			credit: lines.reduce((sum, line) => sum + line.credit, 0)
		};
	}

	function statementDateIso(): string {
		const [day, month, year] = dateFilter.split('/');
		return `${year}-${month}-${day}`;
	}

	async function loadSavedStatementMjv() {
		if (!bank || !dateFilter) return;
		const { data, error } = await supabase.rpc('get_statement_mjv', { p_bank: bank, p_bank_account_id: selectedStatementBankAccountId, p_statement_date: statementDateIso() });
		if (error) accountError = error.message;
		else savedStatementMjv = data || null;
	}

	async function openFullDateJournal() {
		selectedFullJournalBranch = '';
		statementWorkflowMessage = '';
		await loadSavedStatementMjv();
		showFullDateJournal = true;
	}

	async function saveFullDateJournal(preview: any) {
		if (preview.errors.length || Math.abs(preview.debit - preview.credit) >= 0.005) return;
		savingStatementMjv = true; accountError = ''; statementWorkflowMessage = '';
		const branchesPayload = preview.branchGroups.map((group: any) => ({
			branch_id: group.branchId, branch_name: group.branch, debit: group.debit, credit: group.credit,
			lines: group.lines.map((line: any) => ({ ledger_name: line.account, ledger_code: line.ledgerCode || '', amount: Number(line.debit || line.credit).toFixed(2), side: line.debit ? 'Debit' : 'Credit', narration: line.narration }))
		}));
		const { error } = await supabase.rpc('save_statement_mjv', { p_bank: bank, p_bank_account_id: selectedStatementBankAccountId, p_statement_date: statementDateIso(), p_source_file_name: fileName, p_branches: branchesPayload });
		if (error) accountError = error.message;
		else { statementWorkflowMessage = 'MJV saved by branch.'; await loadSavedStatementMjv(); }
		savingStatementMjv = false;
	}

	async function postStatementMjvTasks() {
		if (!savedStatementMjv?.id) return;
		postingStatementTasks = true; accountError = ''; statementWorkflowMessage = '';
		try {
			const response = await authenticatedFetch('/api/assistant-tasks', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ task_type: 'statement_mjv', statement_mjv_id: savedStatementMjv.id }) });
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to create posting tasks.');
			statementWorkflowMessage = `${result.tasks.length} branch posting task${result.tasks.length === 1 ? '' : 's'} sent to the configured Entry Task users.`;
			await loadSavedStatementMjv();
		} catch (error) { accountError = error instanceof Error ? error.message : 'Unable to create posting tasks.'; }
		postingStatementTasks = false;
	}

	async function selectPostingBranch() {
		const selected = branches.find((branch) => branchLabel(branch) === postingBranchSearch);
		postingBranchId = selected ? Number(selected.id) : null;
		ledgerChoices = { vat: [], riyad: [], ahli: [] };
		ledgerSearches = { vat: '', riyad: '', ahli: '' };
		selectedLedgers = { vat: null, riyad: null, ahli: null };
		if (!postingBranchId) return;
		const existing = postingAccounts.find((item) => Number(item.branch_id) === postingBranchId);
		if (existing) {
			selectedLedgers = {
				vat: { LedgerID: existing.input_vat_ledger_id, LedgerCode: existing.input_vat_ledger_code, LedgerName: existing.input_vat_ledger_name },
				riyad: { LedgerID: existing.riyad_fee_ledger_id, LedgerCode: existing.riyad_fee_ledger_code, LedgerName: existing.riyad_fee_ledger_name },
				ahli: { LedgerID: existing.ahli_fee_ledger_id, LedgerCode: existing.ahli_fee_ledger_code, LedgerName: existing.ahli_fee_ledger_name }
			};
			ledgerSearches = { vat: ledgerLabel(selectedLedgers.vat), riyad: ledgerLabel(selectedLedgers.riyad), ahli: ledgerLabel(selectedLedgers.ahli) };
		}
		searchingLedger = 'all';
		try {
			const response = await authenticatedFetch(`/api/erp-ledger-search?branchId=${postingBranchId}`);
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to load branch ledgers.');
			const allLedgers = result.ledgers || [];
			ledgerChoices = { vat: allLedgers, riyad: allLedgers, ahli: allLedgers };
		} catch (error) {
			accountError = error instanceof Error ? error.message : 'Unable to load branch ledgers.';
		} finally {
			searchingLedger = '';
		}
	}

	function ledgerLabel(ledger: any): string {
		return ledger ? `${ledger.LedgerName} (${ledger.LedgerCode ?? ledger.LedgerID})` : '';
	}

	async function searchPostingLedger(kind: 'vat' | 'riyad' | 'ahli') {
		if (!postingBranchId) return;
		searchingLedger = kind;
		selectedLedgers[kind] = null;
		try {
			const query = encodeURIComponent(ledgerSearches[kind].trim());
			const response = await authenticatedFetch(`/api/erp-ledger-search?branchId=${postingBranchId}&query=${query}`);
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to search ledgers.');
			ledgerChoices[kind] = result.ledgers || [];
		} catch (error) {
			accountError = error instanceof Error ? error.message : 'Unable to search ledgers.';
		} finally {
			searchingLedger = '';
		}
	}

	function choosePostingLedger(kind: 'vat' | 'riyad' | 'ahli') {
		const ledger = ledgerChoices[kind].find((item) => ledgerLabel(item) === ledgerSearches[kind]);
		selectedLedgers[kind] = ledger || null;
	}

	async function savePostingAccounts() {
		if (!postingBranchId || !selectedLedgers.vat || !selectedLedgers.riyad || !selectedLedgers.ahli) {
			accountError = 'Select a branch and all three posting accounts.';
			return;
		}
		savingPostingAccounts = true;
		accountError = '';
		const values = selectedLedgers;
		const { error } = await supabase.rpc('save_statement_posting_accounts', {
			p_branch_id: postingBranchId,
			p_input_vat_ledger_id: Number(values.vat.LedgerID), p_input_vat_ledger_code: String(values.vat.LedgerCode ?? ''), p_input_vat_ledger_name: String(values.vat.LedgerName),
			p_riyad_fee_ledger_id: Number(values.riyad.LedgerID), p_riyad_fee_ledger_code: String(values.riyad.LedgerCode ?? ''), p_riyad_fee_ledger_name: String(values.riyad.LedgerName),
			p_ahli_fee_ledger_id: Number(values.ahli.LedgerID), p_ahli_fee_ledger_code: String(values.ahli.LedgerCode ?? ''), p_ahli_fee_ledger_name: String(values.ahli.LedgerName)
		});
		if (error) accountError = error.message;
		else {
			await loadTerminalAccounts();
			accountMessage = 'Posting accounts saved successfully.';
			showPostingForm = false;
		}
		savingPostingAccounts = false;
	}

	async function openAccounts() {
		activeTab = 'accounts';
		accountError = '';
		await loadTerminalAccounts();
	}

	async function openTerminals() {
		activeTab = 'terminals';
		accountError = '';
		await loadTerminalAccounts();
	}

	async function openBankAccounts() {
		activeTab = 'bank-accounts'; accountError = ''; await loadTerminalAccounts();
	}

	async function selectBankAccountBranch() {
		const selected = branches.find((branch) => branchLabel(branch) === bankAccountBranchSearch);
		bankAccountBranchId = selected ? Number(selected.id) : null;
		bankAccountLedgerChoices = []; bankAccountLedgerSearch = ''; selectedConfiguredLedger = null;
		if (!bankAccountBranchId) return;
		loadingConfiguredLedgers = true;
		try {
			const response = await authenticatedFetch(`/api/erp-ledger-search?branchId=${bankAccountBranchId}&bankOnly=true`);
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to load bank accounts.');
			bankAccountLedgerChoices = result.ledgers || [];
		} catch (error) { accountError = error instanceof Error ? error.message : 'Unable to load bank accounts.'; }
		loadingConfiguredLedgers = false;
	}

	function chooseConfiguredBankLedger() {
		selectedConfiguredLedger = bankAccountLedgerChoices.find((ledger) => ledgerLabel(ledger) === bankAccountLedgerSearch) || null;
	}

	async function saveConfiguredBankAccount() {
		if (!bankAccountBranchId || !bankAccountBank || !selectedConfiguredLedger) { accountError = 'Branch, bank, and SQL bank account are required.'; return; }
		savingConfiguredBankAccount = true; accountError = ''; accountMessage = '';
		const { error } = await supabase.rpc('save_statement_bank_account', { p_id: editingBankAccountId, p_branch_id: bankAccountBranchId, p_bank: bankAccountBank, p_ledger_id: selectedConfiguredLedger.LedgerID, p_ledger_code: String(selectedConfiguredLedger.LedgerCode || ''), p_ledger_name: selectedConfiguredLedger.LedgerName });
		if (error) accountError = error.message;
		else { accountMessage = 'Bank account saved.'; showBankAccountForm = false; editingBankAccountId = null; await loadTerminalAccounts(); }
		savingConfiguredBankAccount = false;
	}

	async function editConfiguredBankAccount(account: any) {
		editingBankAccountId = account.id; showBankAccountForm = true; bankAccountBank = account.bank;
		const branch = branches.find((item) => Number(item.id) === Number(account.branch_id));
		bankAccountBranchSearch = branch ? branchLabel(branch) : account.branch_name;
		await selectBankAccountBranch();
		selectedConfiguredLedger = { LedgerID: account.ledger_id, LedgerCode: account.ledger_code, LedgerName: account.ledger_name };
		bankAccountLedgerSearch = ledgerLabel(selectedConfiguredLedger);
	}

	function branchLabel(branch: any): string {
		const name = branch.name_en || branch.name_ar || `Branch ${branch.id}`;
		const location = branch.location_en || branch.location_ar || '';
		return location ? `${name} - ${location}` : name;
	}

	async function selectAccountBranch() {
		const selected = branches.find((branch) => branchLabel(branch) === branchSearch);
		selectedBranchId = selected ? Number(selected.id) : null;
		selectedBankLedgerId = '';
		bankAccounts = [];
		accountError = '';
		if (!selectedBranchId) return;
		bankAccounts = configuredBankAccounts.filter((account) => Number(account.branch_id) === selectedBranchId).map((account) => ({ LedgerID: account.ledger_id, LedgerCode: account.ledger_code, LedgerName: account.ledger_name, Bank: account.bank }));
		if (!bankAccounts.length) accountError = 'Configure a bank account for this branch first.';
	}

	function selectActiveBranch() {
		const selected = branches.find((branch) => branchLabel(branch) === activeBranchSearch);
		selectedActiveBranchId = selected ? Number(selected.id) : null;
	}

	async function saveTerminalAccount() {
		const ledger = bankAccounts.find((account) => String(account.LedgerID) === selectedBankLedgerId);
		if (!selectedBranchId || !selectedActiveBranchId || !ledger || !terminalIdInput.trim()) {
			accountError = 'Select the account branch, Active in branch, bank account, and terminal ID.';
			return;
		}
		savingTerminal = true;
		accountError = '';
		accountMessage = '';
		const rpcName = editingTerminalId ? 'update_statement_terminal_account' : 'add_statement_terminal_account';
		const payload: Record<string, unknown> = {
			p_terminal_id: terminalIdInput.trim(), p_branch_id: selectedBranchId,
			p_active_branch_id: selectedActiveBranchId,
			p_bank_ledger_id: Number(ledger.LedgerID), p_bank_ledger_code: String(ledger.LedgerCode ?? ''),
			p_bank_ledger_name: String(ledger.LedgerName ?? '')
		};
		if (editingTerminalId) payload.p_id = editingTerminalId;
		const { error } = await supabase.rpc(rpcName, payload);
		if (error) accountError = error.message;
		else {
			const { data, error: reloadError } = await supabase.rpc('get_statement_terminal_accounts');
			if (reloadError) {
				accountError = reloadError.message;
				savingTerminal = false;
				return;
			}
			terminalAccounts = data || [];
			terminalIdInput = '';
			activeBranchSearch = '';
			selectedActiveBranchId = null;
			accountMessage = editingTerminalId ? 'Terminal updated successfully.' : 'Terminal saved successfully.';
			editingTerminalId = null;
			showAccountForm = false;
		}
		savingTerminal = false;
	}

	async function editTerminal(account: any) {
		editingTerminalId = account.id;
		terminalIdInput = account.terminal_id;
		const ownerBranch = branches.find((branch) => Number(branch.id) === Number(account.branch_id));
		const activeBranch = branches.find((branch) => Number(branch.id) === Number(account.active_branch_id));
		branchSearch = ownerBranch ? branchLabel(ownerBranch) : account.branch_name;
		activeBranchSearch = activeBranch ? branchLabel(activeBranch) : account.active_branch_name;
		selectedActiveBranchId = Number(account.active_branch_id);
		showAccountForm = true;
		accountError = '';
		await selectAccountBranch();
		selectedBankLedgerId = String(account.bank_ledger_id);
	}

	async function editPostingAccount(posting: any) {
		const branch = branches.find((item) => Number(item.id) === Number(posting.branch_id));
		postingBranchSearch = branch ? branchLabel(branch) : posting.branch_name;
		showPostingForm = true;
		accountError = '';
		await selectPostingBranch();
	}

	const clean = (value: unknown) => String(value ?? '').trim();
	const normalized = (value: unknown) => clean(value).toLowerCase().replace(/\s+/g, ' ');
	const findCode = (details: string) => details.match(/\b([A-Z]{2}\d{6})\s*$/)?.[1] ?? '';
	function findTerminalId(details: string, selectedBank: string): string {
		if (selectedBank === 'al-ahli') return details.match(/REFERENCE\s*:\s*(\d+)/i)?.[1] ?? '';
		return details.match(/TERM\.\s*ID:\s*(\d+)/i)?.[1]
			?? details.match(/FEE\s*[\d,.]+\s*SAR,(\d+),\d+/i)?.[1]
			?? '';
	}

	function findPosKey(row: StatementRow): string | null {
		const identity = row.details.match(/RECON NO:\s*(\d+)\s+(?:000000\s+)?REFERENCE\s*:\s*(\d+)/i);
		if (!identity || !row.code) return null;
		const suffix = row.code.slice(0, 2).toUpperCase();
		const network = row.description === 'POS Retailer Acc. Bulk credit' ? suffix[0] : suffix[1];
		return `${identity[1].replace(/^0+/, '')}|${identity[2]}|${network}|${row.code.slice(2)}`;
	}

	const transactionNumber = (index: number) => `T-${String(index + 1).padStart(3, '0')}`;

	function childKind(row: StatementRow): 'fee' | 'vat' | null {
		if (row.code === 'FEE') return 'fee';
		if (row.code === 'VAT') return 'vat';
		if (row.description === 'Transfer Fees') return 'fee';
		if (row.description === 'VAT Charge') return 'vat';
		if (row.description !== 'POS and E-payment Fee') return null;
		if (row.code.startsWith('F')) return 'fee';
		if (row.code.startsWith('V')) return 'vat';
		return null;
	}

	function referenceKey(value: string): string {
		return value.match(/REF\s+([A-Z0-9]+)/i)?.[1] ?? '';
	}

	function riyadReference(description: string, details: string, exportedReference: string): string {
		if (description === 'ONLINE POS CREDIT') {
			const systemReferences = details.match(/20\d{6}-[A-Z0-9-]+/gi) || [];
			return systemReferences.at(-1) || details.match(/RECON#:\s*([^,]+)/i)?.[1]?.trim() || exportedReference;
		}
		if (description === 'POS SETTLEMENT') {
			return details.match(/^(?:VISA CARD|MASTERCARD)[^,]*,\s*([0-9]+)/i)?.[1] || exportedReference;
		}
		return exportedReference;
	}

	function riyadChild(parent: StatementRow, kind: 'fee' | 'vat', value: number, details: string): StatementRow {
		return {
			rowNumber: parent.rowNumber,
			date: parent.date,
			description: kind === 'fee' ? 'Processing fee' : 'VAT on processing fee',
			details,
			reference: parent.reference,
			terminalId: parent.terminalId,
			debit: amount(value),
			credit: '',
			balance: '',
			code: kind === 'fee' ? 'FEE' : 'VAT',
			children: []
		};
	}

	function groupRiyadTransactions(rows: StatementRow[]): StatementRow[] {
		const attachedSourceRows = new Set<number>();
		const transferParents = new Map<string, StatementRow>();

		for (const row of rows) {
			if (row.description === 'ONLINE POS CREDIT') {
				const values = row.details.match(/PURCHASE AMT:\s*([\d,.]+)\s*SAR,REFUND AMOUNT:\s*([\d,.]+)\s*SAR,FEE\s*([\d,.]+)\s*SAR,VAT Amount:\s*([\d,.]+)\s*SAR/i);
				if (values) {
					const fee = Number(values[3].replace(/,/g, ''));
					const vat = Number(values[4].replace(/,/g, ''));
					row.children = [
						riyadChild(row, 'fee', fee, 'Fee extracted from the Mada POS settlement details'),
						riyadChild(row, 'vat', vat, 'VAT extracted from the Mada POS settlement details')
					];
				}
				row.description = 'Mada POS Credit';
			} else if (row.description === 'POS SETTLEMENT') {
				const values = row.details.match(/VAT AMOUNT\s*([\d,.]+)\s*SAR.*?FEE\s*([\d,.]+)\s*SAR/i);
				if (values) {
					const vat = Number(values[1].replace(/,/g, ''));
					const fee = Number(values[2].replace(/,/g, ''));
					row.children = [
						riyadChild(row, 'fee', fee, 'Fee extracted from the Visa POS settlement details'),
						riyadChild(row, 'vat', vat, 'VAT extracted from the Visa POS settlement details')
					];
				}
				const settlementDetails = row.details.toUpperCase();
				row.description = settlementDetails.includes('VISA')
					? 'Visa POS Credit'
					: settlementDetails.includes('MASTER')
						? 'Mastercard POS Credit'
						: 'Other Card POS Credit';
			}

			if (row.description === 'OUTGOING INSTANT PAYMENT' || row.description === 'OUTGOING TRANSF') {
				const key = referenceKey(row.reference);
				if (key) transferParents.set(key, row);
			}
		}

		for (const feeRow of rows) {
			if (feeRow.description !== 'INSTANT PAYMENT FEES' && feeRow.description !== 'BANK FEES/COMMISSIONS') continue;
			const parent = transferParents.get(referenceKey(feeRow.reference));
			const values = feeRow.details.match(/FEE\s*0*([\d,.]+)\s*SAR,VAT AMOUNT\s*0*([\d,.]+)\s*SAR/i);
			if (!parent || !values) continue;
			const fee = Number(values[1].replace(/,/g, ''));
			const vat = Number(values[2].replace(/,/g, ''));
			parent.children = [
				riyadChild(feeRow, 'fee', fee, `Connected ${feeRow.description.toLowerCase()} row`),
				riyadChild(feeRow, 'vat', vat, `VAT extracted from the connected ${feeRow.description.toLowerCase()} row`)
			];
			attachedSourceRows.add(feeRow.rowNumber);
		}

		const posNetworks = new Set(['Mada POS Credit', 'Visa POS Credit', 'Mastercard POS Credit', 'Other Card POS Credit']);
		const networkPriority: Record<string, number> = {
			'Mada POS Credit': 0,
			'Visa POS Credit': 1,
			'Mastercard POS Credit': 2,
			'Other Card POS Credit': 3
		};
		const priority: Record<string, number> = {
			'OUTGOING INSTANT PAYMENT': 1,
			'OUTGOING TRANSF': 2,
			'POS DEBIT': 3,
			'UTILITY BILL PAYMENT': 4,
			'Outgoing Transfer': 5,
			'ATM DEBIT': 6,
			'INCOMING TRANSFER': 7,
			'TRNSFR FROM C/A TO C/A': 8,
			'--': 9
		};

		return rows
			.filter((row) => !attachedSourceRows.has(row.rowNumber))
			.sort((left, right) => {
				const leftIsPos = posNetworks.has(left.description);
				const rightIsPos = posNetworks.has(right.description);
				if (leftIsPos && rightIsPos) {
					const terminalDifference = left.terminalId.slice(0, 8).localeCompare(right.terminalId.slice(0, 8));
					return terminalDifference || (networkPriority[left.description] ?? 9) - (networkPriority[right.description] ?? 9) || left.rowNumber - right.rowNumber;
				}
				if (leftIsPos !== rightIsPos) return leftIsPos ? -1 : 1;
				return (priority[left.description] ?? 99) - (priority[right.description] ?? 99) || left.description.localeCompare(right.description) || left.rowNumber - right.rowNumber;
			});
	}

	function groupTransactions(rows: StatementRow[]): StatementRow[] {
		const posParents = new Map<string, StatementRow>();
		const transferParents = new Map<string, StatementRow>();
		const attachedRows = new Set<number>();

		for (const row of rows) {
			if (row.description === 'POS Retailer Acc. Bulk credit') {
				const key = findPosKey(row);
				if (key) posParents.set(key, row);
			}
			if (row.description === 'Outgoing IPS local transfer' || row.description === 'Outgoing Local Transfer') {
				if (row.reference) transferParents.set(row.reference, row);
			}
		}

		for (const row of rows) {
			if (!childKind(row)) continue;
			let parent: StatementRow | undefined;
			if (row.description === 'POS and E-payment Fee') {
				const key = findPosKey(row);
				parent = key ? posParents.get(key) : undefined;
			} else if (row.reference) parent = transferParents.get(row.reference);
			if (parent) {
				parent.children.push(row);
				attachedRows.add(row.rowNumber);
			}
		}

		for (const row of rows) {
			row.children.sort((left, right) => childKind(left) === childKind(right) ? left.rowNumber - right.rowNumber : childKind(left) === 'fee' ? -1 : 1);
			if (row.description === 'POS Retailer Acc. Bulk credit') {
				const networkCode = row.code.slice(0, 1).toUpperCase();
				row.description = networkCode === 'V'
					? 'Visa POS Bulk Credit'
					: networkCode === 'M'
						? 'Mastercard POS Bulk Credit'
						: networkCode === 'S'
							? 'Mada POS Bulk Credit'
							: 'Other POS Bulk Credit';
			}
		}
		return rows
			.filter((row) => !attachedRows.has(row.rowNumber))
			.sort((left, right) => {
				const priority = (row: StatementRow) => {
					if (row.description === 'Mada POS Bulk Credit') return 0;
					if (row.description === 'Visa POS Bulk Credit') return 1;
					if (row.description === 'Mastercard POS Bulk Credit') return 2;
					if (row.description === 'Other POS Bulk Credit') return 3;
					if (row.description === 'Outgoing IPS local transfer' || row.description === 'Outgoing Local Transfer') return 4;
					if (row.description === 'SADAD Payment') return 5;
					if (row.description === 'Outgoing internal transfer') return 6;
					if (row.description === 'Incoming internal transfer') return 7;
					return 8;
				};
				const priorityDifference = priority(left) - priority(right);
				if (priorityDifference) return priorityDifference;
				const descriptionDifference = left.description.localeCompare(right.description);
				return descriptionDifference || left.rowNumber - right.rowNumber;
			});
	}

	function displayDate(value: unknown): string {
		if (value instanceof Date && !Number.isNaN(value.getTime())) return value.toLocaleDateString('en-GB');
		if (typeof value === 'number') {
			const parsed = XLSX.SSF.parse_date_code(value);
			if (parsed) return `${String(parsed.d).padStart(2, '0')}/${String(parsed.m).padStart(2, '0')}/${parsed.y}`;
		}
		return clean(value);
	}

	function amount(value: unknown): string {
		const text = clean(value);
		if (!text) return '';
		const number = Number(text.replace(/,/g, ''));
		return Number.isFinite(number) ? number.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : text;
	}

	function chooseFile() {
		if (bank && selectedStatementBankAccountId && !isImporting) fileInput?.click();
	}

	function resetStatement() {
		fileName = '';
		errorMessage = '';
		statementRows = [];
		rawTransactionCount = 0;
		processingFeeCount = 0;
		vatCount = 0;
		transactionView = '';
		terminalFilter = '';
		dateFilter = '';
		showFullDateJournal = false;
		selectedFullJournalBranch = '';
		savedStatementMjv = null;
		statementWorkflowMessage = '';
		selectedStatementBankAccountId = '';
		expandedEntryRows = new Set<number>();
	}

	async function importStatement(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		isImporting = true;
		errorMessage = '';
		statementRows = [];
		transactionView = '';
		terminalFilter = '';
		dateFilter = '';
		showFullDateJournal = false;
		selectedFullJournalBranch = '';
		savedStatementMjv = null;
		statementWorkflowMessage = '';
		fileName = file.name;
		try {
			// Keep Excel dates as serial values. Converting them to JavaScript Date objects can
			// shift an Excel calendar date to the previous day in the Riyadh timezone.
			const workbook = XLSX.read(await file.arrayBuffer(), { type: 'array', cellDates: false });
			const worksheet = workbook.Sheets[workbook.SheetNames[0]];
			const rows = XLSX.utils.sheet_to_json<unknown[]>(worksheet, { header: 1, raw: true, defval: '' });
			const expectedHeader = bank === 'riyad' ? 'transaction type' : 'transaction description';
			const headerIndex = rows.findIndex((row) => row.some((cell) => normalized(cell) === expectedHeader));
			if (headerIndex < 0) throw new Error(`The selected file does not match the expected ${bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli'} statement format.`);

			const headers = rows[headerIndex].map(normalized);
			const column = (name: string) => headers.indexOf(name);
			const dateColumn = column(bank === 'riyad' ? 'value date' : 'processing date');
			const descriptionColumn = column(bank === 'riyad' ? 'transaction type' : 'transaction description');
			const detailsColumn = column(bank === 'riyad' ? 'details' : 'description');
			const referenceColumn = column(bank === 'riyad' ? 'reference no' : 'reference');
			const debitColumn = column(bank === 'riyad' ? 'debit amount' : 'debit');
			const creditColumn = column(bank === 'riyad' ? 'credit amount' : 'credit');
			const balanceColumn = column('balance');

			const parsedRows: StatementRow[] = rows.slice(headerIndex + 1).map((cells, offset) => {
				const details = clean(cells[detailsColumn]);
				const description = clean(cells[descriptionColumn]);
				const exportedReference = clean(cells[referenceColumn]);
				return {
					rowNumber: headerIndex + offset + 2,
					date: cells[dateColumn], description, details,
					reference: bank === 'riyad' ? riyadReference(description, details, exportedReference) : exportedReference, terminalId: findTerminalId(details, bank), debit: amount(cells[debitColumn]),
					credit: amount(cells[creditColumn]), balance: amount(cells[balanceColumn]),
					code: findCode(details), children: []
				};
			}).filter((row) => row.description);

			rawTransactionCount = parsedRows.length;
			if (bank === 'riyad') {
				statementRows = groupRiyadTransactions(parsedRows);
				processingFeeCount = statementRows.reduce((total, row) => total + row.children.filter((child) => childKind(child) === 'fee').length, 0);
				vatCount = statementRows.reduce((total, row) => total + row.children.filter((child) => childKind(child) === 'vat').length, 0);
			} else {
				processingFeeCount = parsedRows.filter((row) => childKind(row) === 'fee').length;
				vatCount = parsedRows.filter((row) => childKind(row) === 'vat').length;
				statementRows = groupTransactions(parsedRows);
			}
			transactionView = statementRows.some(isPosTransaction) ? 'POS Transactions' : statementRows[0] ? transactionViewLabel(statementRows[0]) : '';
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Unable to import the selected statement.';
			fileName = '';
		} finally {
			isImporting = false;
			input.value = '';
		}
	}
</script>

<div class="statement-manager">
	<nav class="manager-tabs" aria-label="Statements Manager sections">
		<button type="button" class:active={activeTab === 'process'} on:click={() => activeTab = 'process'}>Process</button>
		<button type="button" class:active={activeTab === 'accounts'} on:click={openAccounts}>Manage Accounts</button>
		<button type="button" class:active={activeTab === 'bank-accounts'} on:click={openBankAccounts}>Bank Accounts</button>
		<button type="button" class:active={activeTab === 'terminals'} on:click={openTerminals}>Terminal Configuration</button>
		<button type="button" class:active={activeTab === 'task-status'} on:click={openTaskStatus}>Task Status</button>
	</nav>
	{#if activeTab === 'process'}
	<section class="import-panel">
		<div class="field"><label for="statement-bank">Bank</label><select id="statement-bank" bind:value={bank} on:change={resetStatement}><option value="">Choose a bank</option><option value="al-ahli">Al Ahli (SNB)</option><option value="riyad">Riyad Bank</option></select></div>
		{#if bank}
			<div class="field statement-account-field"><label for="statement-bank-account">Real bank account</label><select id="statement-bank-account" bind:value={selectedStatementBankAccountId} on:change={() => { fileName = ''; statementRows = []; transactionView = ''; terminalFilter = ''; dateFilter = ''; showFullDateJournal = false; savedStatementMjv = null; statementWorkflowMessage = ''; }}><option value="">Choose configured account</option>{#each configuredBankAccounts.filter((account) => account.bank === bank) as account}<option value={account.id}>{account.branch_name} — {account.ledger_name} ({account.ledger_code || account.ledger_id})</option>{/each}</select></div>
			<button class="import-button" type="button" disabled={isImporting || !selectedStatementBankAccountId} on:click={chooseFile}>{isImporting ? 'Importing…' : 'Import Excel file'}</button>
			<input bind:this={fileInput} class="file-input" type="file" accept=".xlsx,.xls" on:change={importStatement} />
		{/if}
		{#if fileName}<div class="file-name" title={fileName}>{fileName}</div>{/if}
	</section>
	{#if errorMessage}<div class="error-message">{errorMessage}</div>{/if}

	{#if statementRows.length > 0}
		<section class="summary-grid" aria-label="Statement summary">
			<div><span>Excel source rows</span><strong>{rawTransactionCount}</strong></div><div><span>Main transactions</span><strong>{statementRows.length}</strong></div>
			<div><span>Processing fees</span><strong>{processingFeeCount}</strong></div><div><span>VAT entries</span><strong>{vatCount}</strong></div>
		</section>
		{#if bank === 'riyad'}<div class="source-note">Riyad stores some processing fees and VAT inside the same Excel row. They are extracted below for clear grouping without changing the source-row count.</div>{/if}
		<nav class="transaction-view-tabs" aria-label="Statement transaction categories">
			{#each transactionViewOptions as option}
				<button type="button" class:active={transactionView === option.description} on:click={() => selectTransactionView(option.description)}><span>{option.description}</span><strong>{option.count}</strong></button>
			{/each}
		</nav>
		<div class="table-filters">
			{#if selectedTransactionViewIsPos}<div class="filter-field"><label for="terminal-filter">Terminal ID</label><select id="terminal-filter" bind:value={terminalFilter}><option value="">All terminals</option>{#each terminalOptions as terminalId}<option value={terminalId}>{terminalId}</option>{/each}</select></div>{/if}
			<div class="filter-field"><label for="date-filter">Transaction date</label><select id="date-filter" bind:value={dateFilter} on:change={() => { showFullDateJournal = false; savedStatementMjv = null; statementWorkflowMessage = ''; }}><option value="">All dates</option>{#each dateOptions as transactionDate}<option value={transactionDate}>{transactionDate}</option>{/each}</select></div>
			{#if selectedTransactionViewIsPos}<button class="full-journal-button" type="button" disabled={!dateFilter} on:click={openFullDateJournal}>Show full MJV</button>{/if}
			{#if terminalFilter || dateFilter}<span>{filteredStatementRows.length} matching transactions</span>{/if}
		</div>
		{#if showFullDateJournal}
			{#each [fullDateJournalPreview()] as fullPreview}
				<section class="full-journal-panel">
					<header class="full-journal-header"><div><h2>Full MJV for {dateFilter}</h2><p>{fullPreview.transactionCount} POS transactions across all terminals</p></div><div class="workflow-actions"><span class:unbalanced={fullPreview.errors.length > 0 || Math.abs(fullPreview.debit - fullPreview.credit) >= 0.005} class="balance-badge">{!fullPreview.errors.length && Math.abs(fullPreview.debit - fullPreview.credit) < 0.005 ? 'Overall balanced' : 'Not balanced'}</span>{#if !savedStatementMjv}<button class="save-mjv-button" type="button" disabled={savingStatementMjv || fullPreview.errors.length > 0 || Math.abs(fullPreview.debit - fullPreview.credit) >= 0.005} on:click={() => saveFullDateJournal(fullPreview)}>{savingStatementMjv ? 'Saving…' : 'Save MJV'}</button>{:else if savedStatementMjv.status === 'saved'}<button class="post-mjv-button" type="button" disabled={postingStatementTasks} on:click={postStatementMjvTasks}>{postingStatementTasks ? 'Posting…' : 'Post Task'}</button><span class="workflow-status">Saved</span>{:else}<span class="workflow-status">{savedStatementMjv.status === 'completed' ? 'Posted / Completed' : savedStatementMjv.status === 'partially_posted' ? 'Partially posted' : 'Tasks posted'}</span>{/if}<button type="button" on:click={() => showFullDateJournal = false}>Back to transactions</button></div></header>
					{#if accountError}<div class="preview-error">{accountError}</div>{/if}
					{#if statementWorkflowMessage}<div class="workflow-message">{statementWorkflowMessage}</div>{/if}
					{#if fullPreview.errors.length}<div class="preview-error">{fullPreview.errors.join(' ')}</div>{/if}
					<div class="full-journal-content">
						<nav class="branch-journal-tabs" aria-label="Posting branches">
							{#each fullPreview.branchGroups as branchGroup}
								<button type="button" class:active={(selectedFullJournalBranch || fullPreview.branchGroups[0]?.branch) === branchGroup.branch} on:click={() => selectedFullJournalBranch = branchGroup.branch}>{branchGroup.branch}<span>{branchGroup.lines.length} lines</span></button>
							{/each}
						</nav>
						{#each fullPreview.branchGroups as branchGroup}
							{#if (selectedFullJournalBranch || fullPreview.branchGroups[0]?.branch) === branchGroup.branch}
							<section class="branch-journal-card">
								<header><div><span>Posting branch</span><strong>{branchGroup.branch}</strong></div><span class:unbalanced={Math.abs(branchGroup.debit - branchGroup.credit) >= 0.005} class="balance-badge">{Math.abs(branchGroup.debit - branchGroup.credit) < 0.005 ? 'Balanced' : 'Not balanced'}</span></header>
								<div class="branch-journal-table-scroll">
								<div class="full-journal-grid full-journal-grid-head"><span>Transaction</span><span>Entry type</span><span>Account</span><span>Narration</span><span>Debit</span><span>Credit</span></div>
								{#each branchGroup.lines as line}
									<div class="full-journal-grid"><strong>{line.transaction}<small>{line.description}</small></strong><span>{line.kind}</span><strong>{line.account}</strong><span>{line.narration}</span><span class="number debit">{line.debit ? amount(line.debit) : '—'}</span><span class="number credit">{line.credit ? amount(line.credit) : '—'}</span></div>
								{/each}
								</div>
								<div class="full-journal-grid branch-journal-total"><span></span><span></span><span></span><strong>Branch total</strong><strong class="number">{amount(branchGroup.debit)}</strong><strong class="number">{amount(branchGroup.credit)}</strong></div>
							</section>
							{/if}
						{/each}
						<div class="overall-journal-total"><strong>Overall total</strong><span>Debit: {amount(fullPreview.debit)}</span><span>Credit: {amount(fullPreview.credit)}</span></div>
					</div>
				</section>
			{/each}
		{:else}
		<div class="table-shell"><table>
			<thead><tr><th>Group</th><th>Date</th><th>Transaction description</th><th>Details</th><th>Reference</th><th>{transactionIdentifierLabel(transactionView)}</th><th class="number">Debit</th><th class="number">Credit</th><th class="number">Balance</th></tr></thead>
			{#each filteredStatementRows as row, transactionIndex}
				<tbody class:linked-group={row.children.length > 0} class:standalone-group={row.children.length === 0} class:group-alt={transactionIndex % 2 === 1}>
					<tr class="main-row">
						<td class="group-cell" rowspan={row.children.length + 1 + (expandedEntryRows.has(row.rowNumber) ? 1 : 0)}>
							<strong>{transactionNumber(transactionIndex)}</strong>
							<span>{row.children.length ? `${row.children.length + 1} grouped items` : '1 standalone row'}</span>
							{#if isPosTransaction(row)}
								<button class="entry-toggle" type="button" aria-expanded={expandedEntryRows.has(row.rowNumber)} on:click={() => toggleEntryPreview(row.rowNumber)}>{expandedEntryRows.has(row.rowNumber) ? 'Hide entry' : 'Show entry'}</button>
							{/if}
						</td>
						<td>{displayDate(row.date)}</td><td><span class="row-type main-type">Main</span><strong>{transactionDisplayDescription(row)}</strong></td><td>{row.details}</td><td>{row.reference}</td><td class="terminal-id">{transactionIdentifier(row)}</td><td class="number debit">{row.debit}</td><td class="number credit">{row.credit}</td><td class="number">{row.balance}</td>
					</tr>
					{#each row.children as child}
						<tr class="child-row"><td>{displayDate(child.date)}</td><td><span class:vat-type={childKind(child) === 'vat'} class="row-type">{childKind(child) === 'vat' ? 'VAT' : 'Fee'}</span><strong>{childKind(child) === 'vat' ? 'VAT on processing fee' : 'Processing fee'}</strong></td><td>{child.details}</td><td>{child.reference}</td><td class="terminal-id">{child.terminalId}</td><td class="number debit">{child.debit}</td><td class="number credit">{child.credit}</td><td class="number">{child.balance}</td></tr>
					{/each}
					{#if expandedEntryRows.has(row.rowNumber)}
						{#each [entryPreview(row)] as preview}
							<tr class="entry-preview-row"><td colspan="8">
								<section class="entry-preview" aria-label={`Journal entry preview for ${transactionNumber(transactionIndex)}`}>
									<header><div><strong>Complete journal entry</strong><span>Preview only — nothing will be posted</span></div>{#if !preview.error}<span class:unbalanced={Math.abs(preview.debit - preview.credit) >= 0.005} class="balance-badge">{Math.abs(preview.debit - preview.credit) < 0.005 ? 'Balanced' : 'Not balanced'}</span>{/if}</header>
									{#if preview.error}
										<div class="preview-error">{preview.error}</div>
									{:else}
										<div class="entry-grid entry-grid-head"><span>Posting branch</span><span>Entry type</span><span>Account</span><span>Narration</span><span>Debit</span><span>Credit</span></div>
										{#each preview.lines as line}
											<div class="entry-grid"><span>{line.branch}</span><span>{line.kind}</span><strong>{line.account}</strong><span>{line.narration}</span><span class="number debit">{line.debit ? amount(line.debit) : '—'}</span><span class="number credit">{line.credit ? amount(line.credit) : '—'}</span></div>
										{/each}
										<div class="entry-grid entry-total"><span></span><span></span><span></span><strong>Total</strong><strong class="number">{amount(preview.debit)}</strong><strong class="number">{amount(preview.credit)}</strong></div>
									{/if}
								</section>
							</td></tr>
						{/each}
					{/if}
				</tbody>
			{/each}
			{#if filteredStatementRows.length === 0}<tbody><tr><td class="accounts-empty" colspan="9">No transactions found in this category.</td></tr></tbody>{/if}
		</table></div>
		{/if}
	{:else if !errorMessage}
		<div class="empty-state"><div class="empty-icon">▤</div><h2>No statement imported</h2><p>Choose a bank, then import its Excel statement to arrange transactions with their fees and VAT.</p></div>
	{/if}
	{:else if activeTab === 'accounts'}
		<section class="accounts-manager">
			<header class="accounts-header"><div><h2>Manage Accounts</h2><p>Configure Input VAT and bank-fee posting accounts for each branch.</p></div><button class="add-account-button secondary" type="button" on:click={() => { showPostingForm = !showPostingForm; accountError = ''; accountMessage = ''; }}>+ Posting accounts</button></header>
			{#if showPostingForm}
				<div class="posting-form">
					<div class="account-field"><label for="posting-branch">Branch</label><input id="posting-branch" list="posting-statement-branches" bind:value={postingBranchSearch} on:change={selectPostingBranch} placeholder="Search and select active branch" /><datalist id="posting-statement-branches">{#each branches as branch}<option value={branchLabel(branch)}></option>{/each}</datalist></div>
					{#each [{ key: 'vat', label: 'Input VAT account' }, { key: 'riyad', label: 'Riyad Bank fee account' }, { key: 'ahli', label: 'Al Ahli Bank fee account' }] as field}
						<div class="ledger-search-field"><label for={`ledger-${field.key}`}>{field.label}</label><div class="ledger-search-row"><input id={`ledger-${field.key}`} list={`ledger-list-${field.key}`} bind:value={ledgerSearches[field.key]} on:change={() => choosePostingLedger(field.key as 'vat' | 'riyad' | 'ahli')} placeholder="Search SQL ledger" disabled={!postingBranchId} /><button type="button" disabled={!postingBranchId || searchingLedger === field.key} on:click={() => searchPostingLedger(field.key as 'vat' | 'riyad' | 'ahli')}>{searchingLedger === field.key ? '…' : 'Search'}</button></div><datalist id={`ledger-list-${field.key}`}>{#each ledgerChoices[field.key] as ledger}<option value={ledgerLabel(ledger)}></option>{/each}</datalist></div>
					{/each}
					<button class="save-terminal-button posting-save" type="button" disabled={savingPostingAccounts} on:click={savePostingAccounts}>{savingPostingAccounts ? 'Saving…' : 'Save accounts'}</button>
				</div>
			{/if}
			{#if accountError}<div class="account-alert error">{accountError}</div>{/if}
			{#if accountMessage}<div class="account-alert success">{accountMessage}</div>{/if}
			<div class="accounts-table-shell configured-accounts-table">
				<table class="accounts-table"><thead><tr><th>Branch</th><th>Input VAT account</th><th>Riyad Bank fee account</th><th>Al Ahli Bank fee account</th><th>Action</th></tr></thead><tbody>
					{#each postingAccounts as posting}<tr><td><strong>{posting.branch_name}</strong></td><td>{posting.input_vat_ledger_name}<small>{posting.input_vat_ledger_code || ''}</small></td><td>{posting.riyad_fee_ledger_name}<small>{posting.riyad_fee_ledger_code || ''}</small></td><td>{posting.ahli_fee_ledger_name}<small>{posting.ahli_fee_ledger_code || ''}</small></td><td><button class="edit-row-button" type="button" on:click={() => editPostingAccount(posting)}>Edit</button></td></tr>{/each}
					{#if postingAccounts.length === 0}<tr><td class="accounts-empty" colspan="5">No posting accounts configured yet.</td></tr>{/if}
				</tbody></table>
			</div>
		</section>
	{:else if activeTab === 'bank-accounts'}
		<section class="accounts-manager">
			<header class="accounts-header"><div><h2>Configured Bank Accounts</h2><p>Connect each bank and active branch to its real SQL Server bank ledger.</p></div><button class="add-account-button" type="button" on:click={() => { editingBankAccountId = null; bankAccountBranchSearch = ''; bankAccountBranchId = null; bankAccountBank = ''; bankAccountLedgerSearch = ''; selectedConfiguredLedger = null; bankAccountLedgerChoices = []; showBankAccountForm = !showBankAccountForm; accountError = ''; accountMessage = ''; }}>+ Add bank account</button></header>
			{#if showBankAccountForm}<div class="account-form configured-bank-form">
				<div class="account-field"><label for="configured-bank-branch">Branch</label><input id="configured-bank-branch" list="configured-bank-branches" bind:value={bankAccountBranchSearch} on:change={selectBankAccountBranch} placeholder="Search active branch" /><datalist id="configured-bank-branches">{#each branches as branch}<option value={branchLabel(branch)}></option>{/each}</datalist></div>
				<div class="account-field"><label for="configured-bank-name">Bank</label><select id="configured-bank-name" bind:value={bankAccountBank}><option value="">Choose bank</option><option value="al-ahli">Al Ahli (SNB)</option><option value="riyad">Riyad Bank</option></select></div>
				<div class="account-field"><label for="configured-bank-ledger">SQL bank account</label><input id="configured-bank-ledger" list="configured-bank-ledgers" bind:value={bankAccountLedgerSearch} on:change={chooseConfiguredBankLedger} disabled={!bankAccountBranchId || loadingConfiguredLedgers} placeholder={loadingConfiguredLedgers ? 'Loading bank accounts…' : 'Search and select bank account'} /><datalist id="configured-bank-ledgers">{#each bankAccountLedgerChoices as ledger}<option value={ledgerLabel(ledger)}></option>{/each}</datalist></div>
				<button class="save-terminal-button" type="button" disabled={savingConfiguredBankAccount} on:click={saveConfiguredBankAccount}>{savingConfiguredBankAccount ? 'Saving…' : editingBankAccountId ? 'Update' : 'Save'}</button>
			</div>{/if}
			{#if accountError}<div class="account-alert error">{accountError}</div>{/if}{#if accountMessage}<div class="account-alert success">{accountMessage}</div>{/if}
			<div class="accounts-table-shell"><table class="accounts-table"><thead><tr><th>Bank</th><th>Branch</th><th>Real bank account</th><th>Ledger code</th><th>Action</th></tr></thead><tbody>
				{#each configuredBankAccounts as account}<tr><td><strong>{account.bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli (SNB)'}</strong></td><td>{account.branch_name}</td><td>{account.ledger_name}</td><td>{account.ledger_code || account.ledger_id}</td><td><button class="edit-row-button" type="button" on:click={() => editConfiguredBankAccount(account)}>Edit</button></td></tr>{/each}
				{#if configuredBankAccounts.length === 0}<tr><td class="accounts-empty" colspan="5">No bank accounts configured yet.</td></tr>{/if}
			</tbody></table></div>
		</section>
	{:else if activeTab === 'terminals'}
		<section class="accounts-manager">
			<header class="accounts-header"><div><h2>Terminal Configuration</h2><p>Connect each POS terminal to one branch bank account.</p></div><button class="add-account-button" type="button" on:click={() => { editingTerminalId = null; terminalIdInput = ''; branchSearch = ''; activeBranchSearch = ''; selectedBranchId = null; selectedActiveBranchId = null; selectedBankLedgerId = ''; showAccountForm = !showAccountForm; accountError = ''; accountMessage = ''; }}>+ Add terminal</button></header>
			{#if showAccountForm}
				<div class="account-form">
					<div class="account-field"><label for="branch-search">Account branch</label><input id="branch-search" list="statement-branches" bind:value={branchSearch} on:change={selectAccountBranch} placeholder="Branch owning the bank account" /><datalist id="statement-branches">{#each branches as branch}<option value={branchLabel(branch)}></option>{/each}</datalist></div>
					<div class="account-field"><label for="active-branch-search">Active in branch</label><input id="active-branch-search" list="active-statement-branches" bind:value={activeBranchSearch} on:change={selectActiveBranch} placeholder="Terminal deployment branch" /><datalist id="active-statement-branches">{#each branches as branch}<option value={branchLabel(branch)}></option>{/each}</datalist></div>
					<div class="account-field"><label for="bank-account">Configured bank account</label><select id="bank-account" bind:value={selectedBankLedgerId} disabled={!selectedBranchId || loadingBankAccounts}><option value="">Select configured bank account</option>{#each bankAccounts as account}<option value={String(account.LedgerID)}>{account.Bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli'} — {account.LedgerName} ({account.LedgerCode})</option>{/each}</select></div>
					<div class="account-field"><label for="new-terminal-id">Terminal ID</label><input id="new-terminal-id" bind:value={terminalIdInput} placeholder="Enter terminal ID" /></div>
					<button class="save-terminal-button" type="button" disabled={savingTerminal} on:click={saveTerminalAccount}>{savingTerminal ? 'Saving…' : editingTerminalId ? 'Update' : 'Save'}</button>
				</div>
			{/if}
			{#if accountError}<div class="account-alert error">{accountError}</div>{/if}
			{#if accountMessage}<div class="account-alert success">{accountMessage}</div>{/if}
			<div class="accounts-table-shell">
				<table class="accounts-table"><thead><tr><th>Terminal ID</th><th>Account branch</th><th>Active in branch</th><th>Bank account</th><th>Ledger code</th><th>Action</th></tr></thead><tbody>
					{#each terminalAccounts as account}<tr><td class="terminal-id">{account.terminal_id}</td><td>{account.branch_name}</td><td><span class="active-branch-badge">{account.active_branch_name}</span></td><td>{account.bank_ledger_name}</td><td>{account.bank_ledger_code || '—'}</td><td><button class="edit-row-button" type="button" on:click={() => editTerminal(account)}>Edit</button></td></tr>{/each}
					{#if terminalAccounts.length === 0}<tr><td class="accounts-empty" colspan="6">No terminal accounts added yet.</td></tr>{/if}
				</tbody></table>
			</div>
		</section>
	{:else}
		<section class="accounts-manager task-status-manager">
			<header class="accounts-header task-status-header"><div><h2>Task Status</h2><p>Review saved statement MJVs and posting tasks for each configured bank account.</p></div><strong class="selected-task-date">{taskStatusDate ? `Selected: ${taskStatusDate}` : 'Select a date'}</strong></header>
			<div class="task-status-content">
			<section class="task-calendar" aria-label="Statement task calendar">
				<div class="task-calendar-go-to"><strong>Go to date</strong><select aria-label="Go to month" bind:value={taskGoToMonth}><option value="">Month</option>{#each ['January','February','March','April','May','June','July','August','September','October','November','December'] as monthName, index}<option value={String(index + 1)}>{monthName}</option>{/each}</select><select aria-label="Go to year" bind:value={taskGoToYear}><option value="">Year</option>{#each taskGoToYears(taskStatusMonth) as year}<option value={String(year)}>{year}</option>{/each}</select><select aria-label="Go to day" bind:value={taskGoToDay}><option value="">Day</option>{#each Array.from({ length: 31 }, (_, index) => index + 1) as day}<option value={String(day)}>{day}</option>{/each}</select><button type="button" on:click={goToTaskStatusDate}>Go</button><button class="clear-task-date" type="button" on:click={clearTaskStatusDate}>Clear</button></div>
				<header><button type="button" aria-label="Previous month" on:click|preventDefault={showPreviousTaskStatusMonth}>‹</button><h3>{taskCalendarMonthLabel(taskStatusMonth)}</h3><button type="button" aria-label="Next month" on:click|preventDefault={showNextTaskStatusMonth}>›</button></header>
				<div class="task-calendar-weekdays">{#each ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'] as weekday}<span>{weekday}</span>{/each}</div>
				<div class="task-calendar-days">{#each taskCalendarDays(taskStatusMonth) as date}<button type="button" class:outside={!date.currentMonth} class:selected={date.iso === taskStatusDate} class={date.currentMonth ? taskDateCountClass(taskMonthCounts[date.iso] || 0, taskMonthConfiguredBankCount) : ''} on:click={() => selectTaskStatusDate(date.iso)}><strong>{date.day}</strong>{#if date.currentMonth}<small>Configured {taskMonthConfiguredBankCount}</small><small>Saved {taskMonthCounts[date.iso] || 0}</small>{/if}</button>{/each}</div>
			</section>
			<div class="task-status-results">
			{#if taskStatusError}<div class="account-alert error">{taskStatusError}</div>{/if}
			<div class="accounts-table-shell task-status-table-shell">
				<table class="accounts-table task-status-table"><thead><tr><th>Bank</th><th>Bank account</th><th>Account branch</th><th>Saved MJV</th><th>Posting tasks</th><th>Task branch</th><th>Location</th><th>Assigned user</th><th>Task status</th>{#if $currentUser?.isMasterAdmin}<th>Master actions</th>{/if}</tr></thead><tbody>
					{#each taskStatusRows.filter((row) => row.statement_status !== 'completed') as row}
						<tr><td><strong>{row.bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli (SNB)'}</strong></td><td><span class="bank-account-name">{row.ledger_name}</span><small class="configured-bank-number">Configured bank number: {row.ledger_code || row.ledger_id}</small></td><td>{row.branch_name}</td><td><div class="saved-mjv-cell"><span class:status-saved={!!row.statement_mjv_id} class="task-status-badge">{row.statement_mjv_id ? row.statement_status : 'Not saved'}</span>{#if row.statement_mjv_id}<button type="button" class="expand-mjv-button" disabled={loadingSavedMjvId === String(row.statement_mjv_id)} on:click={() => toggleSavedMjvDetails(row)}>{loadingSavedMjvId === String(row.statement_mjv_id) ? 'Loading…' : expandedSavedMjvRows.has(String(row.statement_mjv_id)) ? 'Collapse' : 'Expand MJV'}</button>{/if}</div></td><td><span class:status-complete={row.statement_mjv_id && row.posted_task_count === row.branch_task_count} class:status-partial={row.statement_mjv_id && row.posted_task_count !== row.branch_task_count} class="task-posting-badge">{row.statement_mjv_id ? `${row.posted_task_count} of ${row.branch_task_count} assigned` : '—'}</span></td><td>{#if row.branch_tasks?.length}<div class="task-status-list">{#each row.branch_tasks as task}<span><strong>{task.branch_name}</strong></span>{/each}</div>{:else}—{/if}</td><td>{#if row.branch_tasks?.length}<div class="task-status-list">{#each row.branch_tasks as task}<span>{task.branch_location || '—'}</span>{/each}</div>{:else}—{/if}</td><td>{#if row.branch_tasks?.length}<div class="task-status-list">{#each row.branch_tasks as task}<span>{task.assigned_user_name || 'Not assigned'}</span>{/each}</div>{:else}—{/if}</td><td>{#if row.branch_tasks?.length}<div class="task-status-list">{#each row.branch_tasks as task}<span><span class:status-complete={task.task_status === 'completed'} class:status-partial={task.task_id && task.task_status !== 'completed'} class="task-posting-badge">{task.task_id ? task.task_status : 'Not assigned'}</span></span>{/each}</div>{:else}—{/if}</td>{#if $currentUser?.isMasterAdmin}<td><div class="statement-delete-actions"><button type="button" disabled={!row.posted_task_count || !!deletingStatementItem} on:click={() => deleteStatementItem(row,'tasks')}>{deletingStatementItem === `${row.statement_mjv_id}:tasks` ? 'Deleting…' : 'Delete tasks'}</button><button type="button" disabled={!row.statement_mjv_id || !!row.posted_task_count || !!deletingStatementItem} on:click={() => deleteStatementItem(row,'mjv')}>{deletingStatementItem === `${row.statement_mjv_id}:mjv` ? 'Deleting…' : 'Delete MJV'}</button></div></td>{/if}</tr>
						{#if row.statement_mjv_id && expandedSavedMjvRows.has(String(row.statement_mjv_id))}
							<tr class="saved-mjv-detail-row"><td colspan={$currentUser?.isMasterAdmin ? 10 : 9}>
								<section class="saved-mjv-preview">
									<header><div><strong>Saved MJV</strong><span>{row.bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli (SNB)'} · {taskStatusDate}</span></div><span class="balance-badge">Saved by branch</span></header>
									{#each savedMjvDetails[String(row.statement_mjv_id)]?.branches || [] as branch}
										<article class="saved-mjv-branch"><h4>{branch.branch_name}</h4><div class="saved-mjv-grid saved-mjv-grid-head"><span>Account</span><span>Narration</span><span>Debit</span><span>Credit</span></div>{#each branch.lines || [] as line}<div class="saved-mjv-grid"><span><strong>{line.ledger_name}</strong>{#if line.ledger_code}<small>{line.ledger_code}</small>{/if}</span><span>{line.narration}</span><span class="number debit">{line.side === 'Debit' ? amount(line.amount) : '—'}</span><span class="number credit">{line.side === 'Credit' ? amount(line.amount) : '—'}</span></div>{/each}</article>
									{/each}
								</section>
							</td></tr>
						{/if}
					{/each}
					{#if loadingTaskStatus}<tr><td class="accounts-empty" colspan={$currentUser?.isMasterAdmin ? 10 : 9}>Loading task status…</td></tr>{:else if !taskStatusDate}<tr><td class="accounts-empty" colspan={$currentUser?.isMasterAdmin ? 10 : 9}>Select a calendar date to view bank and task status.</td></tr>{:else if taskStatusRows.filter((row) => row.statement_status !== 'completed').length === 0}<tr><td class="accounts-empty" colspan={$currentUser?.isMasterAdmin ? 10 : 9}>All statement tasks for this date are completed.</td></tr>{/if}
				</tbody></table>
			</div>
			</div>
			</div>
		</section>
	{/if}
</div>

<style>
	.statement-manager{height:100%;overflow:hidden;padding:18px 24px 24px;background:#f4f7fb;color:#172033;font-family:'Segoe UI',sans-serif;box-sizing:border-box;display:flex;flex-direction:column}.import-panel{display:flex;align-items:flex-end;gap:12px;padding:18px;background:#fff;border:1px solid #dbe3ef;border-radius:14px;box-shadow:0 8px 22px rgba(15,23,42,.05);flex-shrink:0}.field{min-width:260px}label{display:block;margin-bottom:7px;color:#475569;font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.04em}select{width:100%;height:42px;padding:0 12px;border:1px solid #cbd5e1;border-radius:9px;background:#fff;color:#172033;font-size:14px}.import-button{height:42px;padding:0 18px;border:0;border-radius:9px;background:#0f766e;color:#fff;font-weight:700;cursor:pointer}.import-button:hover:not(:disabled){background:#115e59}.import-button:disabled{opacity:.45;cursor:not-allowed}.file-input{display:none}.file-name{min-width:0;padding-bottom:11px;overflow:hidden;color:#475569;font-size:13px;text-overflow:ellipsis;white-space:nowrap}.error-message{margin-top:14px;padding:12px 14px;border:1px solid #fecaca;border-radius:10px;background:#fef2f2;color:#b91c1c;flex-shrink:0}.summary-grid{display:grid;grid-template-columns:repeat(4,minmax(140px,1fr));gap:12px;margin:14px 0;flex-shrink:0}.summary-grid div{padding:14px 16px;border:1px solid #dbe3ef;border-radius:12px;background:#fff}.summary-grid span{display:block;color:#64748b;font-size:12px;font-weight:700}.summary-grid strong{display:block;margin-top:5px;font-size:23px}.source-note{flex-shrink:0;margin:-3px 0 10px;padding:8px 12px;border:1px solid #bfdbfe;border-radius:8px;background:#eff6ff;color:#1e40af;font-size:11px;font-weight:600}.table-shell{flex:1;min-height:0;overflow:auto;border:1px solid #dbe3ef;border-radius:13px;background:#fff;box-shadow:0 8px 22px rgba(15,23,42,.05)}table{width:100%;min-width:1360px;border-collapse:separate;border-spacing:0;font-size:12px}thead{position:sticky;top:0;z-index:2;background:#172033;color:#fff}th,td{padding:10px 12px;border-bottom:1px solid #dce5ef;text-align:left;vertical-align:top}th{font-size:11px;letter-spacing:.03em;text-transform:uppercase}.linked-group td{background:#eef7ff}.linked-group.group-alt td{background:#f2f1ff}.linked-group tr:first-child td{border-top:3px solid #3b82f6}.linked-group.group-alt tr:first-child td{border-top-color:#7c3aed}.linked-group tr:last-child td{border-bottom:3px solid #3b82f6}.linked-group.group-alt tr:last-child td{border-bottom-color:#7c3aed}.linked-group .group-cell{border-left:7px solid #3b82f6;background:#dbeafe}.linked-group.group-alt .group-cell{border-left-color:#7c3aed;background:#e8e5ff}.standalone-group .group-cell{border-left:7px solid #cbd5e1;background:#f8fafc}.standalone-group tr:hover td{background:#f8fafc}.group-cell{width:105px;vertical-align:middle;text-align:center}.group-cell strong{display:block;color:#172033;font-size:14px}.group-cell span{display:block;margin-top:5px;color:#64748b;font-size:10px;font-weight:700;line-height:1.25}.child-row td{border-top:1px dashed #a9bed5}.row-type{display:inline-flex;min-width:36px;justify-content:center;margin-right:8px;padding:3px 7px;border-radius:5px;background:#d1fae5;color:#047857;font-size:9px;font-weight:900;letter-spacing:.04em;text-transform:uppercase}.row-type.vat-type{background:#fef3c7;color:#a16207}.row-type.main-type{background:#dbeafe;color:#1d4ed8}.terminal-id{font-weight:700;white-space:nowrap;font-variant-numeric:tabular-nums}.number{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}.debit{color:#b42318}.credit{color:#087443}.empty-state{display:grid;place-items:center;min-height:0;flex:1;margin-top:18px;padding:30px;border:1px dashed #b7c4d6;border-radius:14px;background:rgba(255,255,255,.65);text-align:center}.empty-state>*{margin:0}.empty-state h2{margin-top:10px;font-size:18px}.empty-state p{max-width:520px;margin-top:7px;color:#64748b}.empty-icon{color:#0f766e;font-size:42px}@media(max-width:850px){.summary-grid{grid-template-columns:repeat(2,1fr)}.import-panel{align-items:stretch;flex-direction:column}.field{min-width:0}.file-name{padding:0}}
	.table-filters{display:flex;align-items:flex-end;gap:12px;margin:0 0 10px;flex-shrink:0}.filter-field{width:260px}.table-filters span{padding-bottom:11px;color:#475569;font-size:12px;font-weight:700}
	.manager-tabs{display:flex;gap:6px;margin-bottom:14px;padding:5px;border:1px solid #dbe3ef;border-radius:12px;background:#fff;flex-shrink:0;width:max-content}.manager-tabs button{height:38px;padding:0 20px;border:0;border-radius:8px;background:transparent;color:#64748b;font-size:13px;font-weight:800;cursor:pointer}.manager-tabs button:hover{background:#f1f5f9;color:#172033}.manager-tabs button.active{background:#0f766e;color:#fff;box-shadow:0 3px 8px rgba(15,118,110,.22)}.accounts-manager{display:flex;flex:1;min-height:0;flex-direction:column;padding:18px;border:1px solid #dbe3ef;border-radius:14px;background:#fff}.accounts-header{display:flex;align-items:center;justify-content:space-between;gap:16px}.accounts-header h2{margin:0;font-size:20px}.accounts-header p{margin:4px 0 0;color:#64748b;font-size:13px}.add-account-button,.save-terminal-button{height:40px;padding:0 17px;border:0;border-radius:9px;background:#0f766e;color:#fff;font-weight:800;cursor:pointer}.account-form{display:grid;grid-template-columns:minmax(220px,1fr) minmax(260px,1.4fr) minmax(180px,.8fr) auto;align-items:end;gap:12px;margin-top:16px;padding:16px;border:1px solid #cbd5e1;border-radius:12px;background:#f8fafc}.account-field input{width:100%;height:42px;box-sizing:border-box;padding:0 12px;border:1px solid #cbd5e1;border-radius:9px;background:#fff;color:#172033;font-size:14px}.save-terminal-button:disabled{opacity:.5;cursor:not-allowed}.account-alert{margin-top:12px;padding:10px 12px;border-radius:8px;font-size:12px;font-weight:700}.account-alert.error{background:#fef2f2;color:#b91c1c}.account-alert.success{background:#ecfdf5;color:#047857}.accounts-table-shell{min-height:0;flex:1;margin-top:16px;overflow:auto;border:1px solid #dbe3ef;border-radius:11px}.accounts-table{min-width:760px}.accounts-table thead{background:#e8eef6;color:#172033}.accounts-table th{border-bottom:1px solid #cbd5e1;color:#172033;font-weight:900}.accounts-empty{padding:40px;text-align:center;color:#64748b}@media(max-width:1000px){.account-form{grid-template-columns:1fr 1fr}.save-terminal-button{width:max-content}}
	.account-actions{display:flex;gap:8px}.add-account-button.secondary{background:#334155}.posting-form{display:grid;grid-template-columns:repeat(2,minmax(260px,1fr));gap:12px;margin-top:16px;padding:16px;border:1px solid #cbd5e1;border-radius:12px;background:#f8fafc}.ledger-search-field label{display:block}.ledger-search-row{display:flex;gap:7px}.ledger-search-row input{min-width:0;flex:1;height:42px;box-sizing:border-box;padding:0 12px;border:1px solid #cbd5e1;border-radius:9px;background:#fff}.ledger-search-row button{height:42px;padding:0 12px;border:1px solid #94a3b8;border-radius:9px;background:#fff;color:#334155;font-weight:800;cursor:pointer}.ledger-search-row button:disabled{opacity:.45}.posting-save{align-self:end;width:max-content}.posting-summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px;margin-top:14px}.posting-summary article{display:flex;flex-direction:column;gap:4px;padding:11px 13px;border:1px solid #dbe3ef;border-radius:10px;background:#f8fafc}.posting-summary article strong{font-size:13px}.posting-summary article span{color:#475569;font-size:11px}@media(max-width:1000px){.posting-form{grid-template-columns:1fr}.account-actions{flex-wrap:wrap}}
	.configured-accounts-table{margin-top:16px}.configured-accounts-table td{vertical-align:middle}.configured-accounts-table small{display:block;margin-top:4px;color:#64748b;font-size:10px;font-weight:700}
	.active-branch-badge{display:inline-flex;padding:4px 8px;border-radius:999px;background:#dcfce7;color:#166534;font-size:11px;font-weight:800}
	.task-status-header{align-items:flex-end}.selected-task-date{color:#0f766e;font-size:13px}.task-status-content{display:grid;grid-template-columns:570px minmax(0,1fr);gap:16px;min-height:0;flex:1;margin-top:16px}.task-calendar{width:100%;height:max-content;box-sizing:border-box;padding:14px;border:1px solid #cbd5e1;border-radius:12px;background:#f8fafc;box-shadow:0 4px 12px rgba(15,23,42,.06)}.task-calendar-go-to{display:grid;grid-template-columns:auto 1.35fr .8fr .65fr auto;align-items:center;gap:7px;margin-bottom:12px;padding-bottom:12px;border-bottom:1px solid #dbe3ef}.task-calendar-go-to>strong{font-size:11px;white-space:nowrap}.task-calendar-go-to select{height:34px;padding:0 8px;font-size:11px}.task-calendar-go-to button{height:34px;padding:0 13px;border:0;border-radius:7px;background:#0f766e;color:#fff;font-size:11px;font-weight:900;cursor:pointer}.task-calendar>header{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}.task-calendar h3{margin:0;font-size:16px}.task-calendar>header button{width:36px;height:32px;border:1px solid #94a3b8;border-radius:8px;background:#fff;color:#172033;font-size:23px;line-height:1;cursor:pointer}.task-calendar-weekdays,.task-calendar-days{display:grid;grid-template-columns:repeat(7,1fr);gap:5px}.task-calendar-weekdays span{text-align:center;color:#64748b;font-size:10px;font-weight:900;text-transform:uppercase}.task-calendar-days{margin-top:6px}.task-calendar-days button{display:flex;height:64px;flex-direction:column;align-items:center;justify-content:center;gap:2px;border:1px solid #e2e8f0;border-radius:7px;background:#fff;color:#334155;cursor:pointer}.task-calendar-days button strong{font-size:13px}.task-calendar-days button small{font-size:8px;font-weight:800}.task-calendar-days button.none-saved{border-color:#fca5a5;background:#fef2f2;color:#991b1b}.task-calendar-days button.partially-saved{border-color:#fdba74;background:#fff7ed;color:#9a3412}.task-calendar-days button.all-saved{border-color:#86efac;background:#f0fdf4;color:#166534}.task-calendar-days button:hover{border-color:#0f766e}.task-calendar-days button.outside{border-color:transparent;background:transparent;color:#a5b4c5}.task-calendar-days button.selected{outline:3px solid #0f766e;outline-offset:1px}.task-status-results{display:flex;min-width:0;min-height:0;flex-direction:column}.task-status-table{min-width:960px;table-layout:auto}.task-status-table-shell{margin-top:0;border-color:#cbd5e1;border-radius:12px;background:#fff;box-shadow:0 8px 22px rgba(15,23,42,.07)}.task-status-table thead{background:linear-gradient(135deg,#e8eef6,#dbe7f3)}.task-status-table th{padding:11px 10px;border-right:1px solid #bdcada;color:#26364d;white-space:nowrap}.task-status-table th:last-child{border-right:0}.task-status-table td{padding:11px 10px;border-right:1px solid #d6e0eb;vertical-align:middle;line-height:1.35}.task-status-table td:last-child{border-right:0}.task-status-table tbody tr:nth-child(even) td{background:#f8fafc}.task-status-table tbody tr{transition:background .15s ease,box-shadow .15s ease}.task-status-table tbody tr:hover td{background:#eef6f7}.task-status-table th:nth-child(1){width:90px}.task-status-table th:nth-child(2){width:125px}.task-status-table th:nth-child(5),.task-status-table th:nth-child(6){width:105px}.task-status-table th:last-child{width:140px}.task-status-list{display:flex;flex-direction:column;gap:6px}.task-status-list span{padding-bottom:5px;border-bottom:1px dashed #cbd5e1;font-size:11px}.task-status-list span:last-child{padding-bottom:0;border-bottom:0}.task-status-list strong{color:#334155}.task-status-badge,.task-posting-badge{display:inline-flex;align-items:center;padding:4px 8px;border-radius:999px;background:#fef2f2;color:#991b1b;font-size:10px;font-weight:900;white-space:nowrap}.task-status-badge.status-saved{background:#fff7ed;color:#9a3412}.task-posting-badge{background:#f1f5f9;color:#64748b}.task-posting-badge.status-partial{background:#fff7ed;color:#9a3412}.task-posting-badge.status-complete{background:#ecfdf5;color:#047857}@media(max-width:1250px){.task-status-content{grid-template-columns:1fr}.task-calendar{width:min(570px,100%)}.task-status-results{min-height:360px}}
	.edit-row-button{height:30px;padding:0 12px;border:1px solid #94a3b8;border-radius:7px;background:#fff;color:#334155;font-size:11px;font-weight:800;cursor:pointer}.edit-row-button:hover{border-color:#0f766e;background:#ecfdf5;color:#0f766e}
	.entry-toggle{width:82px;margin-top:10px;padding:6px 7px;border:1px solid #2563eb;border-radius:7px;background:#fff;color:#1d4ed8;font-size:10px;font-weight:900;cursor:pointer}.entry-toggle:hover{background:#eff6ff}.entry-preview-row>td{padding:10px 14px 14px;background:#f8fafc!important}.entry-preview{overflow:hidden;border:1px solid #94a3b8;border-radius:10px;background:#fff;box-shadow:0 3px 10px rgba(15,23,42,.08)}.entry-preview>header{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:11px 14px;background:#e2e8f0}.entry-preview>header div{display:flex;align-items:baseline;gap:10px}.entry-preview>header strong{font-size:13px}.entry-preview>header span{color:#64748b;font-size:10px;font-weight:700}.balance-badge{padding:4px 8px;border-radius:999px;background:#dcfce7;color:#166534!important;font-size:10px!important;font-weight:900!important}.balance-badge.unbalanced{background:#fee2e2;color:#991b1b!important}.entry-grid{display:grid;grid-template-columns:minmax(135px,.8fr) minmax(105px,.65fr) minmax(220px,1.45fr) minmax(280px,1.8fr) 100px 100px;align-items:center;border-top:1px solid #e2e8f0}.entry-grid>*{padding:8px 12px}.entry-grid-head{background:#f8fafc;color:#475569;font-size:9px;font-weight:900;text-transform:uppercase;letter-spacing:.04em}.entry-grid .number{text-align:right}.entry-total{background:#f8fafc;border-top:2px solid #94a3b8}.preview-error{padding:14px;background:#fef2f2;color:#b91c1c;font-weight:800}
	.full-journal-button{height:42px;padding:0 16px;border:0;border-radius:9px;background:#1d4ed8;color:#fff;font-size:12px;font-weight:900;cursor:pointer}.full-journal-button:disabled{opacity:.4;cursor:not-allowed}.full-journal-panel{display:flex;min-height:0;flex:1;flex-direction:column;overflow:hidden;border:1px solid #94a3b8;border-radius:13px;background:#fff;box-shadow:0 8px 22px rgba(15,23,42,.08)}.full-journal-header{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:14px 16px;border-bottom:1px solid #cbd5e1;background:#e8eef6}.full-journal-header h2{margin:0;font-size:16px}.full-journal-header p{margin:4px 0 0;color:#64748b;font-size:11px;font-weight:700}.full-journal-header button{height:34px;padding:0 13px;border:1px solid #64748b;border-radius:8px;background:#fff;color:#334155;font-size:11px;font-weight:900;cursor:pointer}.full-journal-content{display:flex;min-height:0;flex:1;flex-direction:column;overflow:hidden;padding:14px;background:#f1f5f9}.branch-journal-card{display:flex;min-width:0;min-height:0;flex:1;flex-direction:column;margin-bottom:12px;overflow:hidden;border:1px solid #94a3b8;border-radius:11px;background:#fff;box-shadow:0 3px 10px rgba(15,23,42,.06)}.branch-journal-card>header{display:flex;flex-shrink:0;align-items:center;justify-content:space-between;padding:11px 14px;background:#dbeafe}.branch-journal-card>header div{display:flex;align-items:baseline;gap:9px}.branch-journal-card>header div span{color:#475569;font-size:9px;font-weight:900;text-transform:uppercase}.branch-journal-card>header div strong{font-size:14px}.branch-journal-table-scroll{min-height:0;flex:1;overflow:auto}.full-journal-grid{display:grid;grid-template-columns:105px 115px minmax(230px,1.2fr) minmax(340px,1.8fr) 100px 100px;min-width:1250px;align-items:center;border-bottom:1px solid #e2e8f0;font-size:11px}.full-journal-grid>*{padding:9px 11px}.full-journal-grid small{display:block;margin-top:3px;color:#64748b;font-size:9px}.full-journal-grid-head{position:sticky;top:0;z-index:1;background:#172033;color:#fff;font-size:9px;font-weight:900;text-transform:uppercase}.branch-journal-total{flex-shrink:0;background:#f8fafc;border-top:2px solid #94a3b8;border-bottom:0}.overall-journal-total{display:flex;flex-shrink:0;justify-content:flex-end;gap:28px;padding:13px 16px;border:1px solid #64748b;border-radius:9px;background:#172033;color:#fff;font-variant-numeric:tabular-nums}.overall-journal-total span{font-weight:800}
	.branch-journal-tabs{display:flex;gap:7px;min-width:max-content;margin-bottom:12px}.branch-journal-tabs button{display:flex;align-items:center;gap:9px;height:40px;padding:0 14px;border:1px solid #94a3b8;border-radius:9px;background:#fff;color:#475569;font-size:11px;font-weight:900;cursor:pointer}.branch-journal-tabs button span{padding:3px 7px;border-radius:999px;background:#e2e8f0;color:#475569;font-size:9px}.branch-journal-tabs button.active{border-color:#1d4ed8;background:#1d4ed8;color:#fff}.branch-journal-tabs button.active span{background:#dbeafe;color:#1e40af}
	.workflow-actions{display:flex;align-items:center;justify-content:flex-end;gap:8px}.full-journal-header .save-mjv-button{border-color:#047857;background:#059669;color:#fff}.full-journal-header .post-mjv-button{border-color:#4338ca;background:#4f46e5;color:#fff}.full-journal-header button:disabled{opacity:.5;cursor:not-allowed}.workflow-status{padding:5px 9px;border-radius:999px;background:#dbeafe;color:#1e40af;font-size:10px;font-weight:900}.workflow-message{padding:9px 14px;border-bottom:1px solid #a7f3d0;background:#ecfdf5;color:#047857;font-size:11px;font-weight:800}
	.task-dialog-overlay{position:fixed;inset:0;z-index:12000;display:flex;align-items:center;justify-content:center;padding:24px;background:rgba(15,23,42,.58)}.task-dialog{width:min(720px,95vw);max-height:82vh;overflow:hidden;border-radius:14px;background:#fff;color:#172033;box-shadow:0 24px 70px rgba(0,0,0,.3)}.task-dialog>header{display:flex;align-items:flex-start;justify-content:space-between;padding:18px 20px;border-bottom:1px solid #cbd5e1;background:#f1f5f9}.task-dialog h2{margin:0;font-size:18px}.task-dialog p{margin:5px 0 0;color:#64748b;font-size:12px}.task-dialog>header button{border:0;background:transparent;color:#475569;font-size:24px;cursor:pointer}.task-branch-list{max-height:52vh;overflow:auto;padding:16px 20px}.task-branch-row{display:grid;grid-template-columns:minmax(180px,.8fr) minmax(300px,1.4fr);align-items:start;gap:14px;padding:13px 0;border-bottom:1px solid #e2e8f0}.task-branch-row>strong{padding-top:11px}.task-user-search input{width:100%;height:40px;box-sizing:border-box;padding:0 11px;border:1px solid #94a3b8;border-radius:8px}.task-user-search span{display:block;margin-top:5px;color:#047857;font-size:10px;font-weight:800}.task-dialog>footer{display:flex;justify-content:flex-end;gap:8px;padding:14px 20px;border-top:1px solid #cbd5e1;background:#f8fafc}.task-dialog>footer button{height:38px;padding:0 16px;border:1px solid #94a3b8;border-radius:8px;background:#fff;color:#334155;font-weight:800;cursor:pointer}.task-dialog>footer .post-selected-tasks{border-color:#4338ca;background:#4f46e5;color:#fff}.task-dialog>footer button:disabled{opacity:.5;cursor:not-allowed}
	.task-calendar-go-to{grid-template-columns:auto 1.35fr .8fr .65fr auto auto}.task-calendar-go-to .clear-task-date{border:1px solid #94a3b8;background:#fff;color:#475569}
	.task-calendar-days button.outside{border-color:#cbd5e1;background:#f1f5f9;color:#94a3b8}
	.task-calendar{padding:16px;border-color:#d7e1ec;border-radius:16px;background:linear-gradient(180deg,#fff 0%,#f8fafc 100%);box-shadow:0 10px 28px rgba(15,23,42,.09)}
	.task-calendar-go-to{margin:-16px -16px 14px;padding:14px 16px;border-bottom:1px solid #dbe5ef;border-radius:16px 16px 0 0;background:#f1f5f9}
	.task-calendar-go-to select{border-color:#cbd5e1;border-radius:8px;background:#fff;color:#334155;font-weight:700}
	.task-calendar-go-to button{box-shadow:0 3px 8px rgba(15,118,110,.2);transition:transform .15s ease,box-shadow .15s ease}
	.task-calendar-go-to button:hover{transform:translateY(-1px);box-shadow:0 5px 12px rgba(15,118,110,.25)}
	.task-calendar-go-to .clear-task-date{box-shadow:none}
	.task-calendar>header{margin:0 -2px 13px;padding:9px 10px;border-radius:11px;background:linear-gradient(135deg,#0f766e,#0d9488);color:#fff;box-shadow:0 5px 12px rgba(15,118,110,.18)}
	.task-calendar h3{color:#fff;font-size:17px;letter-spacing:.02em}
	.task-calendar>header button{border-color:rgba(255,255,255,.45);background:rgba(255,255,255,.14);color:#fff;transition:background .15s ease,transform .15s ease}
	.task-calendar>header button:hover{background:rgba(255,255,255,.27);transform:scale(1.04)}
	.task-calendar-weekdays{padding:0 2px}.task-calendar-weekdays span{padding:5px 0;color:#64748b;font-size:9px;letter-spacing:.08em}
	.task-calendar-days{gap:6px}.task-calendar-days button{border-width:1px;box-shadow:0 2px 5px rgba(15,23,42,.04);transition:transform .14s ease,box-shadow .14s ease,border-color .14s ease}
	.task-calendar-days button:hover{z-index:1;transform:translateY(-2px);box-shadow:0 7px 14px rgba(15,23,42,.12)}
	.task-calendar-days button.none-saved{background:linear-gradient(180deg,#fff7f7,#feecec)}
	.task-calendar-days button.partially-saved{background:linear-gradient(180deg,#fffaf2,#ffedd5)}
	.task-calendar-days button.all-saved{background:linear-gradient(180deg,#f5fff8,#dcfce7)}
	.task-calendar-days button.selected{outline:3px solid #0f766e;outline-offset:2px;box-shadow:0 7px 16px rgba(15,118,110,.22)}
	.task-calendar-days button.outside{box-shadow:none;opacity:.72}
	.task-calendar{border:1px solid #dbe3ef;border-radius:12px;background:#fff;box-shadow:0 8px 22px rgba(15,23,42,.05)}
	.task-calendar-go-to{border-bottom-color:#dbe3ef;border-radius:12px 12px 0 0;background:#f8fafc}
	.task-calendar-go-to select{border-color:#cbd5e1;background:#fff;color:#172033}
	.task-calendar-go-to button{background:#0f766e;box-shadow:none}
	.task-calendar-go-to button:hover{background:#115e59;box-shadow:none}
	.task-calendar>header{background:#e8eef6;color:#172033;box-shadow:none}
	.task-calendar h3{color:#172033}
	.task-calendar>header button{border-color:#94a3b8;background:#fff;color:#334155}
	.task-calendar>header button:hover{background:#f1f5f9;color:#0f766e}
	.task-calendar-days button{box-shadow:none}
	.task-calendar-days button:hover{border-color:#0f766e;background:#ecfdf5;box-shadow:none}
	.task-calendar-days button.none-saved{background:#fef2f2}
	.task-calendar-days button.partially-saved{background:#fff7ed}
	.task-calendar-days button.all-saved{background:#f0fdf4}
	.task-calendar-days button.selected{outline-color:#0f766e;box-shadow:none}
	.task-calendar{border-color:#cbd9ea}
	.task-calendar-go-to{background:#f4f8fc;border-bottom-color:#cbd9ea}
	.task-calendar-go-to button{background:#075985;color:#fff}
	.task-calendar-go-to button:hover{background:#0c4a6e}
	.task-calendar-go-to .clear-task-date{border-color:#8fa9c7;background:#fff;color:#06366f}
	.task-calendar>header{background:linear-gradient(90deg,#062a64 0%,#075b9d 72%,#089fc1 100%);color:#fff}
	.task-calendar h3{color:#fff}
	.task-calendar>header button{border-color:rgba(103,232,249,.65);background:rgba(255,255,255,.1);color:#fff}
	.task-calendar>header button:hover{background:#06b6d4;color:#062a64}
	.task-calendar-days button:hover{border-color:#089fc1;background:#ecfeff}
	.task-calendar-days button.selected{outline-color:#06b6d4;box-shadow:0 0 0 1px #062a64}
	.task-calendar{border-color:#164e80;background:linear-gradient(180deg,#082b59 0%,#071f43 100%);box-shadow:0 10px 24px rgba(3,22,52,.18)}
	.task-calendar-go-to{border-bottom-color:#1e5c8f;background:#0a376d;color:#fff}
	.task-calendar-go-to>strong{color:#67e8f9}
	.task-calendar-go-to select{border-color:#3678a8;background:#fff;color:#062a64}
	.task-calendar-go-to .clear-task-date{border-color:#67e8f9;background:transparent;color:#cffafe}
	.task-calendar-weekdays span{color:#a5f3fc}
	.task-calendar-days button{border-color:#38658d;background:#0d3b6f;color:#e0f2fe}
	.task-calendar-days button:hover{border-color:#22d3ee;background:#075985;color:#fff}
	.task-calendar-days button.none-saved{border-color:#f87171;background:#4c1d2b;color:#fecaca}
	.task-calendar-days button.partially-saved{border-color:#fb923c;background:#4a2b16;color:#fed7aa}
	.task-calendar-days button.all-saved{border-color:#4ade80;background:#123e39;color:#bbf7d0}
	.task-calendar-days button.outside{border-color:#315475;background:#0a294f;color:#7897b6;opacity:.8}
	.statement-delete-actions{display:flex;gap:6px;white-space:nowrap}.statement-delete-actions button{height:29px;padding:0 9px;border:1px solid #dc2626;border-radius:6px;background:#fff;color:#b91c1c;font-size:10px;font-weight:800;cursor:pointer}.statement-delete-actions button:hover:not(:disabled){background:#fef2f2}.statement-delete-actions button:disabled{opacity:.4;cursor:not-allowed}
	.task-status-theme{background:linear-gradient(135deg,#061a36 0%,#082b59 55%,#063f68 100%)}
	.task-status-theme .manager-tabs{border-color:#245b87;background:#092d59;box-shadow:0 8px 20px rgba(2,15,36,.2)}
	.task-status-theme .manager-tabs button{color:#b9d9ef}
	.task-status-theme .manager-tabs button:hover{background:#0d467b;color:#fff}
	.task-status-theme .manager-tabs button.active{background:linear-gradient(90deg,#075b9d,#089fc1);color:#fff;box-shadow:0 3px 10px rgba(6,182,212,.25)}
	.task-status-theme .task-status-manager{border-color:#245b87;background:#071f43;color:#e0f2fe;box-shadow:0 14px 34px rgba(2,15,36,.28)}
	.task-status-theme .task-status-header{padding-bottom:13px;border-bottom:1px solid #245b87}
	.task-status-theme .task-status-header h2{color:#fff}
	.task-status-theme .task-status-header p{color:#9fc7df}
	.task-status-theme .selected-task-date{padding:6px 10px;border:1px solid #22d3ee;border-radius:999px;background:#0a376d;color:#a5f3fc}
	.task-status-theme .task-status-results{border:1px solid #245b87;border-radius:12px;background:#08264d;overflow:hidden}
	.task-status-theme .task-status-table-shell{border:0;border-radius:0;background:#08264d}
	.task-status-theme .task-status-table thead{background:linear-gradient(90deg,#062a64,#075b9d);color:#fff}
	.task-status-theme .task-status-table th{border-color:#2a638f;color:#cffafe}
	.task-status-theme .task-status-table td{border-color:#234d75;background:#0a315f;color:#dbeafe}
	.task-status-theme .task-status-table tbody tr:nth-child(even) td{background:#0b3769}
	.task-status-theme .task-status-table tbody tr:hover td{background:#0d467b}
	.task-status-theme .task-status-table td strong{color:#fff}
	.task-status-theme .task-status-list strong{color:#67e8f9}
	.task-status-theme .accounts-empty{color:#9fc7df}
	.task-status-theme .account-alert.error{border:1px solid #f87171;background:#4c1d2b;color:#fecaca}
	.task-status-theme .import-panel,.task-status-theme .summary-grid div,.task-status-theme .accounts-manager,.task-status-theme .empty-state{border-color:#245b87;background:#071f43;color:#e0f2fe;box-shadow:0 8px 22px rgba(2,15,36,.18)}
	.task-status-theme label,.task-status-theme .summary-grid span,.task-status-theme .accounts-header p,.task-status-theme .file-name,.task-status-theme .table-filters span{color:#9fc7df}
	.task-status-theme select,.task-status-theme input{border-color:#3678a8;background:#fff;color:#062a64}
	.task-status-theme .import-button,.task-status-theme .add-account-button,.task-status-theme .save-terminal-button{background:#075b9d;color:#fff}
	.task-status-theme .import-button:hover:not(:disabled),.task-status-theme .add-account-button:hover,.task-status-theme .save-terminal-button:hover:not(:disabled){background:#089fc1}
	.task-status-theme .source-note{border-color:#3678a8;background:#0a376d;color:#bae6fd}
	.task-status-theme .table-shell,.task-status-theme .accounts-table-shell{border-color:#245b87;background:#08264d;box-shadow:0 8px 22px rgba(2,15,36,.18)}
	.task-status-theme table thead,.task-status-theme .accounts-table thead{background:linear-gradient(90deg,#062a64,#075b9d);color:#fff}
	.task-status-theme table th,.task-status-theme .accounts-table th{border-color:#2a638f;color:#cffafe}
	.task-status-theme table td,.task-status-theme .accounts-table td{border-color:#234d75;background:#0a315f;color:#dbeafe}
	.task-status-theme table tbody tr:nth-child(even) td,.task-status-theme .accounts-table tbody tr:nth-child(even) td{background:#0b3769}
	.task-status-theme table tbody tr:hover td,.task-status-theme .accounts-table tbody tr:hover td{background:#0d467b}
	.task-status-theme table td strong,.task-status-theme .accounts-header h2{color:#fff}
	.task-status-theme .account-form,.task-status-theme .posting-form,.task-status-theme .posting-summary article{border-color:#245b87;background:#08264d;color:#dbeafe}
	.task-status-theme .posting-summary article span,.task-status-theme .configured-accounts-table small{color:#9fc7df}
	.task-status-theme .edit-row-button,.task-status-theme .ledger-search-row button{border-color:#67e8f9;background:#0a376d;color:#cffafe}
	.task-status-theme .edit-row-button:hover,.task-status-theme .ledger-search-row button:hover{background:#075985;color:#fff}
	.task-status-theme .empty-state h2{color:#fff}.task-status-theme .empty-state p{color:#9fc7df}.task-status-theme .empty-icon{color:#22d3ee}
	.task-status-theme .full-journal-panel,.task-status-theme .entry-preview,.task-status-theme .branch-journal-card{border-color:#245b87;background:#08264d;color:#dbeafe}
	.task-status-theme .full-journal-header,.task-status-theme .entry-preview>header,.task-status-theme .branch-journal-card>header{border-color:#2a638f;background:#0a376d;color:#fff}
	.task-status-theme .full-journal-content{background:#061a36}.task-status-theme .full-journal-grid,.task-status-theme .entry-grid{border-color:#234d75}
	.task-status-theme .full-journal-grid-head,.task-status-theme .overall-journal-total{background:#062a64;color:#fff}
	.task-status-theme .branch-journal-tabs button{border-color:#3678a8;background:#0a315f;color:#bae6fd}.task-status-theme .branch-journal-tabs button.active{border-color:#22d3ee;background:#075b9d;color:#fff}
	.task-status-table{width:100%;min-width:0;table-layout:fixed}
	.task-status-table th:nth-child(1){width:6%}
	.task-status-table th:nth-child(2){width:28%;min-width:0}
	.task-status-table th:nth-child(3){width:18%}
	.task-status-table th:nth-child(4){width:8%}
	.task-status-table th:nth-child(5){width:8%}
	.task-status-table th:nth-child(6){width:19%;min-width:0}
	.task-status-table th:nth-child(7){width:13%}
	.task-status-table td:nth-child(2),.task-status-table td:nth-child(3){white-space:normal;overflow-wrap:anywhere}
	.task-status-table td:nth-child(6){white-space:normal}
	.task-status-table td:nth-child(7){white-space:nowrap}
	.task-status-table .statement-delete-actions{gap:5px}
	.task-status-table .statement-delete-actions button{padding:0 7px;font-size:9px}
	.task-status-table th,.task-status-table td{padding-left:7px;padding-right:7px}
	.task-status-table th:nth-child(1){width:6%}
	.task-status-table th:nth-child(2){width:18%}
	.task-status-table th:nth-child(3){width:13%}
	.task-status-table th:nth-child(4){width:8%}
	.task-status-table th:nth-child(5){width:8%}
	.task-status-table th:nth-child(6){width:10%}
	.task-status-table th:nth-child(7){width:8%}
	.task-status-table th:nth-child(8){width:8%}
	.task-status-table th:nth-child(9){width:7%}
	.task-status-table th:nth-child(10){width:14%}
	.task-status-table td:nth-child(7),.task-status-table td:nth-child(8),.task-status-table td:nth-child(9){white-space:normal;overflow-wrap:anywhere}
	.task-status-table td:nth-child(10){white-space:nowrap}
	.task-status-table .statement-delete-actions{justify-content:flex-start;gap:4px}
	.task-status-table .statement-delete-actions button{padding:0 5px;font-size:8px}
	.transaction-view-tabs{display:flex;flex-shrink:0;gap:8px;width:100%;box-sizing:border-box;margin:0 0 10px;padding:5px;overflow-x:auto;border:1px solid #dbe3ef;border-radius:11px;background:#fff}
	.transaction-view-tabs button{flex:0 0 auto}
	.transaction-view-tabs button{display:flex;align-items:center;gap:9px;height:36px;padding:0 13px;border:0;border-radius:7px;background:transparent;color:#475569;font-size:11px;font-weight:800;cursor:pointer;white-space:nowrap}
	.transaction-view-tabs button:hover{background:#f1f5f9;color:#172033}
	.transaction-view-tabs button.active{background:#0f766e;color:#fff;box-shadow:0 3px 8px rgba(15,118,110,.2)}
	.transaction-view-tabs button strong{display:inline-flex;min-width:22px;height:20px;align-items:center;justify-content:center;padding:0 6px;border-radius:999px;background:#e2e8f0;color:#334155;font-size:10px}
	.transaction-view-tabs button.active strong{background:rgba(255,255,255,.2);color:#fff}
	.bank-account-name{display:block;font-weight:700;color:#334155}
	.configured-bank-number{display:block;margin-top:5px;color:#64748b;font-size:10px;font-weight:800}
	.saved-mjv-cell{display:flex;flex-direction:column;align-items:flex-start;gap:6px}
	.expand-mjv-button{height:25px;padding:0 8px;border:1px solid #0f766e;border-radius:6px;background:#fff;color:#0f766e;font-size:9px;font-weight:900;white-space:nowrap;cursor:pointer}
	.expand-mjv-button:hover:not(:disabled){background:#ecfdf5}
	.expand-mjv-button:disabled{opacity:.55;cursor:not-allowed}
	.saved-mjv-detail-row>td{padding:10px!important;border-right:0!important;background:#f1f5f9!important}
	.saved-mjv-preview{max-height:min(480px,55vh);overflow:auto;overscroll-behavior:contain;scrollbar-gutter:stable;border:1px solid #94a3b8;border-radius:10px;background:#fff;box-shadow:0 3px 10px rgba(15,23,42,.08)}
	.saved-mjv-preview>header{position:sticky;top:0;z-index:2;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 12px;border-bottom:1px solid #cbd5e1;background:#e8eef6}
	.saved-mjv-preview>header div{display:flex;align-items:baseline;gap:10px}
	.saved-mjv-preview>header span{color:#64748b;font-size:10px;font-weight:700}
	.saved-mjv-branch{margin:10px;overflow:auto;border:1px solid #dbe3ef;border-radius:8px}
	.saved-mjv-branch h4{margin:0;padding:8px 10px;border-bottom:1px solid #dbe3ef;background:#f8fafc;font-size:11px}
	.saved-mjv-grid{display:grid;grid-template-columns:minmax(190px,1fr) minmax(320px,2fr) 95px 95px;min-width:800px;border-bottom:1px solid #e2e8f0;font-size:10px}
	.saved-mjv-grid:last-child{border-bottom:0}
	.saved-mjv-grid>*{padding:7px 9px}
	.saved-mjv-grid small{display:block;margin-top:2px;color:#64748b;font-size:9px}
	.saved-mjv-grid-head{background:#172033;color:#fff;font-size:9px;font-weight:900;text-transform:uppercase}
</style>
