<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';

	export let onRefresh = null;
	export let setRefreshCallback = null;

	// Date range
	function toDateStr(d: Date) {
		return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
	}
	let dateFrom = toDateStr(new Date());
	let dateTo = toDateStr(new Date());

	// Shift date range by N days
	function shiftDateRange(days: number) {
		const f = new Date(dateFrom);
		const t = new Date(dateTo);
		f.setDate(f.getDate() + days);
		t.setDate(t.getDate() + days);
		dateFrom = toDateStr(f);
		dateTo = toDateStr(t);
	}

	// Data
	let paidVendorPayments = [];
	let paidExpensePayments = [];
	let branches = [];
	let branchMap = {};
	let paymentMethods = [];
	let isLoading = false;
	let loadingProgress = 0;

	// Filters
	let filterBranch = '';
	let filterPaymentMethod = '';

	// Editing state
	let editingVendorPaymentId = null;
	let editingExpensePaymentId = null;
	let editingVendorReference = '';
	let editingExpenseReference = '';

	// Pending ERP Reference modal
	let showPendingModal = false;
	let pendingVendorPayments = [];
	let pendingExpensePayments = [];

	// Inline edit popup state
	let showEditPopup = false;
	let editPopupPaymentId = null;
	let editPopupPaymentType = null; // 'vendor' or 'expense'
	let editPopupReference = '';
	let editPopupLabel = '';

	// Real-time subscriptions
	let vendorSubscription = null;
	let expenseSubscription = null;

	// Helper to format currency
	function formatCurrency(amount) {
		if (amount === null || amount === undefined || isNaN(amount)) return 'SAR 0.00';
		return `SAR ${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
	}

	// Helper to format date as dd/mm/yyyy
	function formatDate(dateInput) {
		if (!dateInput) return 'N/A';
		try {
			const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
			if (isNaN(date.getTime())) return 'N/A';
			const day = String(date.getDate()).padStart(2, '0');
			const month = String(date.getMonth() + 1).padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'N/A';
		}
	}

	// Get branch name
	function getBranchName(branchId) {
		if (!branchId) return 'N/A';
		return branchMap[branchId] || 'N/A';
	}

	// Load branches
	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en', { ascending: true })
				.limit(5000);

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
			branchMap = {};
			branches.forEach(branch => {
				const display = branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en;
				branchMap[branch.id] = display;
			});
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	// Load paid vendor payments for selected date range (RPC)
	async function loadPaidVendorPayments() {
		try {
			console.log('🔍 Loading vendor payments via RPC:', dateFrom, 'to', dateTo);

			const { data, error } = await supabase
				.rpc('get_paid_vendor_payments', {
					p_date_from: dateFrom,
					p_date_to: dateTo
				});

			if (error) {
				console.error('Error loading paid vendor payments:', error);
				return;
			}

			console.log('✅ Vendor payments loaded:', data?.length || 0, 'records');
			paidVendorPayments = data || [];
		} catch (error) {
			console.error('Error loading paid vendor payments:', error);
		}
	}

	// Load paid expense scheduler payments for selected date range (RPC)
	async function loadPaidExpensePayments() {
		try {
			console.log('🔍 Loading expense payments via RPC:', dateFrom, 'to', dateTo);

			const { data, error } = await supabase
				.rpc('get_paid_expense_payments', {
					p_date_from: dateFrom,
					p_date_to: dateTo
				});

			if (error) {
				console.error('Error loading paid expense payments:', error);
				return;
			}

			// Map creator_username to match the old shape { creator: { username } }
			console.log('✅ Expense payments loaded:', data?.length || 0, 'records');
			paidExpensePayments = (data || []).map(p => ({
				...p,
				creator: { username: p.creator_username || 'Unknown' }
			}));
		} catch (error) {
			console.error('Error loading paid expense payments:', error);
		}
	}

	// Get unique payment methods from current data
	$: availablePaymentMethods = [...new Set([
		...paidVendorPayments.map(p => p.payment_method).filter(Boolean),
		...paidExpensePayments.map(p => p.payment_method).filter(Boolean)
	])].sort();

	// Export filtered data to XLSX with 2 sheets
	async function exportToExcel() {
		try {
			const XLSX = await import('xlsx');
			const wb = XLSX.utils.book_new();
			const dateStr = dateFrom === dateTo ? dateFrom : `${dateFrom}_to_${dateTo}`;

			// Sheet 1: Vendor Payments sorted by vendor name
			const vendorData = [...filteredVendorPayments]
				.sort((a, b) => (a.vendor_name || '').localeCompare(b.vendor_name || ''))
				.map(p => ({
					'Bill #': p.bill_number || 'N/A',
					'Vendor Name': p.vendor_name || 'N/A',
					'Amount': p.final_bill_amount || 0,
					'Bill Date': formatDate(p.bill_date),
					'Paid Date': formatDate(p.paid_date),
					'Branch': getBranchName(p.branch_id),
					'Payment Method': p.payment_method || 'N/A',
					'ERP Reference': p.payment_reference || 'N/A'
				}));
			const ws1 = XLSX.utils.json_to_sheet(vendorData);
			// Set column widths
			ws1['!cols'] = [
				{ wch: 12 }, { wch: 30 }, { wch: 14 }, { wch: 14 },
				{ wch: 14 }, { wch: 25 }, { wch: 16 }, { wch: 18 }
			];
			XLSX.utils.book_append_sheet(wb, ws1, 'Vendor Payments');

			// Sheet 2: Expense Payments sorted by branch name
			const expenseData = [...filteredExpensePayments]
				.sort((a, b) => (getBranchName(a.branch_id) || '').localeCompare(getBranchName(b.branch_id) || ''))
				.map(p => ({
					'Voucher #': p.id || 'N/A',
					'Category': p.expense_category_name_en || p.expense_category_name_ar || 'Unknown',
					'Branch': getBranchName(p.branch_id),
					'Payment Method': p.payment_method || 'N/A',
					'Amount': p.amount || 0,
					'Paid Date': formatDate(p.paid_date),
					'Created By': p.creator?.username || 'Unknown',
					'Description': p.description || 'N/A',
					'ERP Reference': p.payment_reference || 'N/A'
				}));
			const ws2 = XLSX.utils.json_to_sheet(expenseData);
			ws2['!cols'] = [
				{ wch: 12 }, { wch: 25 }, { wch: 25 }, { wch: 16 },
				{ wch: 14 }, { wch: 14 }, { wch: 18 }, { wch: 30 }, { wch: 18 }
			];
			XLSX.utils.book_append_sheet(wb, ws2, 'Expense Payments');

			XLSX.writeFile(wb, `Paid_Payments_${dateStr}.xlsx`);
		} catch (err) {
			console.error('Export failed:', err);
			alert('Export failed: ' + err.message);
		}
	}

	// Filtered payments
	$: filteredVendorPayments = paidVendorPayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentMethod && payment.payment_method !== filterPaymentMethod) return false;
		return true;
	});

	$: filteredExpensePayments = paidExpensePayments.filter(payment => {
		if (filterBranch && payment.branch_id != filterBranch) return false;
		if (filterPaymentMethod && payment.payment_method !== filterPaymentMethod) return false;
		return true;
	});

	// Update vendor payment reference
	async function updateVendorReference(paymentId, newReference) {
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ payment_reference: newReference || null })
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating vendor payment reference:', error);
				alert('Failed to update payment reference');
				return;
			}

			// Update local data
			paidVendorPayments = paidVendorPayments.map(p => 
				p.id === paymentId ? { ...p, payment_reference: newReference } : p
			);
			editingVendorPaymentId = null;
			console.log('✅ Vendor payment reference updated');
		} catch (error) {
			console.error('Error updating vendor payment reference:', error);
			alert('Failed to update payment reference');
		}
	}

	// Update expense payment reference
	async function updateExpenseReference(paymentId, newReference) {
		try {
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ payment_reference: newReference || null })
				.eq('id', paymentId);

			if (error) {
				console.error('Error updating expense payment reference:', error);
				alert('Failed to update payment reference');
				return;
			}

			// Update local data
			paidExpensePayments = paidExpensePayments.map(p => 
				p.id === paymentId ? { ...p, payment_reference: newReference } : p
			);
			editingExpensePaymentId = null;
			console.log('✅ Expense payment reference updated');
		} catch (error) {
			console.error('Error updating expense payment reference:', error);
			alert('Failed to update payment reference');
		}
	}

	// Open edit popup for pending transaction
	function openEditPopup(paymentId, paymentType, label) {
		editPopupPaymentId = paymentId;
		editPopupPaymentType = paymentType;
		editPopupReference = '';
		editPopupLabel = label;
		showEditPopup = true;
	}

	// Save from edit popup
	async function saveFromPopup() {
		if (!editPopupReference.trim()) {
			alert('Please enter an ERP Payment Reference');
			return;
		}

		if (editPopupPaymentType === 'vendor') {
			await updateVendorReference(editPopupPaymentId, editPopupReference);
		} else if (editPopupPaymentType === 'expense') {
			await updateExpenseReference(editPopupPaymentId, editPopupReference);
		}

		showEditPopup = false;
		// Refresh pending list
		pendingVendorPayments = paidVendorPayments.filter(p => !p.payment_reference);
		pendingExpensePayments = paidExpensePayments.filter(p => !p.payment_reference);
	}

	// Get pending ERP references
	function showPendingERPReferences() {
		pendingVendorPayments = paidVendorPayments.filter(p => !p.payment_reference);
		pendingExpensePayments = paidExpensePayments.filter(p => !p.payment_reference);
		showPendingModal = true;
	}

	// Open All Vendor Paid window
	async function openAllVendorPaidWindow() {
		const { default: AllVendorPaid } = await import('$lib/components/desktop-interface/master/finance/AllVendorPaid.svelte');
		openWindow({
			id: `all-vendor-paid-${Date.now()}`,
			title: '📦 All Vendor Paid Transactions',
			component: AllVendorPaid,
			icon: '📦',
			size: { width: 1100, height: 700 },
			position: { 
				x: 80 + (Math.random() * 50), 
				y: 80 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Open All Expense Paid window
	async function openAllExpensePaidWindow() {
		const { default: AllExpensePaid } = await import('$lib/components/desktop-interface/master/finance/AllExpensePaid.svelte');
		openWindow({
			id: `all-expense-paid-${Date.now()}`,
			title: '💳 All Expense Paid Transactions',
			component: AllExpensePaid,
			icon: '💳',
			size: { width: 1100, height: 700 },
			position: { 
				x: 100 + (Math.random() * 50), 
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function loadData() {
		isLoading = true;
		loadingProgress = 0;
		try {
			loadingProgress = 10;
			await loadBranches();
			loadingProgress = 40;
			await loadPaidVendorPayments();
			loadingProgress = 70;
			await loadPaidExpensePayments();
			loadingProgress = 100;
		} finally {
			isLoading = false;
			loadingProgress = 0;
		}
	}

	onMount(() => {
		loadData();
		subscribeToRealtimeUpdates();

		// Cleanup subscriptions on component unmount
		return () => {
			if (vendorSubscription) {
				vendorSubscription.unsubscribe();
			}
			if (expenseSubscription) {
				expenseSubscription.unsubscribe();
			}
		};
	});

	// Subscribe to real-time updates
	function subscribeToRealtimeUpdates() {
		console.log('🔄 Setting up real-time subscriptions...');

		// Subscribe to vendor_payment_schedule changes
		vendorSubscription = supabase
			.channel('vendor_payment_schedule_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'vendor_payment_schedule',
					filter: `is_paid=eq.true`
				},
				(payload) => {
					console.log('📦 Vendor payment update received:', payload);
					handleVendorPaymentUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('📦 Vendor subscription status:', status);
			});

		// Subscribe to expense_scheduler changes
		expenseSubscription = supabase
			.channel('expense_scheduler_changes')
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'expense_scheduler',
					filter: `is_paid=eq.true`
				},
				(payload) => {
					console.log('💳 Expense payment update received:', payload);
					handleExpensePaymentUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('💳 Expense subscription status:', status);
			});
	}

	// Handle vendor payment updates
	function handleVendorPaymentUpdate(payload) {
		const startDate = dateFrom;
		const endObj = new Date(dateTo);
		endObj.setDate(endObj.getDate() + 1);
		const endDate = toDateStr(endObj);

		// Check if the updated payment matches the selected date range
		const paymentDate = payload.new?.due_date || payload.old?.due_date;
		if (paymentDate && paymentDate >= startDate && paymentDate < endDate && payload.new?.is_paid === true) {
			if (payload.eventType === 'INSERT') {
				console.log('✨ New vendor payment added');
				paidVendorPayments = [...paidVendorPayments, payload.new];
			} else if (payload.eventType === 'UPDATE') {
				console.log('🔄 Vendor payment updated');
				paidVendorPayments = paidVendorPayments.map(p =>
					p.id === payload.new.id ? payload.new : p
				);
			} else if (payload.eventType === 'DELETE') {
				console.log('🗑️ Vendor payment deleted');
				paidVendorPayments = paidVendorPayments.filter(p => p.id !== payload.old.id);
			}
		}
	}

	// Handle expense payment updates
	function handleExpensePaymentUpdate(payload) {
		const startDate = dateFrom;
		const endObj = new Date(dateTo);
		endObj.setDate(endObj.getDate() + 1);
		const endDate = toDateStr(endObj);

		// Check if the updated payment matches the selected date range
		const paymentDate = payload.new?.due_date || payload.old?.due_date;
		if (paymentDate && paymentDate >= startDate && paymentDate < endDate && payload.new?.is_paid === true) {
			if (payload.eventType === 'INSERT') {
				console.log('✨ New expense payment added');
				paidExpensePayments = [...paidExpensePayments, payload.new];
			} else if (payload.eventType === 'UPDATE') {
				console.log('🔄 Expense payment updated');
				paidExpensePayments = paidExpensePayments.map(p =>
					p.id === payload.new.id ? payload.new : p
				);
			} else if (payload.eventType === 'DELETE') {
				console.log('🗑️ Expense payment deleted');
				paidExpensePayments = paidExpensePayments.filter(p => p.id !== payload.old.id);
			}
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-4 py-1 flex items-center justify-end shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl overflow-hidden bg-orange-600 text-white shadow-lg shadow-orange-200 hover:bg-orange-700 hover:shadow-orange-300"
				on:click={showPendingERPReferences}
			>
				<span class="text-base filter drop-shadow-sm">⚠️</span>
				<span>Pending ERP</span>
				<span class="bg-white/20 px-2 py-0.5 rounded-full text-[10px] font-black">
					{paidVendorPayments.filter(p => !p.payment_reference).length + paidExpensePayments.filter(p => !p.payment_reference).length}
				</span>
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl overflow-hidden bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700 hover:shadow-blue-300"
				on:click={openAllVendorPaidWindow}
			>
				<span class="text-base filter drop-shadow-sm">📦</span>
				<span>All Vendor Paid</span>
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl overflow-hidden bg-purple-600 text-white shadow-lg shadow-purple-200 hover:bg-purple-700 hover:shadow-purple-300"
				on:click={openAllExpensePaidWindow}
			>
				<span class="text-base filter drop-shadow-sm">💳</span>
				<span>All Expense Paid</span>
			</button>
			<button
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl overflow-hidden bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:shadow-emerald-300"
				on:click={exportToExcel}
			>
				<span class="text-base filter drop-shadow-sm">📊</span>
				<span>Export Excel</span>
			</button>
		</div>
	</div>

	{#if isLoading}
		<div class="flex-1 flex items-center justify-center">
			<div class="text-center">
				<div class="animate-spin inline-block mb-4">
					<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
				</div>
				<p class="text-slate-600 font-semibold">Loading paid transactions...</p>
				<div class="w-64 h-2 bg-slate-200 rounded-full mt-4 mx-auto overflow-hidden">
					<div class="h-full bg-blue-600 rounded-full transition-all" style="width: {loadingProgress}%"></div>
				</div>
				<p class="text-xs text-slate-400 mt-2">{loadingProgress}%</p>
			</div>
		</div>
	{/if}

	<!-- Scrollable Content -->
	<div class="flex-1 px-4 pt-1 pb-4 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-purple-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto flex flex-col gap-3">

		<!-- Date Range & Filter Controls -->
		<div class="sticky top-0 z-20 bg-white/80 backdrop-blur-md rounded-2xl shadow-sm border border-slate-200/50 px-5 py-4 flex flex-wrap gap-4 items-end">
			<div class="min-w-[180px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="date-from">From</label>
				<div class="flex items-center gap-1">
					<button on:click={() => shiftDateRange(-1)} class="shrink-0 w-8 h-10 flex items-center justify-center rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200 hover:text-blue-800 transition-all font-bold text-sm" title="Previous day">&larr;</button>
					<input id="date-from" type="date" bind:value={dateFrom}
						class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						style="color: #000000 !important; background-color: #ffffff !important;"
					/>
					<button on:click={() => shiftDateRange(1)} class="shrink-0 w-8 h-10 flex items-center justify-center rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200 hover:text-blue-800 transition-all font-bold text-sm" title="Next day">&rarr;</button>
				</div>
			</div>
			<div class="min-w-[180px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="date-to">To</label>
				<div class="flex items-center gap-1">
					<button on:click={() => { const d = new Date(dateTo); d.setDate(d.getDate() - 1); dateTo = toDateStr(d); }} class="shrink-0 w-8 h-10 flex items-center justify-center rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200 hover:text-blue-800 transition-all font-bold text-sm" title="Previous day">&larr;</button>
					<input id="date-to" type="date" bind:value={dateTo}
						class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						style="color: #000000 !important; background-color: #ffffff !important;"
					/>
					<button on:click={() => { const d = new Date(dateTo); d.setDate(d.getDate() + 1); dateTo = toDateStr(d); }} class="shrink-0 w-8 h-10 flex items-center justify-center rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200 hover:text-blue-800 transition-all font-bold text-sm" title="Next day">&rarr;</button>
				</div>
			</div>
			<div>
				<label class="block text-xs font-bold text-transparent mb-2">&nbsp;</label>
				<button on:click={loadData}
					class="flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-black uppercase tracking-wide bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700 hover:shadow-blue-300 transition-all duration-300 {isLoading ? 'opacity-60 pointer-events-none' : ''}"
				>
					{#if isLoading}
						<span class="animate-spin inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full"></span>
					{:else}
						<span>🔄</span>
					{/if}
					<span>Load</span>
				</button>
			</div>
			<div class="flex-1">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filter-branch">Branch</label>
				<select id="filter-branch" bind:value={filterBranch}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
					style="color: #000000 !important; background-color: #ffffff !important;"
				>
					<option value="" style="color: #000000 !important; background-color: #ffffff !important;">All Branches</option>
					{#each branches as branch}
						<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
					{/each}
				</select>
			</div>
			<div class="flex-1">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filter-payment-method">Payment Method</label>
				<select id="filter-payment-method" bind:value={filterPaymentMethod}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
					style="color: #000000 !important; background-color: #ffffff !important;"
				>
					<option value="" style="color: #000000 !important; background-color: #ffffff !important;">All Methods</option>
					{#each availablePaymentMethods as method}
						<option value={method} style="color: #000000 !important; background-color: #ffffff !important;">{method}</option>
					{/each}
				</select>
			</div>
		</div>

	<!-- Paid Vendor Payments Section -->
	<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">

		<div class="overflow-x-auto flex-1">
			<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
				<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
					<tr>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Bill #</th>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Vendor</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Amount</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Bill Date</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Paid Date</th>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Branch</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Payment Method</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">ERP Reference</th>
						<th class="px-4 py-3 text-right text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">
							{#if true}
								{@const totalAmount = filteredVendorPayments.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0)}
								<span class="bg-blue-500/30 px-2 py-0.5 rounded text-[10px]">{filteredVendorPayments.length} items</span>
								<span class="bg-blue-500/30 px-2 py-0.5 rounded text-[10px] ml-1">{formatCurrency(totalAmount)}</span>
							{/if}
						</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-slate-200">
					{#if filteredVendorPayments.length > 0}
						{#each filteredVendorPayments as payment, index}
							<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
								<td class="px-4 py-3 text-sm">
									<span class="inline-block bg-blue-100 text-blue-700 px-3 py-1 rounded-lg font-bold text-xs">#{payment.bill_number || 'N/A'}</span>
								</td>
								<td class="px-4 py-3 text-sm text-slate-700 font-medium">
									{payment.vendor_name || 'N/A'}
								</td>
								<td class="px-4 py-3 text-sm font-bold text-center text-emerald-600">
									{formatCurrency(payment.final_bill_amount)}
								</td>
								<td class="px-4 py-3 text-sm text-center text-slate-600">{formatDate(payment.bill_date)}</td>
								<td class="px-4 py-3 text-sm text-center font-semibold text-emerald-600">{formatDate(payment.paid_date)}</td>
								<td class="px-4 py-3 text-sm text-slate-700">{getBranchName(payment.branch_id)}</td>
								<td class="px-4 py-3 text-sm text-center">
									<span class="inline-block bg-amber-100 text-amber-800 px-3 py-1 rounded-lg text-xs font-semibold">{payment.payment_method || 'Payment'}</span>
								</td>
								<td class="px-4 py-3 text-sm">
									{#if editingVendorPaymentId === payment.id}
										<div class="flex gap-2 items-center">
											<input 
												type="text" 
												value={editingVendorReference}
												on:change={(e) => editingVendorReference = e.target.value}
												on:keydown={(e) => {
													if (e.key === 'Enter') {
														updateVendorReference(payment.id, editingVendorReference);
													} else if (e.key === 'Escape') {
														editingVendorPaymentId = null;
													}
												}}
												placeholder="Enter ERP Reference"
												class="flex-1 px-3 py-2 border-2 border-blue-400 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-600"
												autoFocus
											/>
											<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 transition-all" on:click={() => updateVendorReference(payment.id, editingVendorReference)}>✓</button>
											<button class="px-3 py-2 bg-red-600 text-white text-xs font-bold rounded-lg hover:bg-red-700 transition-all" on:click={() => editingVendorPaymentId = null}>✕</button>
										</div>
									{:else}
										<div class="flex items-center gap-2 cursor-pointer hover:bg-blue-50 px-3 py-2 rounded-lg transition-all" on:click={() => {
											editingVendorPaymentId = payment.id;
											editingVendorReference = payment.payment_reference || '';
										}}>
											<span class="text-slate-700">{payment.payment_reference || 'N/A'}</span>
											<span class="opacity-0 hover:opacity-100 transition-opacity">✏️</span>
										</div>
									{/if}
								</td>
							</tr>
					{/each}
					{:else}
						<tr>
							<td colspan="8" class="px-8 py-12 text-center">
								<div class="text-slate-500 text-sm">📭 No paid vendor payments for this date</div>
							</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	</div>

	<!-- Paid Expense Payments Section -->
	<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">

		<div class="overflow-x-auto flex-1">
			<table class="w-full border-collapse [&_th]:border-x [&_th]:border-purple-500/30 [&_td]:border-x [&_td]:border-slate-200">
				<thead class="sticky top-0 bg-purple-600 text-white shadow-lg z-10">
					<tr>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Voucher #</th>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Category</th>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Branch</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Payment Method</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Amount</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Paid Date</th>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Created By</th>
						<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">Description</th>
						<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">ERP Reference</th>
						<th class="px-4 py-3 text-right text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">
							{#if true}
								{@const totalExpenses = filteredExpensePayments.reduce((sum, p) => sum + (p.amount || 0), 0)}
								<span class="bg-purple-500/30 px-2 py-0.5 rounded text-[10px]">{filteredExpensePayments.length} items</span>
								<span class="bg-purple-500/30 px-2 py-0.5 rounded text-[10px] ml-1">{formatCurrency(totalExpenses)}</span>
							{/if}
						</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-slate-200">
					{#if filteredExpensePayments.length > 0}
						{#each filteredExpensePayments as payment, index}
							<tr class="hover:bg-purple-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
								<td class="px-4 py-3 text-sm">
									<span class="inline-block bg-purple-100 text-purple-700 px-3 py-1 rounded-lg font-bold text-xs">#{payment.id || 'N/A'}</span>
								</td>
								<td class="px-4 py-3 text-sm text-slate-700 font-medium">
									{#if payment.expense_category_name_en || payment.expense_category_name_ar}
										{payment.expense_category_name_en || payment.expense_category_name_ar}
									{:else}
										<span class="text-amber-600 italic">Unknown Category</span>
									{/if}
								</td>
								<td class="px-4 py-3 text-sm text-slate-700">{getBranchName(payment.branch_id)}</td>
								<td class="px-4 py-3 text-sm text-center">
									<span class="inline-block bg-purple-100 text-purple-800 px-3 py-1 rounded-lg text-xs font-semibold">{payment.payment_method || 'Expense'}</span>
								</td>
								<td class="px-4 py-3 text-sm font-bold text-center text-emerald-600">
									{formatCurrency(payment.amount || 0)}
								</td>
								<td class="px-4 py-3 text-sm text-center font-semibold text-emerald-600">{formatDate(payment.paid_date)}</td>
								<td class="px-4 py-3 text-sm text-slate-700">{payment.creator?.username || 'Unknown'}</td>
								<td class="px-4 py-3 text-sm text-slate-700 max-w-xs truncate" title="{payment.description || ''}">
									{payment.description || 'N/A'}
								</td>
								<td class="px-4 py-3 text-sm">
									{#if editingExpensePaymentId === payment.id}
										<div class="flex gap-2 items-center">
											<input 
												type="text" 
												value={editingExpenseReference}
												on:change={(e) => editingExpenseReference = e.target.value}
												on:keydown={(e) => {
													if (e.key === 'Enter') {
														updateExpenseReference(payment.id, editingExpenseReference);
													} else if (e.key === 'Escape') {
														editingExpensePaymentId = null;
													}
												}}
												placeholder="Enter ERP Reference"
												class="flex-1 px-3 py-2 border-2 border-purple-400 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-purple-600"
												autoFocus
											/>
											<button class="px-3 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 transition-all" on:click={() => updateExpenseReference(payment.id, editingExpenseReference)}>✓</button>
											<button class="px-3 py-2 bg-red-600 text-white text-xs font-bold rounded-lg hover:bg-red-700 transition-all" on:click={() => editingExpensePaymentId = null}>✕</button>
										</div>
									{:else}
										<div class="flex items-center gap-2 cursor-pointer hover:bg-purple-50 px-3 py-2 rounded-lg transition-all" on:click={() => {
											editingExpensePaymentId = payment.id;
											editingExpenseReference = payment.payment_reference || '';
										}}>
											<span class="text-slate-700">{payment.payment_reference || 'N/A'}</span>
											<span class="opacity-0 hover:opacity-100 transition-opacity">✏️</span>
										</div>
									{/if}
								</td>
							</tr>
						{/each}
					{:else}
						<tr>
							<td colspan="9" class="px-8 py-12 text-center">
								<div class="text-slate-500 text-sm">📭 No paid expense payments for this date</div>
							</td>
						</tr>
					{/if}
				</tbody>
			</table>
		</div>
	</div>

	</div><!-- /relative max-w wrapper -->
	</div><!-- /scrollable content -->
</div><!-- /root -->

<!-- Pending ERP References Modal -->
{#if showPendingModal}
	<div class="modal-overlay" on:click={() => showPendingModal = false}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>⚠️ Pending ERP Payment References</h2>
				<p class="modal-subtitle">Date Range: {dateFrom} to {dateTo}</p>
			</div>

			<div class="modal-body">
				<!-- Vendor Payments Summary -->
				<div class="pending-section">
					<h3 class="pending-title">📦 Vendor Payments Without ERP Reference</h3>
					<div class="pending-summary">
						<span class="count-badge vendor-badge">{pendingVendorPayments.length}</span>
						<span class="summary-text">payments missing ERP reference</span>
					</div>
					{#if pendingVendorPayments.length > 0}
						<div class="pending-list">
							{#each pendingVendorPayments as payment}
								<div class="pending-item clickable-item" on:click={() => openEditPopup(payment.id, 'vendor', `Bill #${payment.bill_number} - ${payment.vendor_name}`)}>
									<div class="pending-info">
										<span class="bill-info">Bill #{payment.bill_number}</span>
										<span class="vendor-name">{payment.vendor_name}</span>
										<span class="due-date">Due: {formatDate(payment.due_date)}</span>
									</div>
									<span class="pending-amount">{formatCurrency(payment.final_bill_amount)}</span>
								</div>
							{/each}
						</div>
					{:else}
						<p class="no-pending">✓ All vendor payments have ERP references</p>
					{/if}
				</div>

				<!-- Expense Payments Summary -->
				<div class="pending-section">
					<h3 class="pending-title">💳 Expense Payments Without ERP Reference</h3>
					<div class="pending-summary">
						<span class="count-badge expense-badge">{pendingExpensePayments.length}</span>
						<span class="summary-text">payments missing ERP reference</span>
					</div>
					{#if pendingExpensePayments.length > 0}
						<div class="pending-list">
							{#each pendingExpensePayments as payment}
								<div class="pending-item clickable-item" on:click={() => openEditPopup(payment.id, 'expense', `Voucher #${payment.id} - ${payment.expense_category_name_en || payment.expense_category_name_ar || 'Unknown'}`)}>
									<div class="pending-info">
										<span class="bill-info">Voucher #{payment.id}</span>
										<span class="vendor-name">{payment.expense_category_name_en || payment.expense_category_name_ar || 'Unknown'}</span>
										<span class="due-date">Due: {formatDate(payment.due_date)}</span>
									</div>
									<span class="pending-amount">{formatCurrency(payment.amount)}</span>
								</div>
							{/each}
						</div>
					{:else}
						<p class="no-pending">✓ All expense payments have ERP references</p>
					{/if}
				</div>

				<!-- Summary Stats -->
				<div class="pending-stats">
					<div class="stat">
						<span class="stat-label">Total Pending:</span>
						<span class="stat-value">{pendingVendorPayments.length + pendingExpensePayments.length}</span>
					</div>
					<div class="stat">
						<span class="stat-label">Total Amount:</span>
						<span class="stat-value">
							{formatCurrency(
								pendingVendorPayments.reduce((sum, p) => sum + (p.final_bill_amount || 0), 0) +
								pendingExpensePayments.reduce((sum, p) => sum + (p.amount || 0), 0)
							)}
						</span>
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button class="close-btn" on:click={() => showPendingModal = false}>Close</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit ERP Reference Popup Modal -->
{#if showEditPopup}
	<div class="modal-overlay" on:click={() => showEditPopup = false}>
		<div class="edit-popup-content" on:click|stopPropagation>
			<div class="edit-popup-header">
				<h3>📝 Edit ERP Payment Reference</h3>
				<p class="edit-popup-label">{editPopupLabel}</p>
			</div>

			<div class="edit-popup-body">
				<label for="erp-reference-input">ERP Payment Reference:</label>
				<input
					id="erp-reference-input"
					type="text"
					placeholder="Enter ERP Payment Reference"
					bind:value={editPopupReference}
					on:keydown={(e) => {
						if (e.key === 'Enter') {
							saveFromPopup();
						} else if (e.key === 'Escape') {
							showEditPopup = false;
						}
					}}
					autoFocus
				/>
			</div>

			<div class="edit-popup-footer">
				<button class="popup-cancel-btn" on:click={() => showEditPopup = false}>Cancel</button>
				<button class="popup-save-btn" on:click={saveFromPopup}>Save</button>
			</div>
		</div>
	</div>
{/if}

<style>
	/* Modal Styles */
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
		backdrop-filter: blur(4px);
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
		max-width: 700px;
		width: 90%;
		max-height: 85vh;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		padding: 24px;
		border-bottom: 2px solid #e2e8f0;
		background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
		color: white;
	}

	.modal-header h2 {
		margin: 0 0 8px 0;
		font-size: 24px;
		font-weight: 700;
	}

	.modal-subtitle {
		margin: 0;
		font-size: 14px;
		opacity: 0.9;
	}

	.modal-body {
		padding: 24px;
		flex: 1;
		overflow-y: auto;
	}

	.modal-footer {
		padding: 16px 24px;
		border-top: 1px solid #e2e8f0;
		display: flex;
		justify-content: flex-end;
		gap: 12px;
	}

	.close-btn {
		padding: 8px 24px;
		background: #e2e8f0;
		color: #475569;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #cbd5e1;
	}

	/* Pending sections */
	.pending-section {
		margin-bottom: 24px;
		padding: 16px;
		background: #f8fafc;
		border-radius: 8px;
		border-left: 4px solid #f97316;
	}

	.pending-title {
		margin: 0 0 12px 0;
		font-size: 16px;
		font-weight: 600;
		color: #1e293b;
	}

	.pending-summary {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
	}

	.count-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		border-radius: 50%;
		font-weight: 700;
		font-size: 18px;
		color: white;
	}

	.vendor-badge {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
	}

	.expense-badge {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
	}

	.summary-text {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	.pending-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
		max-height: 300px;
		overflow-y: auto;
	}

	.pending-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px;
		background: white;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		transition: all 0.2s;
	}

	.pending-item:hover {
		background: #f0f9ff;
		border-color: #3b82f6;
	}

	.pending-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.bill-info {
		font-weight: 600;
		color: #1e293b;
		font-size: 14px;
	}

	.vendor-name {
		font-size: 13px;
		color: #64748b;
	}

	.due-date {
		font-size: 12px;
		color: #94a3b8;
	}

	.pending-amount {
		font-weight: 600;
		color: #059669;
		font-size: 14px;
	}

	.no-pending {
		text-align: center;
		padding: 20px;
		color: #059669;
		font-weight: 500;
		margin: 0;
	}

	.pending-stats {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		padding: 16px;
		background: linear-gradient(135deg, #f0f9ff 0%, #f0fdfa 100%);
		border-radius: 8px;
		margin-top: 16px;
	}

	.stat {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.stat-label {
		font-size: 13px;
		color: #64748b;
		font-weight: 500;
	}

	.stat-value {
		font-size: 18px;
		font-weight: 700;
		color: #0f766e;
	}

	/* Clickable pending items */
	.clickable-item {
		cursor: pointer;
		transition: all 0.2s;
	}

	.clickable-item:hover {
		background: #e0f2fe !important;
		border-color: #0284c7 !important;
		box-shadow: 0 2px 8px rgba(2, 132, 199, 0.15);
		transform: translateX(4px);
	}

	/* Edit Popup Styles */
	.edit-popup-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
		width: 90%;
		max-width: 450px;
		display: flex;
		flex-direction: column;
		z-index: 1001;
	}

	.edit-popup-header {
		padding: 20px 24px;
		border-bottom: 2px solid #e2e8f0;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border-radius: 12px 12px 0 0;
	}

	.edit-popup-header h3 {
		margin: 0 0 8px 0;
		font-size: 20px;
		font-weight: 700;
	}

	.edit-popup-label {
		margin: 0;
		font-size: 13px;
		opacity: 0.9;
		font-weight: 500;
	}

	.edit-popup-body {
		padding: 24px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.edit-popup-body label {
		display: block;
		font-weight: 600;
		color: #1e293b;
		font-size: 14px;
		margin-bottom: 8px;
	}

	.edit-popup-body input {
		width: 100%;
		padding: 12px 14px;
		border: 2px solid #cbd5e1;
		border-radius: 8px;
		font-size: 15px;
		color: #1e293b;
		outline: none;
		transition: all 0.2s;
		font-family: inherit;
	}

	.edit-popup-body input:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.edit-popup-body input::placeholder {
		color: #94a3b8;
	}

	.edit-popup-footer {
		padding: 16px 24px;
		border-top: 1px solid #e2e8f0;
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		background: #f8fafc;
		border-radius: 0 0 12px 12px;
	}

	.popup-cancel-btn,
	.popup-save-btn {
		padding: 10px 24px;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.popup-cancel-btn {
		background: #e2e8f0;
		color: #475569;
	}

	.popup-cancel-btn:hover {
		background: #cbd5e1;
		transform: translateY(-2px);
	}

	.popup-save-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.2);
	}

	.popup-save-btn:hover {
		box-shadow: 0 6px 20px rgba(16, 185, 129, 0.3);
		transform: translateY(-2px);
	}
</style>
