<script>
	import { onMount, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { currentUser } from '$lib/utils/persistentAuth';

	let vendors = [];
	let paymentBranches = [];
	let branchSavingKey = '';
	let branchBankSchedule = null;
	let branchBankSelection = '';
	let bankLedgers = [];
	let bankLedgerSearch = '';
	let selectedBankLedgerId = null;
	let loadingBankLedgers = false;
	let bankLedgerError = '';
	$: filteredBankLedgers = bankLedgers.filter(ledger => {
		const search = bankLedgerSearch.trim().toLowerCase();
		return !search || ledger.ledgerName.toLowerCase().includes(search)
			|| ledger.groupName.toLowerCase().includes(search)
			|| String(ledger.ledgerId).includes(search);
	});
	let vendorSearch = '';
	let selectedVendor = null;
	let showVendors = false;
	let vendorsLoading = true;
	let vendorError = '';
	let activeVendorIndex = -1;
	let vendorResultsElement;
	const vendorInputId = `bank-planner-vendor-${Math.random().toString(36).slice(2)}`;
	let unpaidItems = [];
	let selectedItemKeys = new Set();
	let draftSchedules = [];
	let expandedScheduleKeys = new Set();
	let bpPreviews = {};
	let bpPreviewLoading = new Set();
	let bpPreviewErrors = {};
	let plannerTasksByVendor = {};
	let postingScheduleKey = '';
	let transferAmount = '';
	let transferPlan = null;
	let transferError = '';
	let autoTransferSaving = false;
	let scheduleMessage = '';
	let scheduleLoading = false;
	let scheduleSaving = false;
	let scheduleError = '';
	let scheduleRequest = 0;
	$: scheduleTotal = draftSchedules.reduce((total, schedule) => total + schedule.items.reduce((sum, item) => sum + item.amount, 0), 0);
	$: scheduledItemKeys = new Set(draftSchedules.flatMap(schedule => schedule.items.map(item => item.key)));
	$: selectedItems = unpaidItems.filter(item => selectedItemKeys.has(item.key));
	$: selectedTotal = selectedItems.reduce((total, item) => total + item.amount, 0);
	$: selectableItems = unpaidItems.filter(item => !scheduledItemKeys.has(item.key));
	$: allItemsSelected = selectableItems.length > 0 && selectedItems.length === selectableItems.length;

	function toggleItemSelection(key, checked) {
		transferPlan = null;
		transferError = '';
		const next = new Set(selectedItemKeys);
		if (checked) next.add(key);
		else next.delete(key);
		selectedItemKeys = next;
	}

	function toggleAllItems(checked) {
		transferPlan = null;
		transferError = '';
		selectedItemKeys = checked ? new Set(unpaidItems.filter(item => !scheduledItemKeys.has(item.key)).map(item => item.key)) : new Set();
	}

	function toggleScheduleDetails(schedule) {
		const next = new Set(expandedScheduleKeys);
		if (next.has(schedule.key)) next.delete(schedule.key);
		else {
			next.add(schedule.key);
			if (!bpPreviews[schedule.key] && !bpPreviewErrors[schedule.key]) loadBpPreview(schedule);
		}
		expandedScheduleKeys = next;
	}

	async function loadBpPreview(schedule) {
		if (!schedule?.paidFromBranchId || !schedule?.bankLedgerName) {
			bpPreviewErrors = { ...bpPreviewErrors, [schedule.key]: 'Select the paying branch and bank first.' };
			return;
		}
		const loading = new Set(bpPreviewLoading);
		loading.add(schedule.key);
		bpPreviewLoading = loading;
		bpPreviewErrors = { ...bpPreviewErrors, [schedule.key]: '' };
		try {
			const payingBranchId = Number(schedule.paidFromBranchId);
			const vendorId = String(schedule.vendorId || '').trim();
			const branchIds = [...new Set(schedule.items.map(item => Number(item.source_branch_id)).filter(Number.isFinite))];
			if (branchIds.length === 0 || schedule.items.some(item => !item.source_branch_id)) {
				throw new Error('A source branch is missing from one or more scheduled records.');
			}
			const otherBranchIds = branchIds.filter(branchId => branchId !== payingBranchId);
			const vendorLedgers = new Map(await Promise.all(branchIds.concat(payingBranchId)
				.filter((branchId, index, values) => values.indexOf(branchId) === index)
				.map(async branchId => [branchId, await loadVendorLedgerForPreview(branchId, vendorId, schedule.vendorName)])));
			let crossBranchAccounts = [];
			if (otherBranchIds.length > 0) {
				const { data, error } = await supabase.rpc('get_bank_planner_cross_branch_accounts', {
					p_paying_branch_id: payingBranchId, p_other_branch_ids: otherBranchIds
				});
				if (error) throw error;
				crossBranchAccounts = data || [];
			}
			const billDetails = items => items.map(item => {
				const billNumber = item.bill_number || item.requisition_number || `${item.type}-${item.id}`;
				return `${billNumber} (${item.branch_location || 'Unknown branch'})`;
			}).join(', ');
			const payingVendor = vendorLedgers.get(payingBranchId);
			const entries = [{
				entry: 'BP 1', type: 'bp', postingBranchId: payingBranchId, postingBranch: getPaymentBranchLabel(payingBranchId),
				debitLedger: payingVendor, creditLedger: { id: schedule.bankLedgerId, name: schedule.bankLedgerName },
				amount: schedule.items.reduce((sum, item) => sum + item.amount, 0),
				narration: `Bills ${billDetails(schedule.items)}`
			}];
			let jvNumber = 1;
			for (const otherBranchId of otherBranchIds) {
				const branchItems = schedule.items.filter(item => Number(item.source_branch_id) === otherBranchId);
				const amount = branchItems.reduce((sum, item) => sum + item.amount, 0);
				const payingBranchAccount = crossBranchAccounts.find(account => Number(account.source_branch_id) === payingBranchId && Number(account.target_branch_id) === otherBranchId);
				const otherBranchAccount = crossBranchAccounts.find(account => Number(account.source_branch_id) === otherBranchId && Number(account.target_branch_id) === payingBranchId);
				if (!payingBranchAccount || !otherBranchAccount) throw new Error(`Both reciprocal default branch accounts are required for ${branchItems[0]?.branch_location || 'the other branch'}.`);
				entries.push({
					entry: `JV ${jvNumber++}`, type: 'jv', postingBranchId: payingBranchId, postingBranch: getPaymentBranchLabel(payingBranchId),
					debitLedger: { id: payingBranchAccount.target_ledger_id, name: payingBranchAccount.target_ledger_name },
					creditLedger: payingVendor, amount,
					narration: `Transfer ${billDetails(branchItems)} to ${branchItems[0]?.branch_location || 'other branch'}`
				});
				entries.push({
					entry: `JV ${jvNumber++}`, type: 'jv', postingBranchId: otherBranchId, postingBranch: getPaymentBranchLabel(otherBranchId),
					debitLedger: vendorLedgers.get(otherBranchId),
					creditLedger: { id: otherBranchAccount.target_ledger_id, name: otherBranchAccount.target_ledger_name },
					amount, narration: `Payment by ${getPaymentBranchLabel(payingBranchId)} for ${billDetails(branchItems)}`
				});
			}
			bpPreviews = { ...bpPreviews, [schedule.key]: entries };
			return entries;
		} catch (error) {
			bpPreviewErrors = { ...bpPreviewErrors, [schedule.key]: error.message || 'Unable to prepare the ERP entry preview.' };
			return null;
		} finally {
			const nextLoading = new Set(bpPreviewLoading);
			nextLoading.delete(schedule.key);
			bpPreviewLoading = nextLoading;
		}
	}

	async function loadVendorLedgerForPreview(branchId, vendorId, vendorName) {
		const { data: connection, error } = await supabase.from('erp_connections')
			.select('erp_branch_id').eq('branch_id', branchId).eq('is_active', true).maybeSingle();
		if (error) throw error;
		if (!connection?.erp_branch_id) throw new Error(`No active ERP connection for ${getPaymentBranchLabel(branchId)}.`);
		const sql = `SELECT DISTINCT l.LedgerID, l.LedgerName, p.PartyCode FROM Parties p INNER JOIN AccLedgers l ON l.LedgerCode = p.PartyCode AND l.BranchID = p.BranchID WHERE p.BranchID = ${Number(connection.erp_branch_id)} AND l.IsActive = 1 ORDER BY l.LedgerName`;
		const response = await authenticatedFetch('/api/erp-products', {
			method: 'POST', headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'query', branchId, sql })
		});
		const result = await response.json();
		if (!response.ok || !result.success) throw new Error(result.error || `Failed to load vendor ledgers from ${getPaymentBranchLabel(branchId)}.`);
		const rows = result.recordset || [];
		// vendors.erp_vendor_id is the ERP PartyCode/LedgerCode. Require both the
		// exact code and a strong name match so an unrelated internal LedgerID can
		// never select the vendor account.
		const codeMatches = rows.filter(row => String(row.PartyCode || '').trim() === vendorId);
		const rankedMatches = codeMatches
			.map(row => ({ row, similarity: getNameSimilarity(vendorName, row.LedgerName) }))
			.sort((a, b) => b.similarity - a.similarity);
		const match = rankedMatches[0];
		if (!match?.row?.LedgerName || match.similarity < 0.8) {
			throw new Error(`No vendor ledger matched code ${vendorId} and at least 80% of the vendor name in ${getPaymentBranchLabel(branchId)}.`);
		}
		return { code: String(match.row.PartyCode).trim(), name: String(match.row.LedgerName).trim() };
	}

	function getNameSimilarity(left, right) {
		const normalize = value => String(value || '').toLowerCase()
			.normalize('NFKC').replace(/[^\p{L}\p{N}]+/gu, ' ').trim().replace(/\s+/g, ' ');
		const a = normalize(left);
		const b = normalize(right);
		if (!a || !b) return 0;
		if (a === b || a.includes(b) || b.includes(a)) return 1;
		const previous = Array.from({ length: b.length + 1 }, (_, index) => index);
		for (let i = 1; i <= a.length; i += 1) {
			let diagonal = previous[0];
			previous[0] = i;
			for (let j = 1; j <= b.length; j += 1) {
				const above = previous[j];
				previous[j] = Math.min(previous[j] + 1, previous[j - 1] + 1, diagonal + (a[i - 1] === b[j - 1] ? 0 : 1));
				diagonal = above;
			}
		}
		return 1 - (previous[b.length] / Math.max(a.length, b.length));
	}
	let unpaidLoading = false;
	let unpaidError = '';
	let unpaidRequest = 0;
	let splitItem = null;
	let splitAmount = '';
	let splitDate = '';
	let splitSaving = false;
	let splitError = '';
	let splitSuccess = '';
	let approvalPermissions = null;
	let approvalPermissionsError = '';
	let approvingKey = '';
	let approvalError = '';
	let approvalSuccess = '';
	let permissionsRequest = 0;

	$: loadApprovalPermissions($currentUser?.id);

	async function loadApprovalPermissions(userId) {
		const request = ++permissionsRequest;
		approvalPermissions = null;
		approvalPermissionsError = '';
		if (!userId) return;
		const { data, error } = await supabase.from('approval_permissions').select('*')
			.eq('user_id', userId).eq('is_active', true).maybeSingle();
		if (request !== permissionsRequest) return;
		if (error) approvalPermissionsError = 'Unable to load approval permissions.';
		else approvalPermissions = data;
	}

	function approvalBlockedReason(item, permissions, user) {
		if (!permissions || permissions.user_id !== user?.id) return 'Active approval permission required.';
		const isBill = item.type === 'Bill';
		const permission = isBill ? permissions.can_approve_vendor_payments : permissions.can_approve_requisitions;
		const rawLimit = isBill ? permissions.vendor_payment_amount_limit : permissions.requisition_amount_limit;
		const amount = isBill ? item.amount : item.approval_amount;
		const approver = isBill ? item.assigned_approver_id : item.requisition_approver_id;
		if ((!isBill || approver != null) && approver !== user?.id) return 'Assigned to another approver.';
		if (!permission || rawLimit == null || amount == null) return 'You do not have permission to approve this record.';
		const limit = Number(rawLimit);
		if (!Number.isFinite(limit) || (limit !== 0 && Number(amount) > limit)) return 'Amount exceeds your approval limit.';
		return '';
	}

	async function approveItem(item) {
		if (approvingKey || splitSaving || approvalBlockedReason(item, approvalPermissions, $currentUser)) return;
		const vendor = selectedVendor;
		approvingKey = item.key;
		approvalError = '';
		approvalSuccess = '';
		try {
			const { error } = await supabase.rpc('bank_planner_approve_payment', { p_type: item.type, p_id: String(item.id) });
			if (error) throw error;
			approvalSuccess = 'Approved successfully.';
			if (selectedVendor === vendor) await loadUnpaidItems(vendor);
		} catch (error) {
			approvalError = error.message || 'Unable to approve this record.';
		} finally {
			approvingKey = '';
		}
	}

	$: loadUnpaidItems(selectedVendor);
	$: unpaidTotal = unpaidItems.reduce((total, item) => total + item.amount, 0);

	async function fetchUnpaid(table, fields, vendorId) {
		const rows = [];
		for (let offset = 0; ; offset += 1000) {
			const { data, error } = await supabase.from(table).select(fields)
				.eq('vendor_id', vendorId).eq('is_paid', false)
				.order('id').range(offset, offset + 999);
			if (error) throw error;
			rows.push(...(data || []));
			if (!data || data.length < 1000) return rows;
		}
	}

	async function loadUnpaidItems(vendor) {
		const request = ++unpaidRequest;
		selectedItemKeys = new Set();
		unpaidItems = [];
		unpaidError = '';
		unpaidLoading = false;
		if (vendor?.erp_vendor_id == null) return;
		unpaidLoading = true;
		try {
			const [bills, expenses] = await Promise.all([
				fetchUnpaid('vendor_payment_schedule', 'id, bill_number, bill_date, due_date, branch_id, branch_name, bill_amount, final_bill_amount, payment_method, approval_status, assigned_approver_id', vendor.erp_vendor_id),
				fetchUnpaid('expense_scheduler', 'id, bill_number, bill_date, due_date, branch_id, branch_name, description, amount, payment_method, requisition_id, requisition_number, created_at', vendor.erp_vendor_id)
			]);
			const branchIds = [...new Set([...bills, ...expenses].map(item => item.branch_id).filter(id => id != null))];
			const branchLocations = new Map();
			for (let offset = 0; offset < branchIds.length; offset += 100) {
				const { data, error } = await supabase.from('branches')
					.select('id, location_en').in('id', branchIds.slice(offset, offset + 100));
				if (error) throw error;
				for (const branch of data || []) branchLocations.set(String(branch.id), branch.location_en);
			}
			// Approved payment schedules move into expense_scheduler. Requisition
			// expenses retain a link to the source approval record.
			const requisitionIds = [...new Set(expenses.map(expense => expense.requisition_id).filter(id => id != null))];
			const requisitionStatuses = new Map();
			for (let offset = 0; offset < requisitionIds.length; offset += 100) {
				const { data, error } = await supabase.from('expense_requisitions')
					.select('id, status, amount, approver_id').in('id', requisitionIds.slice(offset, offset + 100));
				if (error) throw error;
				for (const requisition of data || []) {
					requisitionStatuses.set(String(requisition.id), requisition);
				}
			}
			if (request !== unpaidRequest) return;
			unpaidItems = [
				...bills.map(bill => ({ ...bill, key: `bill-${bill.id}`, type: 'Bill', description: '', amount: Number(bill.final_bill_amount ?? bill.bill_amount ?? 0), status: bill.approval_status })),
				...expenses.map(expense => ({
					...expense, key: `expense-${expense.id}`, type: 'Expense', amount: Number(expense.amount ?? 0),
					status: expense.requisition_id == null ? 'approved'
						: getRequisitionApprovalStatus(requisitionStatuses.get(String(expense.requisition_id))?.status),
					approval_amount: requisitionStatuses.get(String(expense.requisition_id))?.amount,
					requisition_approver_id: requisitionStatuses.get(String(expense.requisition_id))?.approver_id
				}))
			].map(item => ({ ...item, branch_location: branchLocations.get(String(item.branch_id)) || '—' }))
				.sort((a, b) => (a.due_date || '9999').localeCompare(b.due_date || '9999') || a.branch_location.localeCompare(b.branch_location));
		} catch (error) {
			if (request === unpaidRequest) unpaidError = 'Unable to load unpaid bills and expenses. Please try again.';
		} finally {
			if (request === unpaidRequest) unpaidLoading = false;
		}
	}

	function formatAmount(amount) {
		return amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}

	function formatEntryDate(value) {
		if (!value) return '—';
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return '—';
		return date.toLocaleDateString('en-GB', {
			timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit'
		});
	}

	function formatBillDate(value) {
		if (!value) return '—';
		const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})(?:$|T| )/);
		return match ? `${match[3]}/${match[2]}/${match[1]}` : formatEntryDate(value);
	}

	function getDueStatus(value) {
		const match = String(value || '').match(/^(\d{4})-(\d{2})-(\d{2})(?:$|T| )/);
		if (!match) return { label: 'No due date', color: 'text-slate-500' };
		const parts = new Intl.DateTimeFormat('en-US', {
			timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit'
		}).formatToParts(new Date());
		const dateParts = Object.fromEntries(parts.map(part => [part.type, part.value]));
		const todayUtc = Date.UTC(Number(dateParts.year), Number(dateParts.month) - 1, Number(dateParts.day));
		const dueUtc = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
		const daysOverdue = Math.round((todayUtc - dueUtc) / 86400000);
		if (daysOverdue > 0) return {
			label: `Overdue by ${daysOverdue} ${daysOverdue === 1 ? 'day' : 'days'}`, color: 'text-red-600'
		};
		if (daysOverdue === 0) return { label: 'Due today', color: 'text-amber-600' };
		return { label: 'Not due', color: 'text-slate-500' };
	}

	function getRequisitionApprovalStatus(status) {
		if (status === 'completed' || status === 'approved') return 'approved';
		if (status === 'pending' || status === 'rejected') return status;
		return 'unknown';
	}

	onMount(() => {
		loadVendors();
		loadPaymentBranches();
	});

	async function loadPaymentBranches() {
		const { data, error } = await supabase.from('branches')
			.select('id, name_en, location_en').eq('is_active', true).order('name_en');
		if (!error) {
			paymentBranches = data || [];
			// The saved schedule can finish loading before the branch catalog.
			// Reassign the rows so saved branch IDs render their names immediately.
			draftSchedules = [...draftSchedules];
		}
	}

	async function loadVendors() {
		vendorsLoading = true;
		vendorError = '';
		try {
			const loaded = [];
			for (let offset = 0; ; offset += 1000) {
				const { data, error } = await supabase.from('vendors')
					.select('erp_vendor_id, vendor_name, branch_id')
					.order('vendor_name').order('erp_vendor_id').order('branch_id')
					.range(offset, offset + 999);
				if (error) throw error;
				loaded.push(...(data || []));
				if (!data || data.length < 1000) break;
			}
			// One searchable vendor per ERP ID, regardless of branch.
			const vendorMap = new Map();
			for (const vendor of loaded) {
				if (vendor.erp_vendor_id == null) continue;
				const vendorId = String(vendor.erp_vendor_id).trim();
				if (!vendorId) continue;
				if (!vendorMap.has(vendorId)) {
					vendorMap.set(vendorId, {
						erp_vendor_id: vendorId,
						vendor_name: vendor.vendor_name || vendorId
					});
				}
			}
			vendors = Array.from(vendorMap.values()).sort((a, b) => a.vendor_name.localeCompare(b.vendor_name));
		} catch (error) {
			vendorError = 'Unable to load vendors. Please try again.';
		} finally {
			vendorsLoading = false;
		}
	}

	$: matchingVendors = vendors.filter(vendor => {
		const search = vendorSearch.trim().toLowerCase();
		return !search || String(vendor.vendor_name || '').toLowerCase().includes(search)
			|| String(vendor.erp_vendor_id || '').toLowerCase().includes(search);
	});
	$: visibleVendors = matchingVendors.slice(0, 50);
	$: if (matchingVendors) activeVendorIndex = -1;

	async function handleVendorKeydown(event) {
		if (event.key === 'Escape' || event.key === 'Tab') {
			showVendors = false;
			activeVendorIndex = -1;
			return;
		}
		if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
			event.preventDefault();
			showVendors = true;
			if (vendorsLoading || vendorError || visibleVendors.length === 0) return;
			if (activeVendorIndex < 0) {
				activeVendorIndex = event.key === 'ArrowDown' ? 0 : visibleVendors.length - 1;
			} else {
				activeVendorIndex = (activeVendorIndex + (event.key === 'ArrowDown' ? 1 : -1) + visibleVendors.length) % visibleVendors.length;
			}
			await tick();
			vendorResultsElement?.querySelector(`[data-vendor-index="${activeVendorIndex}"]`)?.scrollIntoView({ block: 'nearest' });
		} else if (event.key === 'Enter' && showVendors && !vendorsLoading && !vendorError && visibleVendors.length > 0) {
			event.preventDefault();
			selectVendor(visibleVendors[activeVendorIndex < 0 ? 0 : activeVendorIndex]);
		}
	}

	function selectVendor(vendor) {
		if (splitSaving || approvingKey) return;
		splitItem = null;
		splitSuccess = '';
		transferAmount = '';
		transferPlan = null;
		transferError = '';
		selectedVendor = vendor;
		vendorSearch = vendor.vendor_name || String(vendor.erp_vendor_id);
		showVendors = false;
		activeVendorIndex = -1;
	}

	const today = new Date();
	const currentYear = today.getFullYear();
	let selectedYear = currentYear;
	let selectedMonth = today.getMonth() + 1;
	let selectedDay = today.getDate();

	const years = Array.from({ length: 21 }, (_, index) => currentYear - 10 + index);
	const months = Array.from({ length: 12 }, (_, index) => ({
		value: index + 1,
		label: new Date(2000, index, 1).toLocaleDateString('en-US', { month: 'long' })
	}));

	$: daysInMonth = new Date(selectedYear, selectedMonth, 0).getDate();
	$: days = Array.from({ length: daysInMonth }, (_, index) => index + 1);
	$: if (selectedDay > daysInMonth) selectedDay = daysInMonth;
	$: selectedScheduleDate = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
	$: if ($currentUser?.id && selectedScheduleDate) loadSchedule(selectedScheduleDate);

	async function loadSchedule(date) {
		const request = ++scheduleRequest;
		draftSchedules = [];
		expandedScheduleKeys = new Set();
		bpPreviews = {};
		bpPreviewErrors = {};
		plannerTasksByVendor = {};
		scheduleError = '';
		scheduleMessage = '';
		if (!date || !$currentUser?.id) return;
		scheduleLoading = true;
		const { data, error } = await supabase.rpc('get_bank_payment_planner_schedule', { p_schedule_date: date });
		if (request !== scheduleRequest) return;
		if (error) scheduleError = error.message;
		else {
			const groups = new Map();
			for (const item of data?.items || []) {
				const vendorId = String(item.vendor_id);
				if (!groups.has(vendorId)) groups.set(vendorId, {
					key: `${vendorId}-${date}`, vendorId, vendorName: item.vendor_name, date,
					paidFromBranchId: item.paid_from_branch_id == null ? '' : String(item.paid_from_branch_id),
					bankLedgerId: item.bank_ledger_id == null ? null : Number(item.bank_ledger_id),
					bankLedgerName: item.bank_ledger_name || '', items: []
				});
				groups.get(vendorId).items.push({
					...item, key: `${item.source_type.toLowerCase()}-${item.source_id}`,
					type: item.source_type, id: item.source_id,
					branch_location: item.branch_location, status: item.approval_status,
					created_at: item.entered_date, amount: Number(item.amount || 0)
				});
			}
			draftSchedules = Array.from(groups.values());
			await loadPlannerTaskStates(date);
		}
		if (request === scheduleRequest) scheduleLoading = false;
	}

	async function loadPlannerTaskStates(date) {
		try {
			const response = await authenticatedFetch(`/api/assistant-tasks?bank_planner_date=${encodeURIComponent(date)}`, {
				headers: { 'x-aqura-interface': 'desktop' }
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to load posting task status.');
			const grouped = {};
			for (const task of result.tasks || []) {
				const vendorId = String(task.payload?.vendor_id || '');
				if (!vendorId) continue;
				if (!grouped[vendorId]) grouped[vendorId] = [];
				grouped[vendorId].push(task);
			}
			plannerTasksByVendor = grouped;
		} catch (error) {
			console.error('Unable to load Bank Payment Planner task status:', error);
		}
	}

	async function postScheduleTasks(schedule) {
		if (postingScheduleKey || plannerTasksByVendor[schedule.vendorId]?.length) return;
		postingScheduleKey = schedule.key;
		scheduleError = '';
		scheduleMessage = '';
		try {
			const entries = bpPreviews[schedule.key] || await loadBpPreview(schedule);
			if (!entries?.length) throw new Error(bpPreviewErrors[schedule.key] || 'Unable to prepare the ERP entries.');
			const response = await authenticatedFetch('/api/assistant-tasks', {
				method: 'POST', headers: { 'Content-Type': 'application/json', 'x-aqura-interface': 'desktop' },
				body: JSON.stringify({
					task_type: 'bank_payment_planner', schedule_date: selectedScheduleDate,
					vendor_id: schedule.vendorId, entries
				})
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to post the ERP tasks.');
			plannerTasksByVendor = { ...plannerTasksByVendor, [schedule.vendorId]: result.tasks || [] };
			scheduleMessage = `${result.tasks?.length || entries.length} posting task(s) sent to the branch Entry Task user(s).`;
		} catch (error) {
			scheduleError = error.message || 'Unable to post the ERP tasks.';
		} finally {
			postingScheduleKey = '';
		}
	}

	async function persistScheduleItems(sourceItems, vendor) {
		const items = sourceItems.map(item => ({
				source_type: item.type, source_id: String(item.id),
				source_branch_id: item.branch_id,
				vendor_id: String(vendor.erp_vendor_id), vendor_name: vendor.vendor_name,
				branch_location: item.branch_location || '',
				bill_number: item.bill_number || item.requisition_number || (item.type === 'Expense' ? `EXP-${item.id}` : ''),
				description: item.description || '', bill_date: item.bill_date || '',
				entered_date: item.created_at || '', due_date: item.due_date || '',
				payment_method: item.payment_method || '', approval_status: item.status || '', amount: item.amount
			}));
		const { data, error } = await supabase.rpc('add_bank_payment_planner_schedule_items', {
				p_schedule_date: selectedScheduleDate, p_items: items
			});
		if (error) throw error;
		return data;
	}

	async function addToSchedule() {
		if (!selectedVendor || selectedItems.length === 0 || splitSaving || approvingKey || scheduleSaving) return;
		scheduleSaving = true;
		scheduleError = '';
		scheduleMessage = '';
		try {
			const data = await persistScheduleItems(selectedItems, selectedVendor);
			selectedItemKeys = new Set();
			const addedMessage = data?.added > 0
				? `${data.added} ${data.added === 1 ? 'record added' : 'records added'} to ${formatBillDate(selectedScheduleDate)}.`
				: 'These records are already in this date’s schedule.';
			await loadSchedule(selectedScheduleDate);
			scheduleMessage = addedMessage;
		} catch (error) {
			scheduleError = error.message || 'Unable to save the schedule.';
		} finally {
			scheduleSaving = false;
		}
	}

	function prepareTransferPlan(value) {
		transferAmount = value;
		transferPlan = null;
		transferError = '';
		const target = Number(value);
		const targetCents = Math.round(target * 100);
		if (!value) {
			selectedItemKeys = new Set();
			return;
		}
		if (!Number.isFinite(target) || target <= 0 || Math.abs(target * 100 - targetCents) > 0.000001) {
			selectedItemKeys = new Set();
			transferError = 'Enter a valid amount with up to two decimal places.';
			return;
		}
		const candidates = unpaidItems.filter(item => item.status === 'approved' && !scheduledItemKeys.has(item.key));
		const availableCents = candidates.reduce((sum, item) => sum + Math.round(item.amount * 100), 0);
		if (targetCents > availableCents) {
			selectedItemKeys = new Set(candidates.map(item => item.key));
			transferError = `Approved unscheduled balance is ${formatAmount(availableCents / 100)} SAR.`;
			return;
		}
		let remainingCents = targetCents;
		const fullItems = [];
		let partialItem = null;
		for (const item of candidates) {
			const itemCents = Math.round(item.amount * 100);
			if (itemCents <= remainingCents) {
				fullItems.push(item);
				remainingCents -= itemCents;
			} else if (remainingCents > 0) {
				partialItem = item;
				break;
			}
			if (remainingCents === 0) break;
		}
		selectedItemKeys = new Set(fullItems.map(item => item.key));
		transferPlan = {
			targetAmount: targetCents / 100,
			fullItems,
			fullTotal: fullItems.reduce((sum, item) => sum + item.amount, 0),
			partialItem,
			partialAmount: remainingCents / 100
		};
	}

	async function confirmTransferPlan() {
		if (!transferPlan || !selectedVendor || autoTransferSaving || scheduleSaving || approvingKey) return;
		const plan = transferPlan;
		const vendor = selectedVendor;
		autoTransferSaving = true;
		splitSaving = true;
		scheduleSaving = true;
		scheduleError = '';
		transferError = '';
		try {
			const scheduleItems = [...plan.fullItems];
			if (plan.partialItem && plan.partialAmount > 0) {
				const { data, error } = await supabase.rpc('bank_planner_split_payment', {
					p_type: plan.partialItem.type, p_id: String(plan.partialItem.id),
					p_amount: plan.partialAmount, p_date: selectedScheduleDate,
					p_expected_amount: plan.partialItem.amount
				});
				if (error) throw error;
				await loadUnpaidItems(vendor);
				const splitRecord = unpaidItems.find(item => item.type === data?.source_type && String(item.id) === String(data?.source_id));
				if (!splitRecord) throw new Error('The split was created, but its new record could not be loaded. Refresh and add it to the schedule.');
				scheduleItems.push(splitRecord);
			}
			const data = await persistScheduleItems(scheduleItems, vendor);
			await loadSchedule(selectedScheduleDate);
			scheduleMessage = `${formatAmount(plan.targetAmount)} SAR added to ${formatBillDate(selectedScheduleDate)} (${data?.added || 0} records).`;
			selectedItemKeys = new Set();
			transferAmount = '';
			transferPlan = null;
		} catch (error) {
			transferError = error.message || 'Unable to prepare this transfer.';
		} finally {
			autoTransferSaving = false;
			splitSaving = false;
			scheduleSaving = false;
		}
	}

	async function removeScheduledVendor(schedule) {
		if (scheduleSaving) return;
		scheduleSaving = true;
		scheduleError = '';
		const { error } = await supabase.rpc('remove_bank_payment_planner_scheduled_vendor', {
			p_schedule_date: schedule.date, p_vendor_id: schedule.vendorId
		});
		if (error) scheduleError = error.message;
		else await loadSchedule(selectedScheduleDate);
		scheduleSaving = false;
	}

	async function setPaidFromBranch(schedule, branchId) {
		if (branchSavingKey || scheduleSaving) return false;
		branchSavingKey = schedule.key;
		scheduleError = '';
		const { error } = await supabase.rpc('set_bank_payment_planner_paid_from_branch', {
			p_schedule_date: schedule.date,
			p_vendor_id: schedule.vendorId,
			p_branch_id: branchId ? Number(branchId) : null
		});
		if (error) scheduleError = error.message;
		else {
			draftSchedules = draftSchedules.map(entry => entry.key === schedule.key
				? { ...entry, paidFromBranchId: branchId } : entry);
		}
		branchSavingKey = '';
		return !error;
	}

	function getPaymentBranchLabel(branchId) {
		if (!branchId) return 'Select branch & bank';
		const branch = paymentBranches.find(entry => String(entry.id) === String(branchId));
		return branch ? `${branch.name_en}${branch.location_en ? ` - ${branch.location_en}` : ''}` : 'Selected branch';
	}

	async function openBranchBankPopup(schedule) {
		branchBankSchedule = schedule;
		branchBankSelection = schedule.paidFromBranchId || '';
		selectedBankLedgerId = schedule.bankLedgerId ?? null;
		bankLedgerSearch = schedule.bankLedgerName || '';
		bankLedgers = [];
		bankLedgerError = '';
		scheduleError = '';
		if (branchBankSelection) await loadBankLedgers(Number(branchBankSelection));
	}

	async function loadBankLedgers(branchId) {
		bankLedgers = [];
		bankLedgerError = '';
		loadingBankLedgers = true;
		try {
			const { data: connection, error } = await supabase.from('erp_connections')
				.select('erp_branch_id').eq('branch_id', branchId).eq('is_active', true).maybeSingle();
			if (error) throw error;
			if (!connection?.erp_branch_id) throw new Error('No active ERP connection for this branch.');
			const sql = `SELECT l.LedgerID, l.LedgerName, g.AccGroupName FROM AccLedgers l LEFT JOIN AccGroups g ON g.AccGroupID = l.AccGroupID AND g.BranchID = l.BranchID WHERE l.BranchID = ${Number(connection.erp_branch_id)} AND l.IsActive = 1 AND LOWER(COALESCE(g.AccGroupName, '')) LIKE '%bank%' ORDER BY l.LedgerName`;
			const response = await authenticatedFetch('/api/erp-products', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'query', branchId, sql })
			});
			const result = await response.json();
			if (!result.success) throw new Error(result.error || 'Failed to load bank ledgers.');
			bankLedgers = (result.recordset || []).map(row => ({
				ledgerId: Number(row.LedgerID), ledgerName: String(row.LedgerName || '').trim(),
				groupName: String(row.AccGroupName || '').trim()
			}));
		} catch (error) {
			bankLedgerError = error.message || 'Failed to load bank ledgers.';
		} finally {
			loadingBankLedgers = false;
		}
	}

	async function changePopupBranch(branchId) {
		branchBankSelection = branchId;
		selectedBankLedgerId = null;
		bankLedgerSearch = '';
		bankLedgers = [];
		bankLedgerError = '';
		if (branchId) await loadBankLedgers(Number(branchId));
	}

	function selectBankLedger(ledger) {
		selectedBankLedgerId = ledger.ledgerId;
		bankLedgerSearch = ledger.ledgerName;
	}

	async function saveBranchBankPopup() {
		if (!branchBankSchedule || !branchBankSelection || selectedBankLedgerId == null) return;
		const ledger = bankLedgers.find(item => item.ledgerId === selectedBankLedgerId);
		if (!ledger) {
			bankLedgerError = 'Select a bank ledger from the live results.';
			return;
		}
		branchSavingKey = branchBankSchedule.key;
		scheduleError = '';
		const { error } = await supabase.rpc('set_bank_payment_planner_branch_bank', {
			p_schedule_date: branchBankSchedule.date,
			p_vendor_id: branchBankSchedule.vendorId,
			p_branch_id: Number(branchBankSelection),
			p_bank_ledger_id: ledger.ledgerId,
			p_bank_ledger_name: ledger.ledgerName
		});
		if (error) scheduleError = error.message;
		else {
			const updatedSchedule = {
				...branchBankSchedule, paidFromBranchId: branchBankSelection,
				bankLedgerId: ledger.ledgerId, bankLedgerName: ledger.ledgerName
			};
			draftSchedules = draftSchedules.map(entry => entry.key === branchBankSchedule.key ? updatedSchedule : entry);
			const nextPreviews = { ...bpPreviews };
			delete nextPreviews[branchBankSchedule.key];
			bpPreviews = nextPreviews;
			const nextErrors = { ...bpPreviewErrors };
			delete nextErrors[branchBankSchedule.key];
			bpPreviewErrors = nextErrors;
			if (expandedScheduleKeys.has(branchBankSchedule.key)) loadBpPreview(updatedSchedule);
			branchBankSchedule = null;
		}
		branchSavingKey = '';
	}

	function beginSplit(item) {
		if (approvingKey) return;
		splitItem = item;
		splitAmount = '';
		splitDate = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-${String(selectedDay).padStart(2, '0')}`;
		splitError = '';
		splitSuccess = '';
	}

	async function saveSplit() {
		if (!splitItem || splitSaving || approvingKey) return;
		const amount = Number(splitAmount);
		const amountCents = Math.round(amount * 100);
		if (!Number.isFinite(amount) || amount <= 0 || amountCents >= Math.round(splitItem.amount * 100)
			|| Math.abs(amount * 100 - amountCents) > 0.000001 || !splitDate) {
			splitError = 'Enter a date and an amount greater than zero and less than the unpaid amount (up to two decimal places).';
			return;
		}
		const vendor = selectedVendor;
		splitSaving = true;
		splitError = '';
		try {
			const { error } = await supabase.rpc('bank_planner_split_payment', {
				p_type: splitItem.type, p_id: String(splitItem.id), p_amount: amount,
				p_date: splitDate, p_expected_amount: splitItem.amount
			});
			if (error) throw error;
			splitItem = null;
			splitSuccess = 'Split saved successfully.';
			await loadUnpaidItems(vendor);
		} catch (error) {
			splitError = error.message || 'Unable to save the split.';
		} finally {
			splitSaving = false;
		}
	}
</script>

<div class="relative flex h-full w-full overflow-hidden bg-white">
	<section aria-label="Vendor bills and expenses" class="h-full w-1/2 min-w-0 overflow-auto border-r border-slate-200 p-2">
	<div class="flex flex-wrap items-end gap-2">
		<label class="flex flex-col gap-1 text-sm font-medium text-slate-700">
			Year
			<select bind:value={selectedYear} class="w-32 rounded-md border border-slate-300 bg-white pl-3 pr-10 py-2">
				{#each years as year}
					<option value={year}>{year}</option>
				{/each}
			</select>
		</label>
		<label class="flex flex-col gap-1 text-sm font-medium text-slate-700">
			Month
			<select bind:value={selectedMonth} class="w-44 rounded-md border border-slate-300 bg-white pl-3 pr-10 py-2">
				{#each months as month}
					<option value={month.value}>{month.label}</option>
				{/each}
			</select>
		</label>
		<label class="flex flex-col gap-1 text-sm font-medium text-slate-700">
			Day
			<select bind:value={selectedDay} class="w-28 rounded-md border border-slate-300 bg-white pl-3 pr-10 py-2">
				{#each days as day}
					<option value={day}>{day}</option>
				{/each}
			</select>
		</label>
	</div>
	<div class="mt-2">
		<div class="relative w-full">
			<label for={vendorInputId} class="mb-1 block text-sm font-medium text-slate-700">Vendor</label>
			<div class="flex gap-2">
				<input id={vendorInputId} type="search" bind:value={vendorSearch}
					disabled={splitSaving || !!approvingKey}
					role="combobox" aria-autocomplete="list" aria-expanded={showVendors}
					aria-controls={`${vendorInputId}-results`}
					aria-activedescendant={showVendors && activeVendorIndex >= 0 ? `${vendorInputId}-option-${activeVendorIndex}` : undefined}
					placeholder="Search vendor name or ID"
					on:focus={() => showVendors = true}
					on:input={() => { selectedVendor = null; splitItem = null; splitSuccess = ''; showVendors = true; }}
					on:keydown={handleVendorKeydown}
					class="min-w-0 flex-1 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
				{#if selectedVendor}
					<button type="button" disabled={splitSaving || !!approvingKey} on:click={() => { selectedVendor = null; splitItem = null; splitSuccess = ''; vendorSearch = ''; showVendors = true; }}
						class="rounded-md border border-slate-300 px-3 text-sm">Clear</button>
				{/if}
			</div>
			{#if showVendors}
				<div bind:this={vendorResultsElement} id={`${vendorInputId}-results`} role="listbox" aria-label="Vendors" class="absolute z-20 mt-1 max-h-64 w-full overflow-y-auto rounded-md border border-slate-200 bg-white shadow-lg">
					{#if vendorsLoading}
						<p class="p-3 text-sm text-slate-500">Loading vendors…</p>
					{:else if vendorError}
						<p class="p-3 text-sm text-red-600">{vendorError}</p>
						<button type="button" on:click={loadVendors} class="px-3 pb-3 text-sm text-blue-600">Retry</button>
					{:else if matchingVendors.length === 0}
						<p class="p-3 text-sm text-slate-500">No vendors found.</p>
					{:else}
						{#each visibleVendors as vendor, index}
							<button type="button" role="option" tabindex="-1"
								id={`${vendorInputId}-option-${index}`} data-vendor-index={index}
								aria-selected={activeVendorIndex === index}
								on:click={() => selectVendor(vendor)}
								class="block w-full px-3 py-2 text-left hover:bg-slate-100 focus:bg-slate-100 {activeVendorIndex === index ? 'bg-blue-100' : ''}">
								<span class="block text-sm font-medium text-slate-800">{vendor.vendor_name}</span>
								<span class="block text-xs text-slate-500">ID: {vendor.erp_vendor_id} · All branches</span>
							</button>
						{/each}
						{#if matchingVendors.length > 50}
							<p class="p-3 text-xs text-slate-500">Type more to narrow the results.</p>
						{/if}
					{/if}
				</div>
			{/if}
		</div>
	</div>

	{#if selectedVendor}
		<div class="mt-2">
			{#if approvalPermissionsError}<p role="alert" class="mb-2 text-sm text-red-600">{approvalPermissionsError}</p>{/if}
			{#if approvalError}<p role="alert" class="mb-2 text-sm text-red-600">{approvalError}</p>{/if}
			{#if approvalSuccess}<p role="status" class="mb-2 text-sm text-green-700">{approvalSuccess}</p>{/if}
			<div class="mb-2 flex flex-wrap items-center justify-between gap-2">
				<h2 class="text-sm font-semibold text-slate-800">Unpaid bills and expenses — {selectedVendor.vendor_name} (All branches)</h2>
				<button type="button" on:click={() => loadUnpaidItems(selectedVendor)} disabled={unpaidLoading || splitSaving} class="rounded-md border border-slate-300 px-3 py-2 text-sm disabled:opacity-50">Refresh</button>
			</div>
			{#if unpaidLoading}
				<p class="text-sm text-slate-500">Loading unpaid bills and expenses…</p>
			{:else if unpaidError}
				<p role="alert" class="text-sm text-red-600">{unpaidError}</p>
			{:else}
				<div class="mb-2 flex flex-wrap items-center justify-between gap-2 text-sm">
					<label class="flex items-center gap-2 font-medium text-slate-700">
						Amount to transfer (SAR)
						<input type="number" min="0.01" step="0.01" bind:value={transferAmount}
							disabled={autoTransferSaving || scheduleSaving}
							on:input={() => { transferPlan = null; transferError = ''; selectedItemKeys = new Set(); }}
							class="transfer-amount-input w-36 rounded border border-slate-300 px-2 py-1 text-right" placeholder="0.00" />
						<button type="button" on:click={() => prepareTransferPlan(transferAmount)}
							disabled={autoTransferSaving || scheduleSaving || !transferAmount}
							class="rounded bg-blue-600 px-3 py-1 text-white disabled:opacity-50">Apply</button>
					</label>
					<span>Selected: {selectedItems.length}</span>
					<span class="font-semibold text-blue-700">Selected total: {formatAmount(selectedTotal)} SAR</span>
					{#if selectedItems.length > 0 && !transferPlan}
						<button type="button" on:click={addToSchedule} disabled={splitSaving || !!approvingKey || scheduleSaving} class="rounded bg-blue-600 px-3 py-1 text-sm text-white disabled:opacity-50">{scheduleSaving ? 'Adding…' : 'Add to Schedule'}</button>
					{/if}
				</div>
				{#if transferError}<p role="alert" class="mb-2 text-sm text-red-600">{transferError}</p>{/if}
				{#if transferPlan}
					<div class="mb-2 rounded border border-blue-200 bg-blue-50 p-2 text-sm">
						<p class="font-semibold text-slate-800">Prepare {formatAmount(transferPlan.targetAmount)} SAR for {formatBillDate(selectedScheduleDate)}?</p>
						<p class="mt-1 text-slate-600">
							{transferPlan.fullItems.length} full {transferPlan.fullItems.length === 1 ? 'record' : 'records'}: {formatAmount(transferPlan.fullTotal)} SAR.
							{#if transferPlan.partialItem}
								Split {formatAmount(transferPlan.partialAmount)} SAR from
								{transferPlan.partialItem.bill_number || transferPlan.partialItem.requisition_number || `EXP-${transferPlan.partialItem.id}`};
								the remaining {formatAmount(transferPlan.partialItem.amount - transferPlan.partialAmount)} SAR stays on the original record.
							{:else}
								No split is required.
							{/if}
						</p>
						<div class="mt-2 flex gap-2">
							<button type="button" on:click={confirmTransferPlan} disabled={autoTransferSaving} class="rounded bg-green-600 px-3 py-1 text-white disabled:opacity-50">{autoTransferSaving ? 'Processing…' : 'Yes'}</button>
							<button type="button" disabled={autoTransferSaving} on:click={() => { transferPlan = null; transferAmount = ''; selectedItemKeys = new Set(); }} class="rounded border border-slate-300 bg-white px-3 py-1">Cancel</button>
						</div>
					</div>
				{/if}
				{#if scheduleMessage}<p role="status" class="mb-2 text-xs text-slate-600">{scheduleMessage}</p>{/if}
				<div class="overflow-x-auto rounded-md border border-slate-200">
					<table class="w-full text-left text-sm">
						<thead class="bg-slate-50 text-slate-600">
							<tr>
								<th class="px-2 py-2"><input type="checkbox" aria-label="Select all bills and expenses" checked={allItemsSelected} disabled={unpaidItems.length === 0} on:change={(event) => toggleAllItems(event.currentTarget.checked)} /></th>
								{#each ['Type', 'Branch location', 'Bill number', 'Bill date', 'Payment method', 'Approval status'] as heading}
									<th class="whitespace-nowrap px-3 py-3 font-medium">{heading}</th>
								{/each}
								<th class="px-3 py-3 text-right font-medium">Amount (SAR)</th>
							</tr>
						</thead>
						<tbody>
							{#each unpaidItems as item (item.key)}
								{@const dueStatus = getDueStatus(item.due_date)}
								<tr class="border-t border-slate-200">
									<td class="px-2 py-2"><input type="checkbox" aria-label={`Select ${item.type} ${item.bill_number || item.requisition_number || item.id}`} checked={selectedItemKeys.has(item.key)} disabled={scheduledItemKeys.has(item.key)} title={scheduledItemKeys.has(item.key) ? 'Already scheduled for this date' : ''} on:change={(event) => toggleItemSelection(item.key, event.currentTarget.checked)} /></td>
									<td class="px-3 py-3">{item.type}</td>
									<td class="px-3 py-3">{item.branch_location}</td>
									<td class="px-3 py-3">
										<span class="block">{item.bill_number || item.requisition_number || (item.type === 'Expense' ? `EXP-${item.id}` : '—')}</span>
										{#if item.description}
											<span class="block break-words text-xs text-slate-500">{item.description}</span>
										{/if}
									</td>
									<td class="whitespace-nowrap px-3 py-3">
										{#if item.bill_date}
											{formatBillDate(item.bill_date)}
										{:else if item.type === 'Expense' && item.created_at}
											{formatEntryDate(item.created_at)}
											<span class="text-xs text-slate-500">(Entered)</span>
										{:else}
											—
										{/if}
										<span class="block text-xs {dueStatus.color}">{dueStatus.label}</span>
									</td>
									<td class="px-3 py-3">{item.payment_method || '—'}</td>
									<td class="px-3 py-3">
										<span class="block">{item.status || '—'}</span>
										{#if item.status === 'pending' || item.status === 'sent_for_approval'}
											<button type="button" on:click={() => approveItem(item)}
												disabled={!!approvingKey || splitSaving || !!approvalBlockedReason(item, approvalPermissions, $currentUser)}
												title={approvalBlockedReason(item, approvalPermissions, $currentUser) || 'Approve this record'}
												class="mt-1 rounded border border-green-300 px-2 py-1 text-xs text-green-700 disabled:opacity-50">
												{approvingKey === item.key ? 'Approving…' : 'Approve'}
											</button>
										{/if}
									</td>
									<td class="whitespace-nowrap px-3 py-3 text-right">{formatAmount(item.amount)}</td>
								</tr>
							{:else}
								<tr><td colspan="8" class="px-3 py-6 text-center text-slate-500">No unpaid bills or expenses found for this vendor.</td></tr>
							{/each}
						</tbody>
						<tfoot class="border-t border-slate-200 bg-slate-50 font-semibold">
							<tr><td colspan="7" class="px-3 py-3">Total ({unpaidItems.length} records)</td><td class="whitespace-nowrap px-3 py-3 text-right">{formatAmount(unpaidTotal)}</td></tr>
						</tfoot>
					</table>
				</div>
			{/if}
		</div>
	{:else}
		<p class="mt-2 text-sm text-slate-500">Select a vendor to view unpaid bills and expenses across all branches.</p>
	{/if}
	</section>
	<section aria-label="Payment planning" class="h-full w-1/2 min-w-0 overflow-auto p-2">
		<div class="mb-2 flex flex-wrap items-center justify-between gap-2">
			<h2 class="text-sm font-semibold text-slate-800">Payment Schedule</h2>
			<span class="text-sm font-semibold text-blue-700">Total: {formatAmount(scheduleTotal)} SAR</span>
		</div>
		<p class="mb-2 text-xs text-slate-500">Schedule for {formatBillDate(selectedScheduleDate)}. Saved records reload when this window is reopened.</p>
		{#if scheduleError}
			<p role="alert" class="mb-2 text-sm text-red-600">{scheduleError}</p>
		{/if}
		{#if scheduleMessage}
			<p role="status" class="mb-2 text-sm text-green-700">{scheduleMessage}</p>
		{/if}
		{#if scheduleLoading}
			<p class="text-sm text-slate-500">Loading schedule…</p>
		{:else if draftSchedules.length > 0}
			<div class="overflow-x-auto rounded border border-slate-200">
				<table class="w-full text-left text-sm">
					<thead class="bg-slate-100 text-xs text-slate-600">
						<tr>
							<th class="w-10 text-center">Details</th>
							<th>Vendor</th>
							<th>Branch &amp; Bank</th>
							<th class="text-center">Records</th>
							<th class="text-right">Amount (SAR)</th>
							<th class="text-center">Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each draftSchedules as schedule (schedule.key)}
							<tr class="border-t border-slate-200">
								<td class="text-center"><button type="button" on:click={() => toggleScheduleDetails(schedule)} class="w-6 rounded border border-slate-300" aria-label="Toggle schedule details">{expandedScheduleKeys.has(schedule.key) ? '−' : '+'}</button></td>
								<td class="font-semibold text-slate-800">{schedule.vendorName}</td>
								<td>
									<button type="button" on:click={() => openBranchBankPopup(schedule)} disabled={branchSavingKey === schedule.key || scheduleSaving}
										class="w-full min-w-40 rounded border border-slate-300 bg-white px-2 py-1 text-left text-xs disabled:opacity-50">
										<span class="block">{getPaymentBranchLabel(schedule.paidFromBranchId)}</span>
										<span class="block text-[10px] text-slate-500">{schedule.bankLedgerName || 'Bank not selected'}</span>
									</button>
								</td>
								<td class="text-center">{schedule.items.length}</td>
								<td class="whitespace-nowrap text-right font-semibold text-blue-700">{formatAmount(schedule.items.reduce((sum, item) => sum + item.amount, 0))}</td>
								<td class="text-center">
									<div class="flex flex-col items-center gap-1">
										<button type="button" on:click={() => postScheduleTasks(schedule)}
											disabled={postingScheduleKey === schedule.key || !!postingScheduleKey || !!plannerTasksByVendor[schedule.vendorId]?.length || !schedule.paidFromBranchId || !schedule.bankLedgerName}
											class="rounded border border-blue-300 bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 disabled:opacity-50">
											{postingScheduleKey === schedule.key ? 'Postingâ€¦' : plannerTasksByVendor[schedule.vendorId]?.length ? 'âœ“ Task Sent' : 'Post Task'}
										</button>
										<button type="button" on:click={() => removeScheduledVendor(schedule)} disabled={scheduleSaving || !!plannerTasksByVendor[schedule.vendorId]?.length} class="rounded border border-slate-300 px-2 py-1 text-xs text-slate-600 disabled:opacity-50">Remove</button>
									</div>
								</td>
							</tr>
							{#if expandedScheduleKeys.has(schedule.key)}
								<tr class="border-t border-slate-200 bg-slate-50">
									<td colspan="6" class="p-2">
										<table class="w-full text-left text-xs">
											<thead class="bg-white text-slate-600"><tr>
												<th>Type</th><th>Branch location</th><th>Bill number</th><th>Bill date</th><th>Approval status</th><th class="text-right">Amount (SAR)</th>
											</tr></thead>
											<tbody>
												{#each schedule.items as item (item.key)}
													<tr class="border-t border-slate-200">
														<td>{item.type}</td><td>{item.branch_location}</td>
														<td><span class="block">{item.bill_number || item.requisition_number || `EXP-${item.id}`}</span>{#if item.description}<span class="block text-slate-500">{item.description}</span>{/if}</td>
														<td class="whitespace-nowrap">{item.bill_date ? formatBillDate(item.bill_date) : formatEntryDate(item.created_at)}</td>
														<td>{item.status}</td><td class="whitespace-nowrap text-right">{formatAmount(item.amount)}</td>
													</tr>
												{/each}
											</tbody>
										</table>
										<div class="mt-2">
											<div class="mb-1 flex items-center justify-between">
												<h3 class="text-xs font-semibold text-slate-700">Planned ERP Entries</h3>
												<span class="rounded bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-700">Preview only — not posted</span>
											</div>
											{#if bpPreviewLoading.has(schedule.key)}
												<p class="rounded border border-slate-200 bg-white px-3 py-2 text-xs text-slate-500">Loading the vendor ledger from the paying branch SQL Server…</p>
											{:else if bpPreviewErrors[schedule.key]}
												<p class="rounded border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">{bpPreviewErrors[schedule.key]}</p>
											{:else if bpPreviews[schedule.key]}
												<table class="w-full text-left text-xs">
													<thead class="bg-blue-50 text-slate-600"><tr>
										<th>Entry</th><th>Posting branch</th><th>Debit ledger</th><th>Credit ledger</th><th class="text-right">Amount (SAR)</th><th>Narration</th><th>Status</th>
													</tr></thead>
									<tbody>
										{#each bpPreviews[schedule.key] as preview (preview.entry)}
											<tr class="border-t border-slate-200 bg-white">
												<td class="whitespace-nowrap font-semibold text-blue-700">{preview.entry}</td>
												<td>{preview.postingBranch}</td>
												<td><span class="block font-medium">{preview.debitLedger.name}</span><span class="text-[10px] text-slate-500">{preview.debitLedger.code ? `Code ${preview.debitLedger.code}` : `Ledger ${preview.debitLedger.id}`}</span></td>
												<td><span class="block font-medium">{preview.creditLedger.name}</span><span class="text-[10px] text-slate-500">{preview.creditLedger.code ? `Code ${preview.creditLedger.code}` : `Ledger ${preview.creditLedger.id}`}</span></td>
												<td class="whitespace-nowrap text-right font-semibold">{formatAmount(preview.amount)}</td>
												<td>{preview.narration}</td>
												<td><span class="rounded bg-slate-100 px-2 py-1 text-[10px] text-slate-600">Planned</span></td>
											</tr>
										{/each}
									</tbody>
												</table>
											{/if}
										</div>
									</td>
								</tr>
							{/if}
						{/each}
					</tbody>
					<tfoot class="border-t border-slate-300 bg-slate-100 font-semibold">
						<tr><td colspan="3">Schedule total</td><td class="text-center">{draftSchedules.reduce((sum, schedule) => sum + schedule.items.length, 0)}</td><td class="text-right">{formatAmount(scheduleTotal)}</td><td></td></tr>
					</tfoot>
				</table>
			</div>
		{:else}
			<p class="text-sm text-slate-500">Select records on the left and click Add to Schedule.</p>
		{/if}
	</section>
	{#if branchBankSchedule}
		<div class="absolute inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4" role="presentation" on:click={() => { if (!branchSavingKey) branchBankSchedule = null; }}>
			<div role="dialog" aria-modal="true" aria-labelledby="branch-bank-title" class="w-full max-w-md rounded-lg bg-white p-4 shadow-xl" on:click|stopPropagation>
				<h3 id="branch-bank-title" class="text-base font-semibold text-slate-800">Branch &amp; Bank</h3>
				<p class="mt-1 text-xs text-slate-500">{branchBankSchedule.vendorName}</p>
				<label class="mt-4 block text-sm font-medium text-slate-700">
					Paying branch
					<select value={branchBankSelection} on:change={(event) => changePopupBranch(event.currentTarget.value)} disabled={!!branchSavingKey || loadingBankLedgers} class="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 disabled:opacity-50">
						<option value="">Select branch</option>
						{#each paymentBranches as branch}
							<option value={String(branch.id)}>{branch.name_en}{branch.location_en ? ` - ${branch.location_en}` : ''}</option>
						{/each}
					</select>
				</label>
				<label class="mt-3 block text-sm font-medium text-slate-700">
					Bank ledger
					<input type="search" bind:value={bankLedgerSearch} on:input={() => selectedBankLedgerId = null}
						disabled={!branchBankSelection || loadingBankLedgers || !!branchSavingKey}
						placeholder={branchBankSelection ? 'Search and select bank ledger' : 'Select a branch first'}
						class="mt-1 w-full rounded border border-slate-300 px-3 py-2 disabled:bg-slate-100 disabled:opacity-70" />
				</label>
				{#if loadingBankLedgers}
					<p class="mt-2 text-xs text-slate-500">Loading bank ledgers from the branch SQL Server…</p>
				{:else if bankLedgerError}
					<p class="mt-2 rounded border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">{bankLedgerError}</p>
				{:else if branchBankSelection}
					<div class="mt-2 max-h-52 overflow-y-auto rounded border border-slate-200" role="listbox" aria-label="Bank ledgers">
						{#each filteredBankLedgers as ledger (ledger.ledgerId)}
							<button type="button" on:click={() => selectBankLedger(ledger)} disabled={!!branchSavingKey}
								class="block w-full border-b border-slate-100 px-3 py-2 text-left last:border-b-0 hover:bg-blue-50 disabled:opacity-50"
								class:bg-blue-100={selectedBankLedgerId === ledger.ledgerId}
								role="option" aria-selected={selectedBankLedgerId === ledger.ledgerId}>
								<span class="block text-sm font-medium text-slate-800">{ledger.ledgerName}</span>
								<span class="block text-xs text-slate-500">{ledger.groupName || 'Bank'} · Ledger {ledger.ledgerId}</span>
							</button>
						{:else}
							<p class="px-3 py-3 text-xs text-slate-500">No bank ledgers found.</p>
						{/each}
					</div>
				{/if}
				<div class="mt-4 flex justify-end gap-2">
					<button type="button" on:click={() => branchBankSchedule = null} disabled={!!branchSavingKey} class="rounded border border-slate-300 px-3 py-2 text-sm disabled:opacity-50">Cancel</button>
					<button type="button" on:click={saveBranchBankPopup} disabled={!branchBankSelection || selectedBankLedgerId == null || loadingBankLedgers || !!branchSavingKey} class="rounded bg-blue-600 px-3 py-2 text-sm text-white disabled:opacity-50">{branchSavingKey ? 'Saving…' : 'Save'}</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.transfer-amount-input::-webkit-inner-spin-button,
	.transfer-amount-input::-webkit-outer-spin-button {
		margin: 0;
		appearance: none;
	}

	.transfer-amount-input {
		-moz-appearance: textfield;
	}

	th,
	td {
		border-right: 1px solid #e2e8f0;
		padding: 6px 8px;
	}

	th:last-child,
	td:last-child {
		border-right: none;
	}
</style>
