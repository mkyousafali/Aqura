<script lang="ts">
	import { onMount } from 'svelte';

	let vendorTotal = 0;
	let expenseTotal = 0;
	let vendorTotalUnpaid = 0;
	let expenseTotalUnpaid = 0;
	let isLoading = true;
	let showVendorTable = false;
	let showExpenseTable = false;
	let vendorData: any[] = [];
	let expenseData: any[] = [];
	let loadingVendor = false;
	let loadingExpense = false;
	let vendorLoadingPercent = 0;
	let expenseLoadingPercent = 0;
	let branches: any[] = [];
	let selectedVendorBranch: number | null = null;
	let selectedExpenseBranch: number | null = null;
	let filteredVendorData: any[] = [];
	let filteredExpenseData: any[] = [];
	let editingVendorId: number | null = null;
	let editingVendorDate = '';
	let editingExpenseId: number | null = null;
	let editingExpenseDate = '';
	let vendorSearchQuery = '';

	onMount(async () => {
		await fetchOverduesData();
		await fetchBranches();
		isLoading = false;
	});

	async function fetchBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.eq('is_active', true)
				.order('name_en', { ascending: true });
			branches = data || [];
		} catch (err) {
			console.error('Error fetching branches:', err);
		}
	}

	async function fetchOverduesData() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const today = new Date();
			const fiveDaysFromNow = new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000);
			const dueDateLimit = fiveDaysFromNow.toISOString().split('T')[0];

			// Fetch vendor overdue data (due within 5 days)
			const vendorOverdueResponse = await supabase
				.from('vendor_payment_schedule')
				.select('final_bill_amount')
				.lte('due_date', dueDateLimit)
				.eq('is_paid', false);

			// Fetch vendor total unpaid (all unpaid regardless of due date)
			const vendorUnpaidResponse = await supabase
				.from('vendor_payment_schedule')
				.select('final_bill_amount')
				.eq('is_paid', false);

			// Fetch expense overdue data (due within 5 days)
			const expenseOverdueResponse = await supabase
				.from('expense_scheduler')
				.select('amount')
				.lte('due_date', dueDateLimit)
				.eq('is_paid', false);

			// Fetch expense total unpaid (all unpaid regardless of due date)
			const expenseUnpaidResponse = await supabase
				.from('expense_scheduler')
				.select('amount')
				.eq('is_paid', false);

			// Process vendor overdue data
			if (!vendorOverdueResponse.error && vendorOverdueResponse.data) {
				vendorTotal = vendorOverdueResponse.data.reduce((sum, item) => sum + (item.final_bill_amount || 0), 0);
			}

			// Process vendor total unpaid
			if (!vendorUnpaidResponse.error && vendorUnpaidResponse.data) {
				vendorTotalUnpaid = vendorUnpaidResponse.data.reduce((sum, item) => sum + (item.final_bill_amount || 0), 0);
			}

			// Process expense overdue data
			if (!expenseOverdueResponse.error && expenseOverdueResponse.data) {
				expenseTotal = expenseOverdueResponse.data.reduce((sum, item) => sum + (item.amount || 0), 0);
			}

			// Process expense total unpaid
			if (!expenseUnpaidResponse.error && expenseUnpaidResponse.data) {
				expenseTotalUnpaid = expenseUnpaidResponse.data.reduce((sum, item) => sum + (item.amount || 0), 0);
			}
		} catch (err) {
			console.error('Error fetching overdues data:', err);
		}
	}

	async function loadVendorTable() {
		loadingVendor = true;
		vendorLoadingPercent = 0;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const today = new Date();
			const fiveDaysFromNow = new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000);
			const dueDateLimit = fiveDaysFromNow.toISOString().split('T')[0];

		vendorLoadingPercent = 25;

		const { data: vendorPayments, error: vendorError } = await supabase
			.from('vendor_payment_schedule')
			.select('id, vendor_name, final_bill_amount, due_date, is_paid, bill_date, branch_id, payment_method')
			.lte('due_date', dueDateLimit)
			.eq('is_paid', false)
			.order('due_date', { ascending: true })
			.limit(1000);

		vendorLoadingPercent = 50;

		// Fetch branch names for vendor payments
		if (!vendorError && vendorPayments && vendorPayments.length > 0) {
			const branchIds = [...new Set(vendorPayments.map(v => v.branch_id))];
			const { data: branches } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.in('id', branchIds);

			vendorLoadingPercent = 75;

			const branchMap = new Map(branches?.map(b => [`${b.id}`, `${b.name_en} - ${b.location_en}`]) || []);
			vendorData = vendorPayments
				.filter(row => parseFloat(row.final_bill_amount) >= 0.01)
				.map(row => ({
					...row,
					branch_name: branchMap.get(`${row.branch_id}`) || 'N/A'
				}));
			filteredVendorData = vendorData;
			vendorLoadingPercent = 100;
			showVendorTable = true;
		}
		} catch (err) {
			console.error('Error loading vendor table:', err);
		} finally {
			loadingVendor = false;
		}
	}

	async function loadExpenseTable() {
		loadingExpense = true;
		expenseLoadingPercent = 0;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const today = new Date();
			const fiveDaysFromNow = new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000);
			const dueDateLimit = fiveDaysFromNow.toISOString().split('T')[0];

			expenseLoadingPercent = 25;

		const { data: expenseSchedules, error } = await supabase
			.from('expense_scheduler')
			.select('id, description, amount, due_date, is_paid, payment_method, branch_id, expense_category_name_en')
			.lte('due_date', dueDateLimit)
			.eq('is_paid', false)
			.order('due_date', { ascending: true })
			.limit(1000);

		expenseLoadingPercent = 50;

		if (!error && expenseSchedules && expenseSchedules.length > 0) {
			const branchIds = [...new Set(expenseSchedules.map(e => e.branch_id))];
			const { data: branches } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.in('id', branchIds);

			expenseLoadingPercent = 75;

			const branchMap = new Map(branches?.map(b => [`${b.id}`, `${b.name_en} - ${b.location_en}`]) || []);
			expenseData = expenseSchedules
				.filter(row => parseFloat(row.amount) >= 0.01)
				.map(row => ({
					...row,
					branch_name: branchMap.get(`${row.branch_id}`) || 'N/A'
				}));
				filteredExpenseData = expenseData;
				expenseLoadingPercent = 100;
				showExpenseTable = true;
			}
		} catch (err) {
			console.error('Error loading expense table:', err);
		} finally {
			loadingExpense = false;
		}
	}

	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount);
	}

	function formatDate(dateStr: string): string {
		const date = new Date(dateStr);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}/${month}/${year}`;
	}

	function getStatusDisplay(isPaid: boolean): string {
		return isPaid ? 'Paid' : 'Unpaid';
	}

	async function updateVendorDueDate(id: number, newDate: string) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ due_date: newDate })
				.eq('id', id);

			if (!error) {
				// Update local data
				const index = vendorData.findIndex(row => row.id === id);
				if (index !== -1) {
					vendorData[index].due_date = newDate;
					vendorData = [...vendorData];
				}
				editingVendorId = null;
			} else {
				console.error('Error updating vendor due date:', error);
				alert('Failed to update due date');
			}
		} catch (err) {
			console.error('Error updating vendor due date:', err);
			alert('Error updating due date');
		}
	}

	async function updateExpenseDueDate(id: number, newDate: string) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ due_date: newDate })
				.eq('id', id);

			if (!error) {
				// Update local data
				const index = expenseData.findIndex(row => row.id === id);
				if (index !== -1) {
					expenseData[index].due_date = newDate;
					expenseData = [...expenseData];
				}
				editingExpenseId = null;
			} else {
				console.error('Error updating expense due date:', error);
				alert('Failed to update due date');
			}
		} catch (err) {
			console.error('Error updating expense due date:', err);
			alert('Error updating due date');
		}
	}

	async function exportToExcel(data: any[], filename: string, tableType: 'vendor' | 'expense') {
		try {
			const XLSX = await import('xlsx');
			
			let exportData: any[] = [];
			if (tableType === 'vendor') {
				exportData = data.map(row => ({
					'Vendor Name': row.vendor_name || 'N/A',
					'Branch': row.branch_name || 'N/A',
					'Bill Date': formatDate(row.bill_date || ''),
					'Amount': row.final_bill_amount || 0,
					'Due Date': formatDate(row.due_date || ''),
					'Payment Method': row.payment_method || 'N/A',
					'Status': getStatusDisplay(row.is_paid)
				}));
			} else {
				exportData = data.map(row => ({
					'Description': row.description || 'N/A',
					'Category': row.expense_category_name_en || 'N/A',
					'Branch': row.branch_name || 'N/A',
					'Amount': row.amount || 0,
					'Due Date': formatDate(row.due_date || ''),
					'Payment Method': row.payment_method || 'N/A',
					'Status': getStatusDisplay(row.is_paid)
				}));
			}

			const ws = XLSX.utils.json_to_sheet(exportData);
			const wb = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(wb, ws, 'Data');
			XLSX.writeFile(wb, `${filename}.xlsx`);
		} catch (err) {
			console.error('Error exporting to Excel:', err);
			alert('Failed to export to Excel');
		}
	}

	// Filter vendor data based on selected branch and search query
	$: {
		let filtered = vendorData.filter(row => parseFloat(row.final_bill_amount) >= 0.01);
		if (selectedVendorBranch) {
			filtered = filtered.filter(row => row.branch_id === selectedVendorBranch);
		}
		if (vendorSearchQuery.trim()) {
			const q = vendorSearchQuery.trim().toLowerCase();
			filtered = filtered.filter(row => (row.vendor_name || '').toLowerCase().includes(q));
		}
		filteredVendorData = filtered;
	}

	// Filter expense data based on selected branch
	$: {
		if (selectedExpenseBranch) {
			filteredExpenseData = expenseData.filter(row => 
				row.branch_id === selectedExpenseBranch && parseFloat(row.amount) >= 0.01
			);
		} else {
			filteredExpenseData = expenseData.filter(row => parseFloat(row.amount) >= 0.01);
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header/Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
				{showVendorTable 
					? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => {
					showVendorTable = !showVendorTable;
					if (showVendorTable) {
						showExpenseTable = false;
						if (vendorData.length === 0) {
							loadVendorTable();
						}
					}
				}} 
				disabled={loadingVendor}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">
					{#if loadingVendor}⏳{:else}📊{/if}
				</span>
				<span class="relative z-10">
					{#if loadingVendor}Loading {vendorLoadingPercent}%{:else}Vendor{/if}
				</span>
				{#if showVendorTable}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
				{showExpenseTable 
					? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => {
					showExpenseTable = !showExpenseTable;
					if (showExpenseTable) {
						showVendorTable = false;
						if (expenseData.length === 0) {
							loadExpenseTable();
						}
					}
				}} 
				disabled={loadingExpense}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">
					{#if loadingExpense}⏳{:else}💸{/if}
				</span>
				<span class="relative z-10">
					{#if loadingExpense}Loading {expenseLoadingPercent}%{:else}Expense{/if}
				</span>
				{#if showExpenseTable}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
		</div>
		<div class="flex items-center gap-6">
			<div class="text-right">
				<p class="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Vendor Due</p>
				<p class="text-lg font-black text-blue-700">{formatCurrency(vendorTotal)}</p>
			</div>
			<div class="text-right">
				<p class="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Expense Due</p>
				<p class="text-lg font-black text-orange-700">{formatCurrency(expenseTotal)}</p>
			</div>
		</div>
	</div>

	{#if isLoading}
		<div class="flex items-center justify-center h-full">
			<div class="text-center">
				<div class="animate-spin inline-block">
					<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
				</div>
				<p class="mt-4 text-slate-600 font-semibold">Loading overdues data...</p>
			</div>
		</div>
	{:else}
		<!-- Main Content Area -->
		<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
			<!-- Futuristic background decorative elements -->
			<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
			<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

			<div class="relative max-w-[99%] mx-auto h-full flex flex-col">

		<!-- Vendor Table -->
		{#if showVendorTable}
			<!-- Filter Controls -->
			<div class="mb-4 flex gap-3">
				<div class="flex-1">
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="vendor-search">Search Vendor</label>
					<input
						id="vendor-search"
						type="text"
						placeholder="Search vendor name..."
						bind:value={vendorSearchQuery}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						style="color: #000000 !important; background-color: #ffffff !important;"
					/>
				</div>
				<div class="flex-1">
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="vendor-branch">Filter Branch</label>
					<select id="vendor-branch" bind:value={selectedVendorBranch} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all" style="color: #000000 !important; background-color: #ffffff !important;">
						<option value={null} style="color: #000000 !important; background-color: #ffffff !important;">All Branches</option>
						{#each branches as branch}
							<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">{branch.name_en} - {branch.location_en}</option>
						{/each}
					</select>
				</div>
				<div class="flex flex-col items-center justify-end">
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filtered Total</label>
					<span class="px-4 py-2.5 bg-blue-600 text-white rounded-xl font-black text-sm">
						{formatCurrency(filteredVendorData.reduce((sum, r) => sum + (r.final_bill_amount || 0), 0))}
					</span>
				</div>
				<div class="flex items-end">
					<button 
						on:click={() => exportToExcel(filteredVendorData, 'Vendor_Overdue', 'vendor')}
						class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold text-sm transition-all duration-200 hover:shadow-lg transform hover:scale-105"
					>
						<span>📥</span>
						<span>Export</span>
					</button>
				</div>
			</div>

			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col mb-8">
				<!-- Table Wrapper -->
				<div class="overflow-x-auto flex-1 max-h-[60vh]">
					<table class="w-full border-collapse text-sm table-fixed [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
						<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
							<tr>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Vendor Name</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Branch</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Bill Date</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Amount</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Due Date</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Payment Method</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-1/7">Status</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-slate-200">
						{#each filteredVendorData as row, index (row.id)}
							<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
								<td class="px-4 py-3 text-slate-900 w-1/7">{row.vendor_name || 'N/A'}</td>
								<td class="px-4 py-3 text-slate-700 w-1/7">{row.branch_name || 'N/A'}</td>
								<td class="px-4 py-3 text-slate-700 w-1/7">{formatDate(row.bill_date || '')}</td>
								<td class="px-4 py-3 text-slate-900 font-semibold w-1/7">{formatCurrency(row.final_bill_amount || 0)}</td>
								<td class="px-4 py-3 cursor-pointer hover:bg-blue-50 rounded transition-colors w-1/7" on:dblclick={() => {
									editingVendorId = row.id;
									editingVendorDate = row.due_date || '';
								}}>
									{#if editingVendorId === row.id}
										<input 
											type="date" 
											bind:value={editingVendorDate}
											on:blur={() => {
												if (editingVendorDate && editingVendorDate !== row.due_date) {
													updateVendorDueDate(row.id, editingVendorDate);
												} else {
													editingVendorId = null;
												}
											}}
											on:keydown={(e) => {
												if (e.key === 'Enter') {
													updateVendorDueDate(row.id, editingVendorDate);
												} else if (e.key === 'Escape') {
													editingVendorId = null;
												}
											}}
											autoFocus
											class="w-full px-2 py-1 border-2 border-blue-500 rounded focus:outline-none"
										/>
									{:else}
										<span class="text-slate-700">{formatDate(row.due_date || '')}</span>
									{/if}
								</td>
								<td class="px-4 py-3 text-slate-700 w-1/7">{row.payment_method || 'N/A'}</td>
								<td class="px-4 py-3 w-1/7">
									<span class={`px-2 py-1 rounded-full text-xs font-semibold ${row.is_paid ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
										{getStatusDisplay(row.is_paid)}
									</span>
								</td>
							</tr>
						{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}

		<!-- Expense Table -->
		{#if showExpenseTable}
			<!-- Filter Controls -->
			<div class="mb-4 flex gap-3">
				<div class="flex-1">
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="expense-branch">Filter Branch</label>
					<select id="expense-branch" bind:value={selectedExpenseBranch} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all" style="color: #000000 !important; background-color: #ffffff !important;">
						<option value={null} style="color: #000000 !important; background-color: #ffffff !important;">All Branches</option>
						{#each branches as branch}
							<option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">{branch.name_en} - {branch.location_en}</option>
						{/each}
					</select>
				</div>
				<div class="flex flex-col items-center justify-end">
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filtered Total</label>
					<span class="px-4 py-2.5 bg-orange-600 text-white rounded-xl font-black text-sm">
						{formatCurrency(filteredExpenseData.reduce((sum, r) => sum + (r.amount || 0), 0))}
					</span>
				</div>
				<div class="flex items-end">
					<button 
						on:click={() => exportToExcel(filteredExpenseData, 'Expense_Overdue', 'expense')}
						class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold text-sm transition-all duration-200 hover:shadow-lg transform hover:scale-105"
					>
						<span>📥</span>
						<span>Export</span>
					</button>
				</div>
			</div>

			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
				<!-- Table Wrapper -->
				<div class="overflow-x-auto flex-1 max-h-[60vh]">
					<table class="w-full border-collapse text-sm table-fixed [&_th]:border-x [&_th]:border-orange-500/30 [&_td]:border-x [&_td]:border-slate-200">
						<thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
							<tr>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Description</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Category</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Branch</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Amount</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Due Date</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Payment Method</th>
								<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 w-1/7">Status</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-slate-200">
						{#each filteredExpenseData as row, index (row.id)}
							<tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
							<td class="px-4 py-3 text-slate-900 w-1/7">{row.description || 'N/A'}</td>
							<td class="px-4 py-3 text-slate-700 w-1/7">{row.expense_category_name_en || 'N/A'}</td>
							<td class="px-4 py-3 text-slate-700 w-1/7">{row.branch_name || 'N/A'}</td>
							<td class="px-4 py-3 text-slate-900 font-semibold w-1/7">{formatCurrency(row.amount || 0)}</td>
							<td class="px-4 py-3 cursor-pointer hover:bg-blue-50 rounded transition-colors w-1/7" on:dblclick={() => {
									editingExpenseId = row.id;
									editingExpenseDate = row.due_date || '';
								}}>
									{#if editingExpenseId === row.id}
										<input 
											type="date" 
											bind:value={editingExpenseDate}
											on:blur={() => {
												if (editingExpenseDate && editingExpenseDate !== row.due_date) {
													updateExpenseDueDate(row.id, editingExpenseDate);
												} else {
													editingExpenseId = null;
												}
											}}
											on:keydown={(e) => {
												if (e.key === 'Enter') {
													updateExpenseDueDate(row.id, editingExpenseDate);
												} else if (e.key === 'Escape') {
													editingExpenseId = null;
												}
											}}
											autoFocus
											class="w-full px-2 py-1 border-2 border-blue-500 rounded focus:outline-none"
										/>
									{:else}
										<span class="text-slate-700">{formatDate(row.due_date || '')}</span>
									{/if}
								</td>
							<td class="px-4 py-3 text-slate-700 w-1/7">{row.payment_method || 'N/A'}</td>
							<td class="px-4 py-3 w-1/7">
									<span class={`px-2 py-1 rounded-full text-xs font-semibold ${row.is_paid ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
										{getStatusDisplay(row.is_paid)}
									</span>
								</td>
							</tr>
						{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.tracking-fast {
		letter-spacing: 0.05em;
	}

	/* Animate in effects */
	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	@keyframes scaleIn {
		from {
			opacity: 0;
			transform: scale(0.95);
		}
		to {
			opacity: 1;
			transform: scale(1);
		}
	}

	.animate-in {
		animation: fadeIn 0.2s ease-out;
	}

	.scale-in {
		animation: scaleIn 0.3s ease-out;
	}
</style>
