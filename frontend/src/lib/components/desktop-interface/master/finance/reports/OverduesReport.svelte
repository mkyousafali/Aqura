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

	// Filter vendor data based on selected branch
	$: {
		if (selectedVendorBranch) {
			filteredVendorData = vendorData.filter(row => 
				row.branch_id === selectedVendorBranch && parseFloat(row.final_bill_amount) >= 0.01
			);
		} else {
			filteredVendorData = vendorData.filter(row => parseFloat(row.final_bill_amount) >= 0.01);
		}
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
	{#if isLoading}
		<div class="flex flex-col items-center justify-center h-full gap-5">
			<div class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin"></div>
			<p class="text-slate-600 font-medium">Loading overdues data...</p>
		</div>
	{:else}
		<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
			<!-- Cards Container with Glass Morphism -->
			<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
				<!-- Vendor Overdue Card -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
					<!-- Header with Button -->
					<div class="px-6 py-2 border-b border-slate-200 flex items-center justify-between gap-3">
						<button 
							class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
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
							{#if loadingVendor}
								<span>⏳</span>
								<span>Loading {vendorLoadingPercent}%</span>
							{:else if showVendorTable}
								<span>👁️</span>
								<span>Vendor</span>
							{:else}
								<span>📊</span>
								<span>Vendor</span>
							{/if}
						</button>
						<div class="text-right">
							<p class="text-xs text-slate-600 font-medium">Total Due</p>
							<p class="text-lg font-bold text-slate-900">{formatCurrency(vendorTotal)}</p>
						</div>
					</div>
				</div>

				<!-- Expense Overdue Card -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden">
					<!-- Header with Button -->
					<div class="px-6 py-2 border-b border-slate-200 flex items-center justify-between gap-3">
						<button 
							class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
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
							{#if loadingExpense}
								<span>⏳</span>
								<span>Loading {expenseLoadingPercent}%</span>
							{:else if showExpenseTable}
								<span>👁️</span>
								<span>Expense</span>
							{:else}
								<span>💸</span>
								<span>Expense</span>
							{/if}
						</button>
						<div class="text-right">
							<p class="text-xs text-slate-600 font-medium">Total Due</p>
							<p class="text-lg font-bold text-slate-900">{formatCurrency(expenseTotal)}</p>
						</div>
					</div>
				</div>
			</div>

		<!-- Vendor Table -->
		{#if showVendorTable}
			<div class="bg-white rounded-lg shadow-md border border-slate-200 mb-8">
				<div class="sticky top-0 z-20 bg-white border-b border-slate-200">
					<div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 p-6 pb-4">
						<h3 class="text-lg font-semibold text-slate-900">Vendor Overdue Details</h3>
					<div class="flex items-center justify-between gap-4">
						<div class="flex items-center gap-2">
							<label for="vendor-branch" class="text-sm font-medium text-slate-700">Filter by Branch:</label>
							<select id="vendor-branch" bind:value={selectedVendorBranch} class="px-3 py-2 bg-white border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent">
								<option value={null}>All Branches</option>
								{#each branches as branch}
									<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
								{/each}
							</select>
						</div>
						<button 
							on:click={() => exportToExcel(filteredVendorData, 'Vendor_Overdue', 'vendor')}
							class="inline-flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium text-sm transition-all duration-200 hover:shadow-md"
						>
							<span>📥</span>
							<span>Export to Excel</span>
						</button>
						</div>
					</div>
					<table class="w-full text-sm table-fixed">
						<thead class="bg-slate-50 shadow-sm">
							<tr class="border-b border-slate-200">
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Vendor Name</th>
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Branch</th>
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Bill Date</th>
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Amount</th>
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Due Date</th>
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Payment Method</th>
								<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Status</th>
							</tr>
						</thead>
					</table>
				</div>
				<div class="overflow-x-auto max-h-[60vh]">
					<table class="w-full text-sm table-fixed">
						<tbody>
						{#each filteredVendorData as row (row.id)}
							<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
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
			<div class="bg-white rounded-lg shadow-md border border-slate-200">
				<div class="sticky top-0 z-20 bg-white border-b border-slate-200">
					<div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 p-6 pb-4">
						<h3 class="text-lg font-semibold text-slate-900">Expense Overdue Details</h3>
						<div class="flex items-center justify-between gap-4">
							<div class="flex items-center gap-2">
								<label for="expense-branch" class="text-sm font-medium text-slate-700">Filter by Branch:</label>
								<select id="expense-branch" bind:value={selectedExpenseBranch} class="px-3 py-2 bg-white border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent">
									<option value={null}>All Branches</option>
									{#each branches as branch}
										<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
									{/each}
								</select>
							</div>
							<button 
								on:click={() => exportToExcel(filteredExpenseData, 'Expense_Overdue', 'expense')}
								class="inline-flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium text-sm transition-all duration-200 hover:shadow-md"
							>
								<span>📥</span>
								<span>Export to Excel</span>
							</button>
						</div>
					</div>
					<table class="w-full text-sm table-fixed">
						<thead class="bg-slate-50 shadow-sm">
							<tr class="border-b border-slate-200">
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Description</th>
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Category</th>
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Branch</th>
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Amount</th>
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Due Date</th>
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Payment Method</th>
							<th class="px-4 py-3 text-left font-semibold text-slate-700 w-1/7">Status</th>
							</tr>
						</thead>
					</table>
				</div>
				<div class="overflow-x-auto max-h-[60vh]">
					<table class="w-full text-sm table-fixed">
						<tbody>
						{#each filteredExpenseData as row (row.id)}
							<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
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
	{/if}
</div>

<style>
	:global(body) {
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
	}

	/* Spinner animation */
	:global(.animate-spin) {
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	/* Smooth transitions */
	:global(.transition-colors) {
		transition-property: background-color, border-color, color;
		transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
		transition-duration: 200ms;
	}

	:global(.transition-shadow) {
		transition-property: box-shadow;
		transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
		transition-duration: 200ms;
	}

	:global(.transition-all) {
		transition-property: all;
		transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
		transition-duration: 200ms;
	}
</style>
