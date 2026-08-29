<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let loading = true;
	let vendors: Array<{ vendor_id: string; vendor_name: string }> = [];
	let selectedVendorId = '';
	let selectedVendorName = '';
	let payments: any[] = [];
	let vendorExpenses: any[] = [];
	let loadingPayments = false;
	let searchQuery = '';
	let loadingProgress = 0;
	let branches: Array<{ id: number; name_en: string; name_ar: string; location_en?: string }> = [];
	let selectedBranchId = '';
	let selectedPaymentMethod = '';
	let paymentMethods: string[] = [];
	let paidFilter: 'all' | 'paid' | 'unpaid' = 'unpaid';
	let dueInFilter: 'all' | '7' | '15' | '30' = 'all';
	let highlightedIndex = -1;
	let searchInputEl: HTMLInputElement;
	let totalVendorCount = 0;
	let totalUnpaidAmount = 0;
	let totalUnpaidExpenseAmount = 0;
	let globalTotalPaid = 0;
	let globalTotalUnpaid = 0;
	let globalGrandTotal = 0;
	let vendorUnpaidMap: Map<string, number> = new Map();
	let vendorBillsUnpaidMap: Map<string, number> = new Map();
	let vendorExpensesUnpaidMap: Map<string, number> = new Map();
	let vendorBillsOverdueMap: Map<string, number> = new Map();
	let vendorExpensesOverdueMap: Map<string, number> = new Map();
	let vendorTotalOverdueMap: Map<string, number> = new Map();
	let vendorMaxDaysOverdueMap: Map<string, number> = new Map();

	function formatCompactAmount(amount: number): string {
		const locale = $currentLocale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-SA';
		const absoluteAmount = Math.abs(amount);
		const format = (value: number) => new Intl.NumberFormat(locale, { maximumFractionDigits: 3 }).format(value);

		if (absoluteAmount >= 1_000_000) {
			return `${format(amount / 1_000_000)}${$currentLocale === 'ar' ? ' مليون' : 'M'}`;
		}
		if (absoluteAmount >= 1_000) {
			return `${format(amount / 1_000)}${$currentLocale === 'ar' ? ' ألف' : 'K'}`;
		}
		return new Intl.NumberFormat(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(amount);
	}

	// Raw rows behind the maps above — kept so the branch filter can be applied
	// client-side (recomputed reactively) without re-querying Supabase.
	let rawBillsUnpaid: Array<{ vendor_id: any; final_bill_amount: number; branch_id: any }> = [];
	let rawExpensesUnpaid: Array<{ vendor_id: any; amount: number; branch_id: any }> = [];
	let rawBillsOverdue: Array<{ vendor_id: any; final_bill_amount: number; due_date: string; branch_id: any }> = [];
	let rawExpensesOverdue: Array<{ vendor_id: any; amount: number; due_date: string; branch_id: any }> = [];

	// Main window tab state
	let activeTab: 'account' | 'summary' = 'account';

	// Vendor table (Account tab)
	let vendorTableSearch = '';
	let vendorTableLimit = 50;

	// ERP balance per vendor (vendor_id -> { netBalance, direction })
	let erpBalancesLoading = false;
	let erpBalancesLoaded = false;
	let erpFailedBranches: string[] = []; // branch names that failed
	let erpBranchResults: Array<{ branch_id: number | null; rows: any[] }> = [];
	let selectedErpBranchId = ''; // '' = all branches (list view balance filter)

	async function loadAllErpBalances() {
		erpBalancesLoading = true;
		erpBranchResults = [];
		erpFailedBranches = [];
		try {
			const { data: conns } = await supabase
				.from('erp_connections')
				.select('branch_id, branch_name, tunnel_url, erp_branch_id')
				.eq('is_active', true);
			if (!conns || conns.length === 0) { erpBalancesLoading = false; return; }

			// One query per branch — get ALL supplier balances at once
			const branchResults = await Promise.all(conns.map(async (conn: any) => {
				try {
					const erpBranchId = conn.erp_branch_id ? parseInt(conn.erp_branch_id) : null;
					const branchFilter = erpBranchId ? `AND p.BranchID = ${erpBranchId}` : '';
					const sql = `SELECT p.PartyCode, SUM(d.Debit) as TotalDebit, SUM(d.Credit) as TotalCredit, SUM(d.Debit-d.Credit) as NetBalance FROM Parties p JOIN AccLedgers l ON l.LedgerCode=p.PartyCode AND l.BranchID=p.BranchID JOIN AccTransactionMaster m ON m.BranchID=l.BranchID JOIN AccTransactionDetails d ON d.AccTransactionMasterID=m.AccTransactionMasterID AND d.BranchID=m.BranchID AND d.LedgerID=l.LedgerID WHERE p.PartyType='Supp' ${branchFilter} AND m.IsActive='True' GROUP BY p.PartyCode`;
					const resp = await fetch('/api/erp-products', {
						method: 'POST',
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify({ action: 'query', tunnelUrl: conn.tunnel_url, sql })
					});
					const data = await resp.json();
					if (!data.success) return { branch_id: conn.branch_id, rows: [], failed: conn.branch_name };
					return { branch_id: conn.branch_id, rows: data.recordset || [], failed: null };
				} catch (_) {
					return { branch_id: conn.branch_id, rows: [], failed: conn.branch_name };
				}
			}));

			const failed: string[] = [];
			for (const result of branchResults) {
				if (result.failed) failed.push(result.failed);
			}
			erpFailedBranches = failed;
			erpBranchResults = branchResults.map(r => ({ branch_id: r.branch_id, rows: r.rows }));
			erpBalancesLoaded = true;
		} catch (_) {}
		erpBalancesLoading = false;
	}

	// Sum ERP balances per PartyCode, restricted to the selected branch (or all branches if none selected)
	$: erpBalanceMap = (() => {
		const totals: Map<string, { debit: number; credit: number }> = new Map();
		for (const result of erpBranchResults) {
			if (selectedErpBranchId && String(result.branch_id) !== selectedErpBranchId) continue;
			for (const row of result.rows) {
				const code = String(row.PartyCode);
				const existing = totals.get(code) || { debit: 0, credit: 0 };
				totals.set(code, {
					debit: existing.debit + (parseFloat(row.TotalDebit) || 0),
					credit: existing.credit + (parseFloat(row.TotalCredit) || 0)
				});
			}
		}
		const newMap = new Map<string, { netBalance: number; direction: string }>();
		totals.forEach((v, code) => {
			const net = v.debit - v.credit;
			newMap.set(code, { netBalance: Math.abs(net), direction: net > 0 ? 'Dr' : net < 0 ? 'Cr' : 'Nil' });
		});
		return newMap;
	})();

	// Derive the vendor-table maps (Bills/Expenses Unpaid & Overdue) from the raw rows,
	// restricted to the selected branch — keeps every column in sync with the ERP Balance filter.
	$: {
		const billsUnpaidMap: Map<string, number> = new Map();
		const expensesUnpaidMap: Map<string, number> = new Map();
		const billsOverdueMap: Map<string, number> = new Map();
		const expensesOverdueMap: Map<string, number> = new Map();
		const maxDaysOverdueMap: Map<string, number> = new Map();
		const todayMs = new Date().setHours(0, 0, 0, 0);
		const branchMatches = (bid: any) => !selectedErpBranchId || String(bid) === selectedErpBranchId;

		for (const item of rawBillsUnpaid) {
			if (!item.vendor_id || !branchMatches(item.branch_id)) continue;
			const vid = item.vendor_id.toString();
			billsUnpaidMap.set(vid, (billsUnpaidMap.get(vid) || 0) + (item.final_bill_amount || 0));
		}
		for (const item of rawExpensesUnpaid) {
			if (!item.vendor_id || !branchMatches(item.branch_id)) continue;
			const vid = item.vendor_id.toString();
			expensesUnpaidMap.set(vid, (expensesUnpaidMap.get(vid) || 0) + (item.amount || 0));
		}
		for (const item of rawBillsOverdue) {
			if (!item.vendor_id || !branchMatches(item.branch_id)) continue;
			const vid = item.vendor_id.toString();
			billsOverdueMap.set(vid, (billsOverdueMap.get(vid) || 0) + (item.final_bill_amount || 0));
			const days = Math.floor((todayMs - new Date(item.due_date).getTime()) / 86400000);
			if (days > (maxDaysOverdueMap.get(vid) || 0)) maxDaysOverdueMap.set(vid, days);
		}
		for (const item of rawExpensesOverdue) {
			if (!item.vendor_id || !branchMatches(item.branch_id)) continue;
			const vid = item.vendor_id.toString();
			expensesOverdueMap.set(vid, (expensesOverdueMap.get(vid) || 0) + (item.amount || 0));
			const days = Math.floor((todayMs - new Date(item.due_date).getTime()) / 86400000);
			if (days > (maxDaysOverdueMap.get(vid) || 0)) maxDaysOverdueMap.set(vid, days);
		}

		const unpaidMap: Map<string, number> = new Map();
		const allIds = new Set([...billsUnpaidMap.keys(), ...expensesUnpaidMap.keys()]);
		for (const vid of allIds) {
			unpaidMap.set(vid, (billsUnpaidMap.get(vid) || 0) + (expensesUnpaidMap.get(vid) || 0));
		}
		const totalOverdueMap: Map<string, number> = new Map();
		const allOverdueIds = new Set([...billsOverdueMap.keys(), ...expensesOverdueMap.keys()]);
		for (const vid of allOverdueIds) {
			totalOverdueMap.set(vid, (billsOverdueMap.get(vid) || 0) + (expensesOverdueMap.get(vid) || 0));
		}

		vendorBillsUnpaidMap = billsUnpaidMap;
		vendorExpensesUnpaidMap = expensesUnpaidMap;
		vendorUnpaidMap = unpaidMap;
		vendorBillsOverdueMap = billsOverdueMap;
		vendorExpensesOverdueMap = expensesOverdueMap;
		vendorTotalOverdueMap = totalOverdueMap;
		vendorMaxDaysOverdueMap = maxDaysOverdueMap;
	}

	// Pagination (detail view)
	let currentPage = 1;
	let pageSize = 10;

	// Edit Modal
	let showEditModal = false;
	let editingPayment: any = null;
	let editFormData = {
		due_date: '',
		branch_id: '',
		payment_method: ''
	};
	let savingEdit = false;

	// Checkboxes — payments
	let checkedPaymentIds: Set<string> = new Set();

	// Checkboxes — expenses
	let checkedExpenseIds: Set<string> = new Set();

	// Vendor table reactives
	$: filteredTableVendors = vendors
		.filter(v =>
			v.vendor_name.toLowerCase().includes(vendorTableSearch.toLowerCase()) ||
			v.vendor_id.toLowerCase().includes(vendorTableSearch.toLowerCase())
		)
		.sort((a, b) => (vendorMaxDaysOverdueMap.get(b.vendor_id) || 0) - (vendorMaxDaysOverdueMap.get(a.vendor_id) || 0));
	$: visibleTableVendors = filteredTableVendors.slice(0, vendorTableLimit);

	// Totals row (based on all filtered vendors, not just visible)
	// Reference maps directly so Svelte re-runs when maps are reassigned after load
	$: tableTotalBillsUnpaid = filteredTableVendors.reduce((sum, v) => sum + (vendorBillsUnpaidMap.get(v.vendor_id) || 0), 0);
	$: tableTotalExpensesUnpaid = filteredTableVendors.reduce((sum, v) => sum + (vendorExpensesUnpaidMap.get(v.vendor_id) || 0), 0);
	$: tableTotalUnpaid = filteredTableVendors.reduce((sum, v) => sum + (vendorUnpaidMap.get(v.vendor_id) || 0), 0);
	$: tableTotalOverdue = filteredTableVendors.reduce((sum, v) => sum + (vendorTotalOverdueMap.get(v.vendor_id) || 0), 0);

	// Legacy search (kept for keyboard handler compat)
	$: filteredVendors = vendors.filter(v =>
		v.vendor_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
		v.vendor_id.toLowerCase().includes(searchQuery.toLowerCase())
	);
	$: if (searchQuery || filteredVendors) highlightedIndex = -1;

	// Filtered payments
	$: filteredPayments = payments.filter(payment => {
		const branchMatch = !selectedBranchId || payment.branch_id?.toString() === selectedBranchId;
		const methodMatch = !selectedPaymentMethod || payment.payment_method === selectedPaymentMethod;
		const paidMatch = paidFilter === 'all' || (paidFilter === 'paid' ? payment.is_paid : !payment.is_paid);

		let dueMatch = true;
		if (dueInFilter !== 'all' && payment.due_date && !payment.is_paid) {
			const dueDate = new Date(payment.due_date);
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			const diffTime = dueDate.getTime() - today.getTime();
			const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			dueMatch = diffDays <= parseInt(dueInFilter) && diffDays >= 0;
		}
		return branchMatch && methodMatch && paidMatch && dueMatch;
	});

	// Pagination
	$: totalRecords = filteredPayments.length;
	$: totalPages = Math.ceil(totalRecords / pageSize);
	$: startRecord = (currentPage - 1) * pageSize + 1;
	$: endRecord = Math.min(currentPage * pageSize, totalRecords);
	$: paginatedPayments = filteredPayments.slice((currentPage - 1) * pageSize, currentPage * pageSize);
	$: if (currentPage > totalPages && totalPages > 0) currentPage = 1;

	// Clear checkboxes when vendor or filters change
	$: if (selectedVendorId || paidFilter || selectedBranchId || selectedPaymentMethod) {
		checkedPaymentIds = new Set();
		checkedExpenseIds = new Set();
	}

	$: checkedCount = checkedPaymentIds.size;
	$: checkedTotal = filteredPayments
		.filter(p => checkedPaymentIds.has(String(p.id)))
		.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0);
	$: allPageChecked = paginatedPayments.length > 0 && paginatedPayments.every(p => checkedPaymentIds.has(String(p.id)));

	$: checkedExpenseCount = checkedExpenseIds.size;
	$: checkedExpenseTotal = filteredVendorExpenses
		.filter(e => checkedExpenseIds.has(String(e.id)))
		.reduce((sum, e) => sum + (e.amount || 0), 0);
	$: allExpensesChecked = filteredVendorExpenses.length > 0 && filteredVendorExpenses.every(e => checkedExpenseIds.has(String(e.id)));

	$: combinedCheckedCount = checkedCount + checkedExpenseCount;
	$: combinedCheckedTotal = checkedTotal + checkedExpenseTotal;

	$: totalAmount = filteredPayments.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0);

	$: filteredVendorExpenses = vendorExpenses.filter(exp => {
		const branchMatch = !selectedBranchId || exp.branch_id?.toString() === selectedBranchId;
		const methodMatch = !selectedPaymentMethod || exp.payment_method === selectedPaymentMethod;
		const paidMatch = paidFilter === 'all' || (paidFilter === 'paid' ? exp.is_paid : !exp.is_paid);

		let dueMatch = true;
		if (dueInFilter !== 'all' && exp.due_date && !exp.is_paid) {
			const dueDate = new Date(exp.due_date);
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			const diffTime = dueDate.getTime() - today.getTime();
			const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			dueMatch = diffDays <= parseInt(dueInFilter) && diffDays >= 0;
		}
		return branchMatch && methodMatch && paidMatch && dueMatch;
	});

	$: totalExpenseAmount = filteredVendorExpenses.reduce((sum, e) => sum + (e.amount || 0), 0);

	$: allPaymentsBranch = payments.filter(p => {
		const branchMatch = !selectedBranchId || p.branch_id?.toString() === selectedBranchId;
		const methodMatch = !selectedPaymentMethod || p.payment_method === selectedPaymentMethod;
		return branchMatch && methodMatch;
	});
	$: allExpensesBranch = vendorExpenses.filter(e => {
		const branchMatch = !selectedBranchId || e.branch_id?.toString() === selectedBranchId;
		const methodMatch = !selectedPaymentMethod || e.payment_method === selectedPaymentMethod;
		return branchMatch && methodMatch;
	});

	$: summaryTotalPaid = allPaymentsBranch.filter(p => p.is_paid).reduce((s, p) => s + (p.final_bill_amount || 0), 0)
		+ allExpensesBranch.filter(e => e.is_paid).reduce((s, e) => s + (e.amount || 0), 0);
	$: summaryTotalUnpaid = allPaymentsBranch.filter(p => !p.is_paid).reduce((s, p) => s + (p.final_bill_amount || 0), 0)
		+ allExpensesBranch.filter(e => !e.is_paid).reduce((s, e) => s + (e.amount || 0), 0);
	$: summaryGrandTotal = summaryTotalPaid + summaryTotalUnpaid;

	onMount(async () => {
		await Promise.all([loadInitialData(), loadBranches()]);
		loading = false;
		await tick();
		loadAllErpBalances();
	});

	async function loadInitialData() {
		try {
			const { data, error } = await supabase.rpc('get_vendor_pending_summary');
			if (error) throw error;

			globalTotalPaid = data.global_total_paid || 0;
			globalTotalUnpaid = data.global_total_unpaid || 0;
			globalGrandTotal = data.global_grand_total || 0;
			totalVendorCount = data.total_vendor_count || 0;
			vendors = data.vendors || [];
			paymentMethods = data.payment_methods || [];

			await loadVendorsWithUnpaidBalances();

			console.log('✅ Vendors loaded from RPC:', vendors.length, 'vendors');
		} catch (error) {
			console.error('Error loading initial data:', error);
			await Promise.all([loadVendorsFallback(), loadSummaryFallback(), loadAllPaymentMethodsFallback()]);
		}
	}

	async function loadAllPaymentMethodsFallback() {
		try {
			const [vpsResult, expResult] = await Promise.all([
				supabase.from('vendor_payment_schedule').select('payment_method').not('payment_method', 'is', null),
				supabase.from('expense_scheduler').select('payment_method').not('payment_method', 'is', null).not('vendor_id', 'is', null)
			]);
			const methods = new Set<string>();
			vpsResult.data?.forEach(item => { if (item.payment_method) methods.add(item.payment_method); });
			expResult.data?.forEach(item => { if (item.payment_method) methods.add(item.payment_method); });
			paymentMethods = Array.from(methods).sort();
		} catch (error) {
			console.error('Error loading payment methods:', error);
		}
	}

	async function loadSummaryFallback() {
		try {
			const [paymentResult, expenseResult] = await Promise.all([
				supabase.from('vendor_payment_schedule').select('vendor_id, final_bill_amount, is_paid'),
				supabase.from('expense_scheduler').select('vendor_id, amount, is_paid').not('vendor_id', 'is', null)
			]);
			if (paymentResult.error) throw paymentResult.error;

			const uniqueVendors = new Set(paymentResult.data?.map(item => item.vendor_id));
			if (expenseResult.data) expenseResult.data.forEach(item => uniqueVendors.add(item.vendor_id?.toString()));
			totalVendorCount = uniqueVendors.size;

			const vpsPaid   = paymentResult.data?.filter(i => i.is_paid).reduce((s, i) => s + (i.final_bill_amount || 0), 0) || 0;
			const vpsUnpaid = paymentResult.data?.filter(i => !i.is_paid).reduce((s, i) => s + (i.final_bill_amount || 0), 0) || 0;
			const expPaid   = expenseResult.data?.filter(i => i.is_paid).reduce((s, i) => s + (i.amount || 0), 0) || 0;
			const expUnpaid = expenseResult.data?.filter(i => !i.is_paid).reduce((s, i) => s + (i.amount || 0), 0) || 0;

			globalTotalPaid = vpsPaid + expPaid;
			globalTotalUnpaid = vpsUnpaid + expUnpaid;
			globalGrandTotal = globalTotalPaid + globalTotalUnpaid;
			totalUnpaidAmount = vpsUnpaid;
			totalUnpaidExpenseAmount = expUnpaid;
		} catch (error) {
			console.error('Error loading summary:', error);
		}
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase.from('branches').select('id, name_en, name_ar, location_en').eq('is_active', true).order('name_en');
			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
			branches = [];
		}
	}

	async function loadVendorsFallback() {
		try {
			const pageSize = 500;
			let page = 0;
			let hasMore = true;
			const vendorMap = new Map();
			let totalLoaded = 0;

			const { data: expenseVendors } = await supabase.from('expense_scheduler').select('vendor_id, vendor_name').not('vendor_id', 'is', null);
			if (expenseVendors) {
				for (const item of expenseVendors) {
					if (item.vendor_id && item.vendor_name) {
						const vid = item.vendor_id.toString();
						if (!vendorMap.has(vid)) vendorMap.set(vid, { vendor_id: vid, vendor_name: item.vendor_name });
					}
				}
			}

			while (hasMore) {
				const from = page * pageSize;
				const to = from + pageSize - 1;
				const { data, error, count } = await supabase
					.from('vendor_payment_schedule')
					.select('vendor_id, vendor_name', { count: 'exact' })
					.range(from, to);
				if (error) throw error;
				if (!data || data.length === 0) { hasMore = false; break; }

				for (const item of data) {
					if (item.vendor_id && item.vendor_name && !vendorMap.has(item.vendor_id))
						vendorMap.set(item.vendor_id, { vendor_id: item.vendor_id, vendor_name: item.vendor_name });
				}
				totalLoaded += data.length;
				if (count) loadingProgress = Math.round((totalLoaded / count) * 100);
				hasMore = data.length === pageSize;
				page++;
				vendors = Array.from(vendorMap.values()).sort((a, b) => a.vendor_name.localeCompare(b.vendor_name));
			}
			loadingProgress = 100;
		} catch (error) {
			console.error('Error loading vendors:', error);
			vendors = [];
		}
	}

	async function handleVendorSelect(vendorId: string, vendorName: string) {
		selectedVendorId = vendorId;
		selectedVendorName = vendorName;
		searchQuery = '';
		currentPage = 1;
		await loadPayments();
	}

	async function loadPayments() {
		if (!selectedVendorId) return;
		loadingPayments = true;
		try {
			const vendorIdInt = parseInt(selectedVendorId);
			const [paymentResult, expenseResult] = await Promise.all([
				supabase
					.from('vendor_payment_schedule')
					.select(`*, branches!branch_id (name_en, name_ar)`)
					.eq('vendor_id', selectedVendorId)
					.order('due_date', { ascending: true }),
				!isNaN(vendorIdInt)
					? supabase
						.from('expense_scheduler')
						.select('id, amount, is_paid, paid_date, status, branch_id, branch_name, payment_method, expense_category_name_en, expense_category_name_ar, description, due_date, requisition_number, co_user_name, vendor_name')
						.eq('vendor_id', vendorIdInt)
						.order('due_date', { ascending: true })
					: Promise.resolve({ data: [], error: null })
			]);
			if (paymentResult.error) throw paymentResult.error;
			if (expenseResult.error) console.error('Error loading vendor expenses:', expenseResult.error);
			payments = paymentResult.data || [];
			vendorExpenses = expenseResult.data || [];

			// Sync table cache with real loaded data so Account tab stays consistent
			const realBillsUnpaid = payments.filter(p => !p.is_paid).reduce((s, p) => s + (p.final_bill_amount || 0), 0);
			const realExpensesUnpaid = vendorExpenses.filter(e => !e.is_paid).reduce((s, e) => s + (e.amount || 0), 0);
			vendorBillsUnpaidMap.set(selectedVendorId, realBillsUnpaid);
			vendorExpensesUnpaidMap.set(selectedVendorId, realExpensesUnpaid);
			vendorUnpaidMap.set(selectedVendorId, realBillsUnpaid + realExpensesUnpaid);
			vendorBillsUnpaidMap = vendorBillsUnpaidMap;
			vendorExpensesUnpaidMap = vendorExpensesUnpaidMap;
			vendorUnpaidMap = vendorUnpaidMap;
		} catch (error) {
			console.error('Error loading payments:', error);
			payments = [];
			vendorExpenses = [];
		} finally {
			loadingPayments = false;
		}
	}

	function clearSelection() {
		selectedVendorId = '';
		selectedVendorName = '';
		payments = [];
		vendorExpenses = [];
		searchQuery = '';
		selectedBranchId = '';
		selectedPaymentMethod = '';
		paymentMethods = [];
		currentPage = 1;
		paidFilter = 'unpaid';
	}

	async function loadVendorsWithUnpaidBalances() {
		try {
			// Query both tables directly — the RPC only returns expense-side totals
			const today = new Date().toISOString().split('T')[0];
			const [billsResult, expensesResult, billsOverdueResult, expensesOverdueResult] = await Promise.all([
				supabase
					.from('vendor_payment_schedule')
					.select('vendor_id, final_bill_amount, branch_id')
					.eq('is_paid', false),
				supabase
					.from('expense_scheduler')
					.select('vendor_id, amount, branch_id')
					.eq('is_paid', false)
					.not('vendor_id', 'is', null),
				supabase
					.from('vendor_payment_schedule')
					.select('vendor_id, final_bill_amount, due_date, branch_id')
					.eq('is_paid', false)
					.not('due_date', 'is', null)
					.lt('due_date', today),
				supabase
					.from('expense_scheduler')
					.select('vendor_id, amount, due_date, branch_id')
					.eq('is_paid', false)
					.not('vendor_id', 'is', null)
					.not('due_date', 'is', null)
					.lt('due_date', today)
			]);

			// Keep the raw rows — the maps below are derived reactively so the
			// branch filter can be applied instantly without re-querying.
			rawBillsUnpaid = billsResult.data || [];
			rawExpensesUnpaid = expensesResult.data || [];
			rawBillsOverdue = billsOverdueResult.data || [];
			rawExpensesOverdue = expensesOverdueResult.data || [];
		} catch (error) {
			console.error('❌ Error loading vendor unpaid balances:', error);
		}
	}

	async function loadVendorUnpaidTotal(vendorId: string): Promise<number> {
		console.warn('⚠️ FALLBACK: loadVendorUnpaidTotal() called for', vendorId);
		try {
			if (vendorUnpaidMap.has(vendorId)) return vendorUnpaidMap.get(vendorId) || 0;
			let total = 0;
			const { data: p } = await supabase.from('vendor_payment_schedule').select('final_bill_amount').eq('vendor_id', vendorId).eq('is_paid', false);
			if (p) total += p.reduce((s, x) => s + (x.final_bill_amount || 0), 0);
			const { data: e } = await supabase.from('expense_scheduler').select('amount').eq('vendor_id', vendorId).eq('is_paid', false);
			if (e) total += e.reduce((s, x) => s + (x.amount || 0), 0);
			vendorUnpaidMap.set(vendorId, total);
			return total;
		} catch (error) {
			console.error(`Error loading unpaid total for vendor ${vendorId}:`, error);
			return 0;
		}
	}

	function getVendorTotalUnpaid(vendorId: string): number {
		return vendorUnpaidMap.get(vendorId) || 0;
	}

	function getVendorBillsUnpaid(vendorId: string): number {
		return vendorBillsUnpaidMap.get(vendorId) || 0;
	}

	function getVendorExpensesUnpaid(vendorId: string): number {
		return vendorExpensesUnpaidMap.get(vendorId) || 0;
	}

	function getVendorTotalOverdue(vendorId: string): number {
		return vendorTotalOverdueMap.get(vendorId) || 0;
	}

	function getVendorBillsOverdue(vendorId: string): number {
		return vendorBillsOverdueMap.get(vendorId) || 0;
	}

	function getVendorExpensesOverdue(vendorId: string): number {
		return vendorExpensesOverdueMap.get(vendorId) || 0;
	}

	function handleVendorTableScroll(e: Event) {
		const el = e.currentTarget as HTMLElement;
		if (el.scrollTop + el.clientHeight >= el.scrollHeight - 150) {
			if (vendorTableLimit < filteredTableVendors.length) vendorTableLimit += 50;
		}
	}

	function toggleRow(id: string) {
		if (checkedPaymentIds.has(id)) checkedPaymentIds.delete(id);
		else checkedPaymentIds.add(id);
		checkedPaymentIds = checkedPaymentIds;
	}

	function toggleAllPage() {
		if (allPageChecked) paginatedPayments.forEach(p => checkedPaymentIds.delete(String(p.id)));
		else paginatedPayments.forEach(p => checkedPaymentIds.add(String(p.id)));
		checkedPaymentIds = checkedPaymentIds;
	}

	function toggleExpenseRow(id: string) {
		if (checkedExpenseIds.has(id)) checkedExpenseIds.delete(id);
		else checkedExpenseIds.add(id);
		checkedExpenseIds = checkedExpenseIds;
	}

	function toggleAllExpenses() {
		if (allExpensesChecked) filteredVendorExpenses.forEach(e => checkedExpenseIds.delete(String(e.id)));
		else filteredVendorExpenses.forEach(e => checkedExpenseIds.add(String(e.id)));
		checkedExpenseIds = checkedExpenseIds;
	}

	function openEditModal(payment: any) {
		editingPayment = payment;
		editFormData = {
			due_date: payment.due_date || '',
			branch_id: payment.branch_id?.toString() || '',
			payment_method: payment.payment_method || ''
		};
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		editingPayment = null;
		editFormData = { due_date: '', branch_id: '', payment_method: '' };
	}

	async function saveEdit() {
		if (!editingPayment) return;
		savingEdit = true;
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({
					due_date: editFormData.due_date,
					branch_id: parseInt(editFormData.branch_id),
					payment_method: editFormData.payment_method
				})
				.eq('id', editingPayment.id);
			if (error) throw error;

			payments = payments.map(p =>
				p.id === editingPayment.id
					? { ...p, due_date: editFormData.due_date, branch_id: parseInt(editFormData.branch_id), payment_method: editFormData.payment_method, branches: branches.find(b => b.id.toString() === editFormData.branch_id) }
					: p
			);
			closeEditModal();
			vendorUnpaidMap.clear();
			vendorUnpaidMap = vendorUnpaidMap;
		} catch (error) {
			console.error('Error saving edit:', error);
			alert('Failed to save changes. Please try again.');
		} finally {
			savingEdit = false;
		}
	}

	function nextPage() { if (currentPage < totalPages) currentPage++; }
	function previousPage() { if (currentPage > 1) currentPage--; }

	function handleSearchKeydown(e: KeyboardEvent) {
		if (!searchQuery || filteredVendors.length === 0) return;
		if (e.key === 'ArrowDown') {
			e.preventDefault();
			highlightedIndex = (highlightedIndex + 1) % filteredVendors.length;
			document.querySelector(`[data-vendor-index="${highlightedIndex}"]`)?.scrollIntoView({ block: 'nearest' });
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			highlightedIndex = highlightedIndex <= 0 ? filteredVendors.length - 1 : highlightedIndex - 1;
			document.querySelector(`[data-vendor-index="${highlightedIndex}"]`)?.scrollIntoView({ block: 'nearest' });
		} else if (e.key === 'Enter') {
			e.preventDefault();
			if (highlightedIndex >= 0 && highlightedIndex < filteredVendors.length) {
				const v = filteredVendors[highlightedIndex];
				handleVendorSelect(v.vendor_id, v.vendor_name);
			}
		} else if (e.key === 'Escape') {
			searchQuery = '';
		}
	}

	const filterOrder: Array<'all' | 'paid' | 'unpaid'> = ['all', 'unpaid', 'paid'];

	function handleGlobalKeydown(e: KeyboardEvent) {
		if (!selectedVendorId) return;
		const tag = (e.target as HTMLElement)?.tagName;
		if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
		if (e.key === 'ArrowRight') {
			e.preventDefault();
			const idx = filterOrder.indexOf(paidFilter);
			paidFilter = filterOrder[(idx + 1) % filterOrder.length];
		} else if (e.key === 'ArrowLeft') {
			e.preventDefault();
			const idx = filterOrder.indexOf(paidFilter);
			paidFilter = filterOrder[(idx - 1 + filterOrder.length) % filterOrder.length];
		} else if (e.key === 'Escape') {
			clearSelection();
		}
	}

	function formatDate(dateString: string): string {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}/${month}/${year}`;
	}
</script>

<svelte:window on:keydown={handleGlobalKeydown} />

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">

	{#if loading}
		<!-- Loading state -->
		<div class="flex-1 flex items-center justify-center">
			<div class="text-center">
				<div class="animate-spin inline-block">
					<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
				</div>
				<p class="mt-4 text-slate-600 font-semibold">{$t('vendorPaymentFilters.loadingVendors')}</p>
				{#if loadingProgress > 0}
					<div class="w-64 mx-auto mt-3 h-2 bg-slate-200 rounded-full overflow-hidden">
						<div class="h-full bg-blue-500 transition-all duration-300" style="width: {loadingProgress}%"></div>
					</div>
					<p class="mt-1 text-xs text-slate-400">{loadingProgress}%</p>
				{/if}
			</div>
		</div>

	{:else if selectedVendorId}
		<!-- DETAIL VIEW: existing full functionality -->
		<div class="bg-white border-b border-slate-200 px-4 py-2.5 flex items-center gap-3 shadow-sm flex-shrink-0">
			<button
				class="px-3 py-1.5 bg-slate-100 text-slate-600 border border-slate-200 rounded-lg text-xs font-semibold hover:bg-slate-200 transition-all"
				on:click={clearSelection}
			>← {$t('nav.goBack')}</button>
			<div class="flex items-center gap-2">
				<span class="font-bold text-sm text-slate-800">{selectedVendorName}</span>
				<span class="text-xs text-slate-400">({selectedVendorId})</span>
			</div>
			<div class="ml-auto flex items-center gap-3">
				<div class="flex gap-1 bg-slate-100 p-1 rounded-xl border border-slate-200/50">
					<button class="px-3 py-1 text-[11px] font-bold uppercase rounded-lg transition-all {paidFilter === 'all' ? 'bg-blue-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => paidFilter = 'all'}>{$t('vendorPaymentFilters.all')}</button>
					<button class="px-3 py-1 text-[11px] font-bold uppercase rounded-lg transition-all {paidFilter === 'unpaid' ? 'bg-red-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => paidFilter = 'unpaid'}>{$t('vendorPaymentFilters.unpaid')}</button>
					<button class="px-3 py-1 text-[11px] font-bold uppercase rounded-lg transition-all {paidFilter === 'paid' ? 'bg-emerald-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => paidFilter = 'paid'}>{$t('vendorPaymentFilters.paid')}</button>
				</div>
				<div class="flex gap-1 bg-slate-100 p-1 rounded-xl border border-slate-200/50">
					<button class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === 'all' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => { dueInFilter = 'all'; paidFilter = 'all'; }}>{$t('vendorPaymentFilters.any')}</button>
					<button class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === '7' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => { dueInFilter = '7'; paidFilter = 'unpaid'; }}>{$t('vendorPaymentFilters.days7')}</button>
					<button class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === '15' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => { dueInFilter = '15'; paidFilter = 'unpaid'; }}>{$t('vendorPaymentFilters.days15')}</button>
					<button class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === '30' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}" on:click={() => { dueInFilter = '30'; paidFilter = 'unpaid'; }}>{$t('vendorPaymentFilters.days30')}</button>
				</div>
				<select bind:value={selectedBranchId} class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-500">
					<option value="">{$t('vendorPaymentFilters.selectBranch') || 'All Branches'}</option>
					{#each branches as branch}
						<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
					{/each}
				</select>
				<select bind:value={selectedPaymentMethod} class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-500">
					<option value="">{$t('vendorPaymentFilters.allMethods') || 'All Methods'}</option>
					{#each paymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
			</div>
		</div>

		{#if !loadingPayments}
			<div class="flex gap-3 px-4 py-2.5 flex-shrink-0">
				<div class="flex-1 flex items-center justify-between px-4 py-2 rounded-lg bg-sky-50 border border-sky-200">
					<span class="text-[10px] font-bold text-slate-500 uppercase">{$t('vendorPaymentFilters.total')}</span>
					<span class="text-sm font-black text-sky-700 flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-85" /> {summaryGrandTotal.toLocaleString()}
					</span>
				</div>
				<div class="flex-1 flex items-center justify-between px-4 py-2 rounded-lg bg-emerald-50 border border-emerald-200">
					<span class="text-[10px] font-bold text-slate-500 uppercase">{$t('vendorPaymentFilters.paid')}</span>
					<span class="text-sm font-black text-emerald-700 flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-85" /> {summaryTotalPaid.toLocaleString()}
					</span>
				</div>
				<div class="flex-1 flex items-center justify-between px-4 py-2 rounded-lg bg-red-50 border border-red-200">
					<span class="text-[10px] font-bold text-slate-500 uppercase">{$t('vendorPaymentFilters.unpaid')}</span>
					<span class="text-sm font-black text-red-600 flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-85" /> {summaryTotalUnpaid.toLocaleString()}
					</span>
				</div>
			</div>
		{/if}

		<div class="flex-1 overflow-auto px-4 pb-4">
			{#if loadingPayments}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-10 h-10 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
						</div>
						<p class="mt-3 text-slate-500 text-sm">{$t('vendorPaymentFilters.loadingPayments')}</p>
					</div>
				</div>
			{:else}
				<!-- Payments Table -->
				{#if filteredPayments.length > 0}
					{#if combinedCheckedCount > 0}
						<div class="mb-3 flex items-center gap-4 px-4 py-2.5 rounded-xl bg-blue-600 text-white shadow-lg text-xs font-bold">
							<span class="flex items-center gap-1.5">
								<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>
								{combinedCheckedCount} {$t('vendorPaymentFilters.selected')}
								{#if checkedCount > 0 && checkedExpenseCount > 0}
									<span class="font-normal opacity-75">({checkedCount} {$t('vendorPaymentFilters.payments')} + {checkedExpenseCount} {$t('vendorPaymentFilters.expenses')})</span>
								{/if}
							</span>
							<span class="flex items-center gap-1">
								{$t('vendorPaymentFilters.total')}:
								<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.7em] opacity-80 inline mx-0.5" />
								<span class="text-sm font-black">{combinedCheckedTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
							</span>
							<button class="ml-auto text-[10px] font-bold bg-white/20 hover:bg-white/30 px-2.5 py-1 rounded-lg transition-all" on:click={() => { checkedPaymentIds = new Set(); checkedExpenseIds = new Set(); }}>{$t('vendorPaymentFilters.clearAll')}</button>
						</div>
					{/if}
					<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden mb-4">
						<div class="overflow-x-auto">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-2 py-2.5 text-center text-[11px] font-black uppercase border-b-2 border-blue-400 w-8">
											<input type="checkbox" checked={allPageChecked} on:change={toggleAllPage} class="w-3.5 h-3.5 rounded cursor-pointer accent-white" />
										</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.branch')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.billDate')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.dueDate')}</th>
										<th class="px-3 py-2.5 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.amount')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.method')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.invoiceNumber')}</th>
										<th class="px-3 py-2.5 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.status')}</th>
										<th class="px-3 py-2.5 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.action')}</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each paginatedPayments as payment, index}
										<tr class="hover:bg-blue-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {checkedPaymentIds.has(String(payment.id)) ? '!bg-blue-50/60' : ''}">
											<td class="px-2 py-2 text-center w-8">
												<input type="checkbox" checked={checkedPaymentIds.has(String(payment.id))} on:change={() => toggleRow(String(payment.id))} class="w-3.5 h-3.5 rounded cursor-pointer accent-blue-600" />
											</td>
											<td class="px-3 py-2 text-xs text-slate-700">{payment.branches?.name_en || payment.branch_name || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700 font-mono">{formatDate(payment.bill_date)}</td>
											<td class="px-3 py-2 text-xs text-slate-700 font-mono">{formatDate(payment.due_date)}</td>
											<td class="px-3 py-2 text-xs text-right font-bold text-emerald-700">{payment.final_bill_amount?.toLocaleString() || 'N/A'}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{payment.payment_method || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{payment.bill_number || '-'}</td>
											<td class="px-3 py-2 text-xs text-center">
												<span class="inline-block px-2.5 py-0.5 rounded-full text-[10px] font-black {payment.is_paid ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'}">
{payment.is_paid ? $t('vendorPaymentFilters.paid') : $t('vendorPaymentFilters.unpaid')}
																	</span>
																</td>
																<td class="px-3 py-2 text-xs text-center">
																	<button class="inline-flex items-center px-3 py-1 rounded-lg bg-blue-600 text-white text-[10px] font-bold hover:bg-blue-700 transition-all" on:click={() => openEditModal(payment)}>✏️ {$t('vendorPaymentFilters.edit')}</button>
																</td>
															</tr>
														{/each}
													</tbody>
												</table>
											</div>
											<div class="px-4 py-2 bg-slate-50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500">
												<span>{$t('vendorPaymentFilters.showing')} {startRecord}-{endRecord} {$t('vendorPaymentFilters.of')} {totalRecords} {$t('vendorPaymentFilters.records')} · {$t('vendorPaymentFilters.total')}: <strong class="text-emerald-700">{totalAmount.toLocaleString()}</strong></span>
												{#if totalPages > 1}
													<div class="flex items-center gap-2">
														<button class="px-2.5 py-1 bg-blue-600 text-white rounded-md text-[10px] font-bold hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-all" on:click={previousPage} disabled={currentPage === 1}>← {$t('vendorPaymentFilters.prev')}</button>
														<span class="text-slate-600 font-semibold">{$t('vendorPaymentFilters.page')} {currentPage} / {totalPages}</span>
														<button class="px-2.5 py-1 bg-blue-600 text-white rounded-md text-[10px] font-bold hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-all" on:click={nextPage} disabled={currentPage === totalPages}>{$t('vendorPaymentFilters.next')} →</button>
													</div>
												{/if}
											</div>
										</div>
									{:else}
										<div class="bg-white/40 rounded-2xl border border-slate-200 p-8 text-center mb-4">
											<p class="text-slate-400 text-sm">{$t('vendorPaymentFilters.noPaymentsFound')} {selectedBranchId || selectedPaymentMethod ? $t('vendorPaymentFilters.matchingFilters') : $t('vendorPaymentFilters.forThisVendor')}.</p>
					</div>
				{/if}

				<!-- Expenses Table -->
				{#if filteredVendorExpenses.length > 0}
					{#if checkedExpenseCount > 0 && filteredPayments.length === 0}
						<div class="mb-3 flex items-center gap-4 px-4 py-2.5 rounded-xl bg-amber-600 text-white shadow-lg text-xs font-bold">
							<span class="flex items-center gap-1.5">
								<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>
								{checkedExpenseCount} {$t('vendorPaymentFilters.expenses')} {$t('vendorPaymentFilters.selected')}
							</span>
							<span class="flex items-center gap-1">
								{$t('vendorPaymentFilters.total')}:
								<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.7em] opacity-80 inline mx-0.5" />
								<span class="text-sm font-black">{checkedExpenseTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
							</span>
							<button class="ml-auto text-[10px] font-bold bg-white/20 hover:bg-white/30 px-2.5 py-1 rounded-lg transition-all" on:click={() => { checkedExpenseIds = new Set(); }}>{$t('vendorPaymentFilters.clear')}</button>
						</div>
					{/if}
					<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden">
						<div class="overflow-x-auto">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-amber-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-amber-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-2 py-2.5 text-center text-[11px] font-black uppercase border-b-2 border-amber-400 w-8">
											<input type="checkbox" checked={allExpensesChecked} on:change={toggleAllExpenses} class="w-3.5 h-3.5 rounded cursor-pointer accent-white" />
										</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.reqNumber')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.category')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.branch')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.dueDate')}</th>
										<th class="px-3 py-2.5 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.amount')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.method')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.requester')}</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.description')}</th>
										<th class="px-3 py-2.5 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">{$t('vendorPaymentFilters.status')}</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredVendorExpenses as expense, index}
										<tr class="hover:bg-amber-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {checkedExpenseIds.has(String(expense.id)) ? '!bg-amber-50/60' : ''}">
											<td class="px-2 py-2 text-center w-8">
												<input type="checkbox" checked={checkedExpenseIds.has(String(expense.id))} on:change={() => toggleExpenseRow(String(expense.id))} class="w-3.5 h-3.5 rounded cursor-pointer accent-amber-600" />
											</td>
											<td class="px-3 py-2 text-xs">
												<span class="inline-block px-2 py-0.5 bg-indigo-100 text-indigo-800 rounded text-[10px] font-bold">{expense.requisition_number || `#${expense.id}`}</span>
											</td>
											<td class="px-3 py-2 text-xs text-slate-700">{expense.expense_category_name_en || expense.expense_category_name_ar || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{expense.branch_name || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700 font-mono">{formatDate(expense.due_date)}</td>
											<td class="px-3 py-2 text-xs text-right font-bold text-emerald-700">{(expense.amount || 0).toLocaleString()}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{expense.payment_method || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{expense.co_user_name || expense.vendor_name || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700 max-w-[200px] truncate" title={expense.description || ''}>{expense.description || '-'}</td>
											<td class="px-3 py-2 text-xs text-center">
												<span class="inline-block px-2.5 py-0.5 rounded-full text-[10px] font-black {expense.is_paid ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'}">
													{expense.is_paid ? 'Paid' : (expense.status || 'Pending')}
												</span>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<div class="px-4 py-2 bg-slate-50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500 font-semibold">
							<span>{filteredVendorExpenses.length} expense{filteredVendorExpenses.length !== 1 ? 's' : ''} · Total: <strong class="text-red-600">{totalExpenseAmount.toLocaleString()}</strong></span>
							{#if checkedExpenseCount > 0}
								<span class="text-amber-700">{checkedExpenseCount} selected · <strong>{checkedExpenseTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</strong></span>
							{/if}
						</div>
					</div>
				{/if}
			{/if}
		</div>

	{:else}
		<!-- MAIN WINDOW: Account / Summary tab interface -->

		<!-- Global summary strip -->
		<div class="hidden md:flex gap-3 px-5 py-3 bg-white border-b border-slate-200 flex-shrink-0">
			<div class="flex items-center gap-2.5 px-4 py-2 rounded-xl bg-sky-50 border border-sky-200 flex-1 min-w-0">
				<div class="w-7 h-7 rounded-lg bg-gradient-to-br from-sky-400 to-blue-600 flex items-center justify-center flex-shrink-0">
					<span class="text-sm">💰</span>
				</div>
				<div class="min-w-0">
					<div class="text-[9px] font-black text-slate-400 uppercase tracking-wider">{$t('vendorPaymentFilters.grandTotal')}</div>
					<div class="text-sm font-black text-sky-700 flex items-center gap-0.5">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" /> {globalGrandTotal.toLocaleString()}
					</div>
				</div>
			</div>
			<div class="flex items-center gap-2.5 px-4 py-2 rounded-xl bg-emerald-50 border border-emerald-200 flex-1 min-w-0">
				<div class="w-7 h-7 rounded-lg bg-gradient-to-br from-emerald-400 to-green-600 flex items-center justify-center flex-shrink-0">
					<span class="text-sm">✅</span>
				</div>
				<div class="min-w-0">
					<div class="text-[9px] font-black text-slate-400 uppercase tracking-wider">{$t('vendorPaymentFilters.paid')}</div>
					<div class="text-sm font-black text-emerald-700 flex items-center gap-0.5">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" /> {globalTotalPaid.toLocaleString()}
					</div>
				</div>
			</div>
			<div class="flex items-center gap-2.5 px-4 py-2 rounded-xl bg-red-50 border border-red-200 flex-1 min-w-0">
				<div class="w-7 h-7 rounded-lg bg-gradient-to-br from-red-400 to-rose-600 flex items-center justify-center flex-shrink-0">
					<span class="text-sm">⏳</span>
				</div>
				<div class="min-w-0">
					<div class="text-[9px] font-black text-slate-400 uppercase tracking-wider">{$t('vendorPaymentFilters.unpaid')}</div>
					<div class="text-sm font-black text-red-600 flex items-center gap-0.5">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" /> {globalTotalUnpaid.toLocaleString()}
					</div>
				</div>
			</div>
			<div class="flex items-center gap-2.5 px-4 py-2 rounded-xl bg-purple-50 border border-purple-200 flex-1 min-w-0">
				<div class="w-7 h-7 rounded-lg bg-gradient-to-br from-purple-400 to-violet-600 flex items-center justify-center flex-shrink-0">
					<span class="text-sm">🏢</span>
				</div>
				<div class="min-w-0">
					<div class="text-[9px] font-black text-slate-400 uppercase tracking-wider">{$t('vendorPaymentFilters.vendors')}</div>
					<div class="text-sm font-black text-purple-700">{totalVendorCount}</div>
				</div>
			</div>
		</div>

		<!-- Tab bar -->
		<div class="hidden md:flex items-center gap-1 px-5 py-2 bg-white border-b border-slate-200 flex-shrink-0">
			<button
				class="flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-bold transition-all {activeTab === 'account' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-500 hover:bg-slate-100'}"
				on:click={() => activeTab = 'account'}
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
				{$t('vendorPaymentFilters.account')}
			</button>
		</div>

		{#if activeTab === 'account'}
			<!-- Account tab: full vendor table with search + scroll-to-load-more -->
			<div class="flex-1 flex flex-col overflow-hidden px-4 pt-3 pb-4">
				<!-- Search bar + branch filter + count — search on its own line, filter+count together on a second line on mobile -->
				<div class="flex flex-col md:flex-row md:items-center gap-2 md:gap-3 mb-3 flex-shrink-0">
					<div class="relative flex-1 max-w-md">
						<div class="absolute inset-y-0 left-3 flex items-center pointer-events-none">
							<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
						</div>
						<input
							type="text"
							placeholder={$t('vendorPaymentFilters.searchVendors')}
							bind:value={vendorTableSearch}
							class="w-full pl-10 pr-9 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/40 focus:border-blue-300 transition-all shadow-sm"
						/>
						{#if vendorTableSearch}
							<button
								aria-label="Clear search"
								class="absolute inset-y-0 right-3 flex items-center text-slate-400 hover:text-slate-600 transition-colors"
								on:click={() => vendorTableSearch = ''}
							>
								<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12"/></svg>
							</button>
						{/if}
					</div>
					<div class="flex items-center gap-3">
						<select
							bind:value={selectedErpBranchId}
							class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-blue-500/40 focus:border-blue-300 transition-all shadow-sm flex-1 md:flex-shrink-0 min-w-0"
							title="Filter balances by branch"
						>
							<option value="">{$t('vendorPaymentFilters.selectBranch') || 'All Branches'}</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
							{/each}
						</select>
						<span class="text-xs text-slate-500 font-semibold flex-shrink-0">
							{filteredTableVendors.length} {filteredTableVendors.length !== 1 ? $t('vendorPaymentFilters.vendorsCount') : $t('vendorPaymentFilters.vendorCount')}{#if vendorTableSearch} {$t('vendorPaymentFilters.found')}{/if}
						</span>
					</div>
				</div>

				<!-- Mobile: Totals summary card (desktop shows the same totals in the table footer) -->
				<div class="md:hidden mb-3 flex-shrink-0 bg-blue-600 rounded-xl shadow-sm p-3">
					<div class="text-[10px] font-bold text-blue-100 uppercase tracking-wide mb-2">
						{$t('vendorPaymentFilters.totals')} · {filteredTableVendors.length} {filteredTableVendors.length !== 1 ? $t('vendorPaymentFilters.vendorsCount') : $t('vendorPaymentFilters.vendorCount')}
					</div>
					<div class="grid grid-cols-2 gap-2">
						<div>
							<div class="text-[10px] text-blue-200 font-semibold uppercase">{$t('vendorPaymentFilters.billsUnpaid')}</div>
							{#if tableTotalBillsUnpaid > 0}
								<div class="text-sm font-black text-white flex items-center gap-1">
									<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-80" />
									{formatCompactAmount(tableTotalBillsUnpaid)}
								</div>
							{:else}
								<div class="text-sm text-blue-200">—</div>
							{/if}
						</div>
						<div>
							<div class="text-[10px] text-blue-200 font-semibold uppercase">{$t('vendorPaymentFilters.expensesUnpaid')}</div>
							{#if tableTotalExpensesUnpaid > 0}
								<div class="text-sm font-black text-white flex items-center gap-1">
									<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-80" />
									{formatCompactAmount(tableTotalExpensesUnpaid)}
								</div>
							{:else}
								<div class="text-sm text-blue-200">—</div>
							{/if}
						</div>
						<div>
							<div class="text-[10px] text-blue-200 font-semibold uppercase">{$t('vendorPaymentFilters.totalUnpaid')}</div>
							{#if tableTotalUnpaid > 0}
								<div class="text-sm font-black text-white flex items-center gap-1">
									<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-90" />
									{formatCompactAmount(tableTotalUnpaid)}
								</div>
							{:else}
								<div class="text-sm text-blue-200">—</div>
							{/if}
						</div>
						<div>
							<div class="text-[10px] text-blue-200 font-semibold uppercase">{$t('vendorPaymentFilters.totalOverdue')}</div>
							{#if tableTotalOverdue > 0}
								<div class="text-sm font-black text-orange-300 flex items-center gap-1">
									<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-90" />
									{formatCompactAmount(tableTotalOverdue)}
								</div>
							{:else}
								<div class="text-sm text-blue-200">—</div>
							{/if}
						</div>
					</div>
				</div>

				<!-- ERP tunnel warning -->
				{#if erpFailedBranches.length > 0}
					<div class="mx-0 mb-2 flex items-center gap-2 px-3 py-2 rounded-lg bg-amber-50 border border-amber-300 text-amber-800 text-xs font-semibold">
						<span class="text-base flex-shrink-0">⚠️</span>
						<span>ERP tunnel unreachable for: <strong>{erpFailedBranches.join(', ')}</strong> — balances may be incomplete</span>
					</div>
				{/if}

				<!-- Vendor table with scroll-to-load-more -->
				<div
					class="flex-1 overflow-auto bg-white/60 backdrop-blur-xl rounded-2xl border border-white/80 shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)]"
					on:scroll={handleVendorTableScroll}
				>
					<table class="w-full border-collapse hidden md:table">
						<thead class="sticky top-0 z-10">
							<tr class="bg-blue-600 text-white shadow-lg">
								<th class="px-3 py-3 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400 border-r border-blue-500/30 w-10">#</th>
								<th class="px-4 py-3 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400 border-r border-blue-500/30">{$t('vendorPaymentFilters.vendorName')}</th>
								<th class="px-4 py-3 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400 border-r border-blue-500/30">{$t('vendorPaymentFilters.vendorId')}</th>
								<th class="px-4 py-3 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400 border-r border-blue-500/30">{$t('vendorPaymentFilters.billsUnpaid')}</th>
								<th class="px-4 py-3 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400 border-r border-blue-500/30">{$t('vendorPaymentFilters.expensesUnpaid')}</th>
								<th class="px-4 py-3 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400 border-r border-blue-500/30">{$t('vendorPaymentFilters.totalUnpaid')}</th>
								<th class="px-4 py-3 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-orange-400 border-r border-orange-500/30 bg-orange-600">{$t('vendorPaymentFilters.totalOverdue')}</th>
								<th class="px-3 py-2 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-indigo-400 bg-indigo-600 border-r border-indigo-500/30">
									<div class="flex items-center justify-end gap-1.5">
										<span>{$t('vendorPaymentFilters.erpBalance')}</span>
										{#if erpBalancesLoading}
											<span class="text-[10px] opacity-70">⏳</span>
										{:else}
											<button class="px-1.5 py-0.5 rounded bg-white/20 hover:bg-white/30 text-[9px] font-bold" on:click={loadAllErpBalances} title="Refresh">🔄</button>
										{/if}
									</div>
								</th>
								<th class="px-4 py-3 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-slate-400 bg-slate-600 border-r border-slate-500/30">{$t('vendorPaymentFilters.match')}</th>
								<th class="px-4 py-3 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('vendorPaymentFilters.action')}</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-slate-100">
							{#each visibleTableVendors as vendor, index}
								<tr class="hover:bg-blue-50/40 transition-colors {index % 2 === 0 ? 'bg-white' : 'bg-slate-50/50'}">
									<td class="px-3 py-3 text-center text-xs font-bold text-slate-400 border-r border-slate-100 w-10">{index + 1}</td>
									<td class="px-4 py-3 text-sm font-semibold text-slate-800 border-r border-slate-100">{vendor.vendor_name}</td>
									<td class="px-4 py-3 border-r border-slate-100">
										<span class="inline-block px-2 py-0.5 bg-blue-100/70 text-blue-700 rounded-md text-xs font-bold">{vendor.vendor_id}</span>
									</td>
									<td class="px-4 py-3 text-right border-r border-slate-100">
										{#if getVendorBillsUnpaid(vendor.vendor_id) > 0}
											<span class="text-sm font-bold text-red-600 inline-flex items-center justify-end gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" />
												{getVendorBillsUnpaid(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										{:else}
											<span class="text-xs text-slate-300 font-medium">—</span>
										{/if}
									</td>
									<td class="px-4 py-3 text-right border-r border-slate-100">
										{#if getVendorExpensesUnpaid(vendor.vendor_id) > 0}
											<span class="text-sm font-bold text-amber-600 inline-flex items-center justify-end gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" />
												{getVendorExpensesUnpaid(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										{:else}
											<span class="text-xs text-slate-300 font-medium">—</span>
										{/if}
									</td>
									<td class="px-4 py-3 text-right border-r border-slate-100">
										{#if getVendorTotalUnpaid(vendor.vendor_id) > 0}
											<span class="text-sm font-black text-red-700 inline-flex items-center justify-end gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-80" />
												{getVendorTotalUnpaid(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										{:else}
											<span class="inline-block px-2 py-0.5 bg-emerald-100 text-emerald-700 rounded-md text-[10px] font-bold">Cleared</span>
										{/if}
									</td>
									<td class="px-4 py-3 text-right border-r border-slate-100 bg-orange-50/40">
										{#if getVendorTotalOverdue(vendor.vendor_id) > 0}
											<span class="text-sm font-black text-orange-700 inline-flex items-center justify-end gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-80" />
												{getVendorTotalOverdue(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</span>
										{:else}
											<span class="text-xs text-slate-300 font-medium">—</span>
										{/if}
									</td>
									<td class="px-4 py-3 text-right border-r border-indigo-100 bg-indigo-50/30">
										{#if erpBalancesLoading}
											<span class="text-xs text-indigo-300">⏳</span>
										{:else if erpBalanceMap.has(vendor.vendor_id)}
											{@const erb = erpBalanceMap.get(vendor.vendor_id)}
											<span class="text-sm font-black inline-flex items-center justify-end gap-1 {erb?.direction === 'Cr' ? 'text-emerald-700' : erb?.direction === 'Dr' ? 'text-red-600' : 'text-slate-400'}">
												{erb?.netBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												<span class="text-[10px] font-bold opacity-70">{erb?.direction}</span>
											</span>
										{:else}
											<span class="text-xs text-slate-300">—</span>
										{/if}
									</td>
									<td class="px-3 py-3 text-center border-r border-slate-100">
										{#if erpBalanceMap.has(vendor.vendor_id)}
											{@const erb = erpBalanceMap.get(vendor.vendor_id)}
											{@const overdue = getVendorTotalUnpaid(vendor.vendor_id)}
											{@const erpVal = erb?.netBalance ?? 0}
											{@const matched = Math.abs(overdue - erpVal) < 1}
											<span class="inline-block px-2 py-0.5 rounded-md text-[10px] font-black text-white {matched ? 'bg-emerald-600' : 'bg-red-600'}">
												{matched ? '✓' : '✗'}
											</span>
										{:else}
											<span class="text-xs text-slate-300">—</span>
										{/if}
									</td>
									<td class="px-4 py-3 text-center">
										<button
											class="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-blue-600 text-white text-xs font-bold hover:bg-blue-700 shadow-sm shadow-blue-200/60 transition-all"
											on:click={() => handleVendorSelect(vendor.vendor_id, vendor.vendor_name)}
										>
											<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
											{$t('vendorPaymentFilters.details')}
										</button>
									</td>
								</tr>
							{/each}
							{#if visibleTableVendors.length === 0}
								<tr>
									<td colspan="10" class="px-4 py-14 text-center">
										<div class="text-slate-400 text-sm">
											{vendorTableSearch ? `${$t('vendorPaymentFilters.noVendorsMatching')} "${vendorTableSearch}"` : $t('vendorPaymentFilters.noVendorsFound')}
										</div>
									</td>
								</tr>
							{/if}
						</tbody>
						<tfoot class="sticky bottom-0 z-10">
							<tr class="bg-blue-600 text-white shadow-lg">
								<td class="px-3 py-3 border-r border-blue-500/30"></td>
								<td class="px-4 py-3 text-xs font-black uppercase tracking-wider border-r border-blue-500/30">
									Totals · {filteredTableVendors.length} vendor{filteredTableVendors.length !== 1 ? 's' : ''}
								</td>
								<td class="px-4 py-3 border-r border-blue-500/30"></td>
								<td class="px-4 py-3 text-right border-r border-blue-500/30">
									{#if tableTotalBillsUnpaid > 0}
										<span class="text-sm font-black text-white inline-flex items-center justify-end gap-1">
											<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" />
											{tableTotalBillsUnpaid.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</span>
									{:else}
										<span class="text-xs text-white/60 font-medium">—</span>
									{/if}
								</td>
								<td class="px-4 py-3 text-right border-r border-blue-500/30">
									{#if tableTotalExpensesUnpaid > 0}
										<span class="text-sm font-black text-white inline-flex items-center justify-end gap-1">
											<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" />
											{tableTotalExpensesUnpaid.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</span>
									{:else}
										<span class="text-xs text-white/60 font-medium">—</span>
									{/if}
								</td>
								<td class="px-4 py-3 text-right border-r border-blue-500/30">
									{#if tableTotalUnpaid > 0}
										<span class="text-sm font-black text-white inline-flex items-center justify-end gap-1">
											<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-80" />
											{tableTotalUnpaid.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</span>
									{:else}
										<span class="text-xs text-white/60 font-medium">—</span>
									{/if}
								</td>
								<td class="px-4 py-3 text-right border-r border-orange-500/30 bg-orange-600">
									{#if tableTotalOverdue > 0}
										<span class="text-sm font-black text-white inline-flex items-center justify-end gap-1">
											<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-80" />
											{tableTotalOverdue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
										</span>
									{:else}
										<span class="text-xs text-white/60 font-medium">—</span>
									{/if}
								</td>
								<td class="px-4 py-3 border-r border-indigo-500/30"></td>
								<td class="px-4 py-3"></td>
								<td class="px-4 py-3"></td>
							</tr>
						</tfoot>
					</table>

					<!-- Mobile: vendor card list (desktop shows the table above instead) -->
					<div class="md:hidden flex flex-col gap-2 p-2">
						{#each visibleTableVendors as vendor, index}
							<div class="bg-white rounded-xl border border-slate-200 shadow-sm p-3">
								<div class="flex items-start justify-between gap-2 mb-2.5">
									<div class="min-w-0">
										<div class="text-sm font-bold text-slate-800 truncate">{vendor.vendor_name}</div>
										<span class="inline-block mt-1 px-2 py-0.5 bg-blue-100/70 text-blue-700 rounded-md text-[10px] font-bold">{vendor.vendor_id}</span>
									</div>
									<button
										class="flex-shrink-0 inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-blue-600 text-white text-[11px] font-bold hover:bg-blue-700 transition-all"
										on:click={() => handleVendorSelect(vendor.vendor_id, vendor.vendor_name)}
									>
										<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
										{$t('vendorPaymentFilters.details')}
									</button>
								</div>
								<div class="grid grid-cols-2 gap-x-3 gap-y-2 text-xs">
									<div>
										<div class="text-[10px] text-slate-400 font-semibold uppercase">{$t('vendorPaymentFilters.billsUnpaid')}</div>
										{#if getVendorBillsUnpaid(vendor.vendor_id) > 0}
											<div class="font-bold text-red-600 flex items-center gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" />
												{getVendorBillsUnpaid(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</div>
										{:else}
											<div class="text-slate-300">—</div>
										{/if}
									</div>
									<div>
										<div class="text-[10px] text-slate-400 font-semibold uppercase">{$t('vendorPaymentFilters.expensesUnpaid')}</div>
										{#if getVendorExpensesUnpaid(vendor.vendor_id) > 0}
											<div class="font-bold text-amber-600 flex items-center gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.5em] opacity-70" />
												{getVendorExpensesUnpaid(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</div>
										{:else}
											<div class="text-slate-300">—</div>
										{/if}
									</div>
									<div>
										<div class="text-[10px] text-slate-400 font-semibold uppercase">{$t('vendorPaymentFilters.totalUnpaid')}</div>
										{#if getVendorTotalUnpaid(vendor.vendor_id) > 0}
											<div class="font-black text-red-700 flex items-center gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-80" />
												{getVendorTotalUnpaid(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</div>
										{:else}
											<span class="inline-block px-1.5 py-0.5 bg-emerald-100 text-emerald-700 rounded text-[10px] font-bold">{$t('vendorPaymentFilters.cleared')}</span>
										{/if}
									</div>
									<div>
										<div class="text-[10px] text-slate-400 font-semibold uppercase">{$t('vendorPaymentFilters.totalOverdue')}</div>
										{#if getVendorTotalOverdue(vendor.vendor_id) > 0}
											<div class="font-black text-orange-700 flex items-center gap-1">
												<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-80" />
												{getVendorTotalOverdue(vendor.vendor_id).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
											</div>
										{:else}
											<div class="text-slate-300">—</div>
										{/if}
									</div>
								</div>
								<div class="flex items-center justify-between gap-2 mt-2.5 pt-2.5 border-t border-slate-100">
									<div>
										<div class="text-[10px] text-slate-400 font-semibold uppercase">{$t('vendorPaymentFilters.erpBalance')}</div>
										{#if erpBalancesLoading}
											<div class="text-indigo-300">⏳</div>
										{:else if erpBalanceMap.has(vendor.vendor_id)}
											{@const erb = erpBalanceMap.get(vendor.vendor_id)}
											<div class="font-black flex items-center gap-1 {erb?.direction === 'Cr' ? 'text-emerald-700' : erb?.direction === 'Dr' ? 'text-red-600' : 'text-slate-400'}">
												{erb?.netBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
												<span class="text-[10px] font-bold opacity-70">{erb?.direction}</span>
											</div>
										{:else}
											<div class="text-slate-300">—</div>
										{/if}
									</div>
									{#if erpBalanceMap.has(vendor.vendor_id)}
										{@const erb = erpBalanceMap.get(vendor.vendor_id)}
										{@const overdue = getVendorTotalUnpaid(vendor.vendor_id)}
										{@const erpVal = erb?.netBalance ?? 0}
										{@const matched = Math.abs(overdue - erpVal) < 1}
										<span class="inline-block px-2 py-0.5 rounded-md text-[10px] font-black text-white {matched ? 'bg-emerald-600' : 'bg-red-600'}">
											{matched ? `✓ ${$t('vendorPaymentFilters.matchText')}` : `✗ ${$t('vendorPaymentFilters.mismatchText')}`}
										</span>
									{/if}
								</div>
							</div>
						{/each}
						{#if visibleTableVendors.length === 0}
							<div class="text-center text-slate-400 text-sm py-14">
								{vendorTableSearch ? `${$t('vendorPaymentFilters.noVendorsMatching')} "${vendorTableSearch}"` : $t('vendorPaymentFilters.noVendorsFound')}
							</div>
						{/if}
					</div>

					{#if visibleTableVendors.length < filteredTableVendors.length}
						<div class="flex items-center justify-center py-4 gap-2 text-slate-400 text-xs border-t border-slate-100 bg-white/50">
							<div class="w-3.5 h-3.5 border-2 border-slate-300 border-t-blue-500 rounded-full animate-spin"></div>
							<span>{$t('vendorPaymentFilters.scrollToLoadMore')} · {visibleTableVendors.length} {$t('vendorPaymentFilters.of')} {filteredTableVendors.length} {$t('vendorPaymentFilters.shown')}</span>
						</div>
					{/if}
				</div>
			</div>

		{:else}
			<!-- Summary tab: Coming Soon -->
			<div class="flex-1 flex items-center justify-center p-8 bg-gradient-to-br from-purple-50/30 via-slate-50 to-white">
				<div class="bg-white/60 backdrop-blur-xl rounded-3xl border border-white/80 shadow-[0_8px_32px_-8px_rgba(0,0,0,0.1)] p-12 text-center max-w-sm">
					<div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-purple-400 to-violet-600 flex items-center justify-center mx-auto mb-5 shadow-lg shadow-purple-200/60">
						<svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
					</div>
					<h3 class="text-xl font-black text-slate-800 mb-2">Coming Soon</h3>
					<p class="text-sm text-slate-400 leading-relaxed">Advanced vendor payment summaries and analytics will be available here in a future update.</p>
					<div class="mt-6 flex items-center justify-center gap-1.5">
						<span class="w-2 h-2 rounded-full bg-purple-300"></span>
						<span class="w-2 h-2 rounded-full bg-purple-400"></span>
						<span class="w-2 h-2 rounded-full bg-purple-500"></span>
					</div>
				</div>
			</div>
		{/if}
	{/if}

	<!-- Edit Modal -->
	{#if showEditModal && editingPayment}
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-interactive-supports-focus -->
		<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" on:click={closeEditModal} on:keydown={e => e.key === 'Escape' && closeEditModal()} role="dialog" tabindex="-1">
			<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-noninteractive-element-interactions -->
			<div class="bg-white rounded-2xl shadow-2xl w-[90%] max-w-md" on:click|stopPropagation={() => {}} role="document">
				<div class="flex items-center justify-between px-5 py-4 border-b border-slate-200">
					<h2 class="text-base font-bold text-slate-800">{$t('vendorPaymentFilters.editPaymentDetails')}</h2>
					<button class="w-7 h-7 flex items-center justify-center rounded-md text-slate-400 hover:bg-slate-100 hover:text-slate-800 transition" on:click={closeEditModal}>✕</button>
				</div>
				<div class="p-5 flex flex-col gap-4">
					<div class="flex flex-col gap-1">
						<label for="edit-due-date" class="text-xs font-bold text-slate-600 uppercase">{$t('vendorPaymentFilters.dueDate')}</label>
						<input id="edit-due-date" type="date" bind:value={editFormData.due_date} class="px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
					</div>
					<div class="flex flex-col gap-1">
						<label for="edit-branch" class="text-xs font-bold text-slate-600 uppercase">{$t('vendorPaymentFilters.branch')}</label>
						<select id="edit-branch" bind:value={editFormData.branch_id} class="px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
							<option value="">{$t('vendorPaymentFilters.selectBranch') || 'Select Branch'}</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
							{/each}
						</select>
					</div>
					<div class="flex flex-col gap-1">
						<label for="edit-method" class="text-xs font-bold text-slate-600 uppercase">{$t('vendorPaymentFilters.paymentMethod')}</label>
						<select id="edit-method" bind:value={editFormData.payment_method} class="px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
							<option value="">{$t('vendorPaymentFilters.selectMethod')}</option>
							{#each paymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>
				</div>
				<div class="flex justify-end gap-2 px-5 py-4 border-t border-slate-200">
					<button class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm font-semibold hover:bg-slate-200 transition disabled:opacity-50" on:click={closeEditModal} disabled={savingEdit}>{$t('vendorPaymentFilters.cancel')}</button>
					<button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700 transition disabled:opacity-50" on:click={saveEdit} disabled={savingEdit}>{savingEdit ? $t('vendorPaymentFilters.saving') : $t('vendorPaymentFilters.saveChanges')}</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- All styling handled by Tailwind utility classes -->
