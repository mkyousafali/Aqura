<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { _ as t } from '$lib/i18n';
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

	// Pagination
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

	// Filtered vendors based on search
	$: filteredVendors = vendors.filter(v => 
		v.vendor_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
		v.vendor_id.toLowerCase().includes(searchQuery.toLowerCase())
	);

	// Reset highlight when search query or filtered list changes
	$: if (searchQuery || filteredVendors) highlightedIndex = -1;

	// Filtered payments based on branch, payment method and paid status
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

	// Pagination calculations (derived from filteredPayments)
	$: totalRecords = filteredPayments.length;
	$: totalPages = Math.ceil(totalRecords / pageSize);
	$: startRecord = (currentPage - 1) * pageSize + 1;
	$: endRecord = Math.min(currentPage * pageSize, totalRecords);

	// Paginated payments for display
	$: paginatedPayments = filteredPayments.slice(
		(currentPage - 1) * pageSize,
		currentPage * pageSize
	);

	// Reset to page 1 when filters change and current page is out of bounds
	$: if (currentPage > totalPages && totalPages > 0) {
		currentPage = 1;
	}

	// Calculate total amount
	$: totalAmount = filteredPayments.reduce((sum, payment) => {
		return sum + (payment.final_bill_amount || 0);
	}, 0);

	// Filtered vendor expenses based on branch, payment method and paid status
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

	// Calculate total expense amount for selected vendor
	$: totalExpenseAmount = filteredVendorExpenses.reduce((sum, exp) => {
		return sum + (exp.amount || 0);
	}, 0);

	// Summary totals across both tables (payments + expenses) — unfiltered by paid status
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
		searchInputEl?.focus();
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
		} catch (error) {
			console.error('Error loading initial data:', error);
			// Fallback to old method if RPC fails
			await Promise.all([loadVendorsFallback(), loadSummaryFallback(), loadAllPaymentMethodsFallback()]);
		}
	}

	async function loadAllPaymentMethodsFallback() {
		try {
			const [vpsResult, expResult] = await Promise.all([
				supabase
					.from('vendor_payment_schedule')
					.select('payment_method')
					.not('payment_method', 'is', null),
				supabase
					.from('expense_scheduler')
					.select('payment_method')
					.not('payment_method', 'is', null)
					.not('vendor_id', 'is', null)
			]);

			// Extract unique payment methods from both sources
			const methods = new Set<string>();
			vpsResult.data?.forEach(item => {
				if (item.payment_method) methods.add(item.payment_method);
			});
			expResult.data?.forEach(item => {
				if (item.payment_method) methods.add(item.payment_method);
			});
			paymentMethods = Array.from(methods).sort();
		} catch (error) {
			console.error('Error loading payment methods:', error);
		}
	}

	async function loadSummaryFallback() {
		try {
			const [paymentResult, expenseResult] = await Promise.all([
				supabase
					.from('vendor_payment_schedule')
					.select('vendor_id, final_bill_amount, is_paid'),
				supabase
					.from('expense_scheduler')
					.select('vendor_id, amount, is_paid')
					.not('vendor_id', 'is', null)
			]);

			if (paymentResult.error) throw paymentResult.error;

			// Count unique vendors
			const uniqueVendors = new Set(paymentResult.data?.map(item => item.vendor_id));
			if (expenseResult.data) {
				expenseResult.data.forEach(item => uniqueVendors.add(item.vendor_id?.toString()));
			}
			totalVendorCount = uniqueVendors.size;

			// Calculate global paid/unpaid from vendor_payment_schedule
			const vpsPaid = paymentResult.data?.filter(i => i.is_paid).reduce((s, i) => s + (i.final_bill_amount || 0), 0) || 0;
			const vpsUnpaid = paymentResult.data?.filter(i => !i.is_paid).reduce((s, i) => s + (i.final_bill_amount || 0), 0) || 0;

			// Calculate global paid/unpaid from expense_scheduler
			const expPaid = expenseResult.data?.filter(i => i.is_paid).reduce((s, i) => s + (i.amount || 0), 0) || 0;
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
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en');

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

			// Also load vendors from expense_scheduler (vendor expenses)
			const { data: expenseVendors } = await supabase
				.from('expense_scheduler')
				.select('vendor_id, vendor_name')
				.not('vendor_id', 'is', null);

			if (expenseVendors) {
				for (const item of expenseVendors) {
					if (item.vendor_id && item.vendor_name) {
						const vid = item.vendor_id.toString();
						if (!vendorMap.has(vid)) {
							vendorMap.set(vid, {
								vendor_id: vid,
								vendor_name: item.vendor_name
							});
						}
					}
				}
			}

			while (hasMore) {
				const from = page * pageSize;
				const to = from + pageSize - 1;

			const { data, error, count } = await supabase
				.from('vendor_payment_schedule')
				.select('vendor_id, vendor_name', { count: 'exact' })
				.range(from, to);				if (error) throw error;

				if (!data || data.length === 0) {
					hasMore = false;
					break;
				}

				// Add unique vendors to map
				for (const item of data) {
					if (item.vendor_id && item.vendor_name && !vendorMap.has(item.vendor_id)) {
						vendorMap.set(item.vendor_id, {
							vendor_id: item.vendor_id,
							vendor_name: item.vendor_name
						});
					}
				}

				totalLoaded += data.length;
				
				// Update progress
				if (count) {
					loadingProgress = Math.round((totalLoaded / count) * 100);
				}

				// Check if we have more data
				hasMore = data.length === pageSize;
				page++;

				// Update vendors array progressively
				vendors = Array.from(vendorMap.values()).sort((a, b) => 
					a.vendor_name.localeCompare(b.vendor_name)
				);
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
		currentPage = 1; // Reset pagination
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
					.select(`
						*,
						branches!branch_id (
							name_en,
							name_ar
						)
					`)
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
			console.log('Vendor expenses loaded:', vendorExpenses.length, 'for vendor_id:', vendorIdInt);
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
		editFormData = {
			due_date: '',
			branch_id: '',
			payment_method: ''
		};
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

			// Update the local payments array
			payments = payments.map(p => 
				p.id === editingPayment.id 
					? { 
						...p, 
						due_date: editFormData.due_date,
						branch_id: parseInt(editFormData.branch_id),
						payment_method: editFormData.payment_method,
						branches: branches.find(b => b.id.toString() === editFormData.branch_id)
					}
					: p
			);

			closeEditModal();
		} catch (error) {
			console.error('Error saving edit:', error);
			alert('Failed to save changes. Please try again.');
		} finally {
			savingEdit = false;
		}
	}

	function goToPage(page: number) {
		if (page >= 1 && page <= totalPages) {
			currentPage = page;
		}
	}

	function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
		}
	}

	function previousPage() {
		if (currentPage > 1) {
			currentPage--;
		}
	}

	function handleSearchKeydown(e: KeyboardEvent) {
		if (!searchQuery || filteredVendors.length === 0) return;
		if (e.key === 'ArrowDown') {
			e.preventDefault();
			highlightedIndex = (highlightedIndex + 1) % filteredVendors.length;
			// Scroll into view
			const el = document.querySelector(`[data-vendor-index="${highlightedIndex}"]`);
			el?.scrollIntoView({ block: 'nearest' });
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			highlightedIndex = highlightedIndex <= 0 ? filteredVendors.length - 1 : highlightedIndex - 1;
			const el = document.querySelector(`[data-vendor-index="${highlightedIndex}"]`);
			el?.scrollIntoView({ block: 'nearest' });
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
		// Only in Step 2, and not when focus is on an input/select
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
		<div class="flex-1 flex items-center justify-center">
			<div class="text-center">
				<div class="animate-spin inline-block">
					<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
				</div>
				<p class="mt-4 text-slate-600 font-semibold">Loading vendors...</p>
				{#if loadingProgress > 0}
					<div class="w-64 mx-auto mt-3 h-2 bg-slate-200 rounded-full overflow-hidden">
						<div class="h-full bg-blue-500 transition-all duration-300" style="width: {loadingProgress}%"></div>
					</div>
					<p class="mt-1 text-xs text-slate-400">{loadingProgress}%</p>
				{/if}
			</div>
		</div>
	{:else if !selectedVendorId}
		<!-- STEP 1: Global Summary + Centered Search -->
		<div class="flex-1 flex flex-col items-center justify-center p-8 overflow-auto relative bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-blue-50 via-slate-50 to-white">
			<!-- Decorative background blobs -->
			<div class="absolute top-10 left-10 w-72 h-72 bg-blue-200/20 rounded-full blur-3xl pointer-events-none"></div>
			<div class="absolute bottom-10 right-10 w-96 h-96 bg-emerald-200/15 rounded-full blur-3xl pointer-events-none"></div>
			<div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-purple-100/10 rounded-full blur-3xl pointer-events-none"></div>

			<!-- Summary Cards -->
			<div class="grid grid-cols-4 gap-4 w-full max-w-3xl mb-10 relative z-10">
				<!-- Total -->
				<div class="group relative bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 flex flex-col items-center gap-2 hover:shadow-[0_16px_48px_-12px_rgba(14,165,233,0.2)] hover:scale-[1.03] transition-all duration-300">
					<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-sky-400 to-blue-600 flex items-center justify-center shadow-lg shadow-sky-200/50">
						<span class="text-white text-lg">💰</span>
					</div>
					<span class="text-[10px] font-black text-slate-400 uppercase tracking-[0.15em]">Total</span>
					<span class="text-xl font-black bg-gradient-to-r from-sky-600 to-blue-700 bg-clip-text text-transparent flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-70" /> {globalGrandTotal.toLocaleString()}
					</span>
				</div>
				<!-- Paid -->
				<div class="group relative bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 flex flex-col items-center gap-2 hover:shadow-[0_16px_48px_-12px_rgba(16,185,129,0.2)] hover:scale-[1.03] transition-all duration-300">
					<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-400 to-green-600 flex items-center justify-center shadow-lg shadow-emerald-200/50">
						<span class="text-white text-lg">✅</span>
					</div>
					<span class="text-[10px] font-black text-slate-400 uppercase tracking-[0.15em]">Paid</span>
					<span class="text-xl font-black bg-gradient-to-r from-emerald-600 to-green-700 bg-clip-text text-transparent flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-70" /> {globalTotalPaid.toLocaleString()}
					</span>
				</div>
				<!-- Unpaid -->
				<div class="group relative bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 flex flex-col items-center gap-2 hover:shadow-[0_16px_48px_-12px_rgba(239,68,68,0.2)] hover:scale-[1.03] transition-all duration-300">
					<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-red-400 to-rose-600 flex items-center justify-center shadow-lg shadow-red-200/50">
						<span class="text-white text-lg">⏳</span>
					</div>
					<span class="text-[10px] font-black text-slate-400 uppercase tracking-[0.15em]">Unpaid</span>
					<span class="text-xl font-black bg-gradient-to-r from-red-500 to-rose-600 bg-clip-text text-transparent flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-70" /> {globalTotalUnpaid.toLocaleString()}
					</span>
				</div>
				<!-- Vendors -->
				<div class="group relative bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] p-5 flex flex-col items-center gap-2 hover:shadow-[0_16px_48px_-12px_rgba(147,51,234,0.2)] hover:scale-[1.03] transition-all duration-300">
					<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-400 to-violet-600 flex items-center justify-center shadow-lg shadow-purple-200/50">
						<span class="text-white text-lg">🏢</span>
					</div>
					<span class="text-[10px] font-black text-slate-400 uppercase tracking-[0.15em]">Vendors</span>
					<span class="text-xl font-black bg-gradient-to-r from-purple-600 to-violet-700 bg-clip-text text-transparent">{totalVendorCount}</span>
				</div>
			</div>

			<!-- Search Section -->
			<div class="w-full max-w-xl text-center relative z-10">
				<div class="bg-white/50 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.1)] p-8">
					<div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center mx-auto mb-4 shadow-lg shadow-blue-200/50">
						<span class="text-2xl">🔍</span>
					</div>
					<h3 class="text-lg font-black text-slate-800 mb-1">Search & Select Vendor</h3>
					<p class="text-sm text-slate-400 mb-5">Select a vendor to view detailed payment information</p>
					<div class="relative">
						<div class="absolute inset-y-0 left-4 flex items-center pointer-events-none">
							<svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
						</div>
						<input
							bind:this={searchInputEl}
							type="text"
							placeholder="Search vendor by name or ID..."
							bind:value={searchQuery}
							on:keydown={handleSearchKeydown}
							class="w-full pl-11 pr-4 py-3.5 bg-slate-50/80 border border-slate-200/80 rounded-2xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-300 focus:bg-white transition-all duration-300 shadow-inner placeholder:text-slate-400"
						/>
						{#if searchQuery && filteredVendors.length > 0}
							<div class="absolute top-full left-0 right-0 mt-2 bg-white/95 backdrop-blur-xl border border-slate-200 rounded-2xl shadow-[0_16px_48px_-8px_rgba(0,0,0,0.15)] z-10 max-h-72 overflow-y-auto">
								{#each filteredVendors as vendor, i}
									<button
										data-vendor-index={i}
										class="w-full px-5 py-3 text-left transition-all duration-200 border-b border-slate-100/80 last:border-b-0 first:rounded-t-2xl last:rounded-b-2xl {i === highlightedIndex ? 'bg-blue-100/70' : 'hover:bg-blue-50/50'}"
										on:click={() => handleVendorSelect(vendor.vendor_id, vendor.vendor_name)}
										on:mouseenter={() => highlightedIndex = i}
									>
										<div class="font-semibold text-sm text-slate-800">{vendor.vendor_name}</div>
										<div class="text-[11px] text-slate-400 mt-0.5">ID: {vendor.vendor_id}</div>
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			</div>
		</div>
	{:else}
		<!-- STEP 2: Vendor Detail View -->
		<!-- Header bar -->
		<div class="bg-white border-b border-slate-200 px-4 py-2.5 flex items-center gap-3 shadow-sm">
			<button
				class="px-3 py-1.5 bg-slate-100 text-slate-600 border border-slate-200 rounded-lg text-xs font-semibold hover:bg-slate-200 transition-all"
				on:click={clearSelection}
			>← {$t('nav.goBack')}</button>
			<div class="flex items-center gap-2">
				<span class="font-bold text-sm text-slate-800">{selectedVendorName}</span>
				<span class="text-xs text-slate-400">({selectedVendorId})</span>
			</div>
			<!-- Filters inline -->
			<div class="ml-auto flex items-center gap-3">
				<div class="flex gap-1 bg-slate-100 p-1 rounded-xl border border-slate-200/50">
					<button
						class="px-3 py-1 text-[11px] font-bold uppercase rounded-lg transition-all {paidFilter === 'all' ? 'bg-blue-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => paidFilter = 'all'}
					>{$t('vendorPaymentFilters.all')}</button>
					<button
						class="px-3 py-1 text-[11px] font-bold uppercase rounded-lg transition-all {paidFilter === 'unpaid' ? 'bg-red-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => paidFilter = 'unpaid'}
					>{$t('vendorPaymentFilters.unpaid')}</button>
					<button
						class="px-3 py-1 text-[11px] font-bold uppercase rounded-lg transition-all {paidFilter === 'paid' ? 'bg-emerald-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => paidFilter = 'paid'}
					>{$t('vendorPaymentFilters.paid')}</button>
				</div>

				<!-- Due in Filters -->
				<div class="flex gap-1 bg-slate-100 p-1 rounded-xl border border-slate-200/50">
					<button
						class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === 'all' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => { dueInFilter = 'all'; paidFilter = 'all'; }}
					>{$t('vendorPaymentFilters.any')}</button>
					<button
						class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === '7' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => { dueInFilter = '7'; paidFilter = 'unpaid'; }}
					>{$t('vendorPaymentFilters.days7')}</button>
					<button
						class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === '15' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => { dueInFilter = '15'; paidFilter = 'unpaid'; }}
					>{$t('vendorPaymentFilters.days15')}</button>
					<button
						class="px-2 py-1 text-[10px] font-bold uppercase rounded-lg transition-all {dueInFilter === '30' ? 'bg-indigo-600 text-white shadow' : 'text-slate-500 hover:bg-white'}"
						on:click={() => { dueInFilter = '30'; paidFilter = 'unpaid'; }}
					>{$t('vendorPaymentFilters.days30')}</button>
				</div>

				<select bind:value={selectedBranchId} class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-500">
					<option value="">{$t('nav.selectBranch') || 'All Branches'}</option>
					{#each branches as branch}
						<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
					{/each}
				</select>
				<select bind:value={selectedPaymentMethod} class="px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-blue-500">
					<option value="">All Methods</option>
					{#each paymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
			</div>
		</div>

		<!-- Summary Cards (vendor-level) -->
		{#if !loadingPayments}
			<div class="flex gap-3 px-4 py-2.5">
				<div class="flex-1 flex items-center justify-between px-4 py-2 rounded-lg bg-sky-50 border border-sky-200">
					<span class="text-[10px] font-bold text-slate-500 uppercase">Total</span>
					<span class="text-sm font-black text-sky-700 flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-85" /> {summaryGrandTotal.toLocaleString()}
					</span>
				</div>
				<div class="flex-1 flex items-center justify-between px-4 py-2 rounded-lg bg-emerald-50 border border-emerald-200">
					<span class="text-[10px] font-bold text-slate-500 uppercase">Paid</span>
					<span class="text-sm font-black text-emerald-700 flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-85" /> {summaryTotalPaid.toLocaleString()}
					</span>
				</div>
				<div class="flex-1 flex items-center justify-between px-4 py-2 rounded-lg bg-red-50 border border-red-200">
					<span class="text-[10px] font-bold text-slate-500 uppercase">Unpaid</span>
					<span class="text-sm font-black text-red-600 flex items-center gap-1">
						<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="h-[0.55em] opacity-85" /> {summaryTotalUnpaid.toLocaleString()}
					</span>
				</div>
			</div>
		{/if}

		<!-- Tables area -->
		<div class="flex-1 overflow-auto px-4 pb-4">
			{#if loadingPayments}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-10 h-10 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
						</div>
						<p class="mt-3 text-slate-500 text-sm">Loading payments...</p>
					</div>
				</div>
			{:else}
				<!-- Receiving Payments Table -->
				{#if filteredPayments.length > 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden mb-4">
						<div class="overflow-x-auto">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Branch</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Bill Date</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Due Date</th>
										<th class="px-3 py-2.5 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Amount</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Method</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Invoice #</th>
										<th class="px-3 py-2.5 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Status</th>
										<th class="px-3 py-2.5 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-blue-400">Action</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each paginatedPayments as payment, index}
										<tr class="hover:bg-blue-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-3 py-2 text-xs text-slate-700">{payment.branches?.name_en || payment.branch_name || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700 font-mono">{formatDate(payment.bill_date)}</td>
											<td class="px-3 py-2 text-xs text-slate-700 font-mono">{formatDate(payment.due_date)}</td>
											<td class="px-3 py-2 text-xs text-right font-bold text-emerald-700">{payment.final_bill_amount?.toLocaleString() || 'N/A'}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{payment.payment_method || '-'}</td>
											<td class="px-3 py-2 text-xs text-slate-700">{payment.bill_number || '-'}</td>
											<td class="px-3 py-2 text-xs text-center">
												<span class="inline-block px-2.5 py-0.5 rounded-full text-[10px] font-black {payment.is_paid ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'}">
													{payment.is_paid ? 'Paid' : 'Unpaid'}
												</span>
											</td>
											<td class="px-3 py-2 text-xs text-center">
												<button
													class="inline-flex items-center px-3 py-1 rounded-lg bg-blue-600 text-white text-[10px] font-bold hover:bg-blue-700 transition-all"
													on:click={() => openEditModal(payment)}
												>✏️ Edit</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<!-- Footer -->
						<div class="px-4 py-2 bg-slate-50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500">
							<span>Showing {startRecord}-{endRecord} of {totalRecords} records · Total: <strong class="text-emerald-700">{totalAmount.toLocaleString()}</strong></span>
							{#if totalPages > 1}
								<div class="flex items-center gap-2">
									<button
										class="px-2.5 py-1 bg-blue-600 text-white rounded-md text-[10px] font-bold hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-all"
										on:click={previousPage}
										disabled={currentPage === 1}
									>← Prev</button>
									<span class="text-slate-600 font-semibold">Page {currentPage} / {totalPages}</span>
									<button
										class="px-2.5 py-1 bg-blue-600 text-white rounded-md text-[10px] font-bold hover:bg-blue-700 disabled:bg-slate-300 disabled:cursor-not-allowed transition-all"
										on:click={nextPage}
										disabled={currentPage === totalPages}
									>Next →</button>
								</div>
							{/if}
						</div>
					</div>
				{:else}
					<div class="bg-white/40 rounded-2xl border border-slate-200 p-8 text-center mb-4">
						<p class="text-slate-400 text-sm">No payments found {selectedBranchId || selectedPaymentMethod ? 'matching the selected filters' : 'for this vendor'}.</p>
					</div>
				{/if}

				<!-- Vendor Expenses Table -->
				{#if filteredVendorExpenses.length > 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] overflow-hidden">
						<div class="overflow-x-auto">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-amber-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-amber-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Req #</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Category</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Branch</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Due Date</th>
										<th class="px-3 py-2.5 text-right text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Amount</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Method</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Requester</th>
										<th class="px-3 py-2.5 text-left text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Description</th>
										<th class="px-3 py-2.5 text-center text-[11px] font-black uppercase tracking-wider border-b-2 border-amber-400">Status</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredVendorExpenses as expense, index}
										<tr class="hover:bg-amber-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
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
						<div class="px-4 py-2 bg-slate-50 border-t border-slate-200 text-xs text-slate-500 font-semibold">
							{filteredVendorExpenses.length} expense{filteredVendorExpenses.length !== 1 ? 's' : ''} · Total: <strong class="text-red-600">{totalExpenseAmount.toLocaleString()}</strong>
						</div>
					</div>
				{/if}
			{/if}
		</div>
	{/if}

	<!-- Edit Modal -->
	{#if showEditModal && editingPayment}
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-interactive-supports-focus -->
		<div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" on:click={closeEditModal} on:keydown={e => e.key === 'Escape' && closeEditModal()} role="dialog" tabindex="-1">
			<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-noninteractive-element-interactions -->
			<div class="bg-white rounded-2xl shadow-2xl w-[90%] max-w-md" on:click|stopPropagation={() => {}} role="document">
				<div class="flex items-center justify-between px-5 py-4 border-b border-slate-200">
					<h2 class="text-base font-bold text-slate-800">Edit Payment Details</h2>
					<button class="w-7 h-7 flex items-center justify-center rounded-md text-slate-400 hover:bg-slate-100 hover:text-slate-800 transition" on:click={closeEditModal}>✕</button>
				</div>
				<div class="p-5 flex flex-col gap-4">
					<div class="flex flex-col gap-1">
						<label for="edit-due-date" class="text-xs font-bold text-slate-600 uppercase">Due Date</label>
						<input id="edit-due-date" type="date" bind:value={editFormData.due_date} class="px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
					</div>
					<div class="flex flex-col gap-1">
						<label for="edit-branch" class="text-xs font-bold text-slate-600 uppercase">Branch</label>
						<select id="edit-branch" bind:value={editFormData.branch_id} class="px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
							<option value="">Select Branch</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
							{/each}
						</select>
					</div>
					<div class="flex flex-col gap-1">
						<label for="edit-method" class="text-xs font-bold text-slate-600 uppercase">Payment Method</label>
						<select id="edit-method" bind:value={editFormData.payment_method} class="px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
							<option value="">Select Payment Method</option>
							{#each paymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>
				</div>
				<div class="flex justify-end gap-2 px-5 py-4 border-t border-slate-200">
					<button class="px-4 py-2 bg-slate-100 text-slate-700 rounded-lg text-sm font-semibold hover:bg-slate-200 transition disabled:opacity-50" on:click={closeEditModal} disabled={savingEdit}>Cancel</button>
					<button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700 transition disabled:opacity-50" on:click={saveEdit} disabled={savingEdit}>{savingEdit ? 'Saving...' : 'Save Changes'}</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- All styling handled by Tailwind utility classes -->
