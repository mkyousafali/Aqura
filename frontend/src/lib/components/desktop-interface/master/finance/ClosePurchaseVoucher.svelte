<script>
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { onMount } from 'svelte';

	export let autoFilterSerial = '';
	export let autoFilterValue = '';

	let issuedVouchers = [];
	let filteredVouchers = [];
	let isLoading = false;
	let branches = [];
	let selectedVouchers = new Set();
	let showCloseModal = false;
	let selectedVoucherForModal = null;
	let closeBillNumber = '';
	let closeRemarks = '';
	let isClosing = false;
	let expenseCategories = [];
	let selectedExpenseCategoryId = null;
	let expenseCategorySearch = '';
	let showCategoryDropdown = false;
	
	// Filtered expense categories based on search
	$: filteredExpenseCategories = expenseCategories.filter(cat => {
		if (!expenseCategorySearch.trim()) return true;
		const search = expenseCategorySearch.toLowerCase();
		return cat.name_en.toLowerCase().includes(search) || 
		       cat.name_ar.toLowerCase().includes(search);
	});
	
	// Get selected category display name
	$: selectedCategoryDisplay = selectedExpenseCategoryId 
		? expenseCategories.find(c => c.id === selectedExpenseCategoryId)
		: null;
	
	// Filter states
	let filterPVId = '';
	let filterSerialNumber = '';
	let filterValue = '';
	let filterIssuedTo = '';
	let filterApprovalStatus = '';

	// Unique filter options
	$: uniquePVIds = [...new Set(issuedVouchers.map(v => v.purchase_voucher_id))].sort();
	$: uniqueValues = [...new Set(issuedVouchers.map(v => v.value))].sort((a, b) => a - b);
	$: uniqueIssuedTo = [...new Set(issuedVouchers.map(v => v.issued_to).filter(Boolean))];
	$: uniqueApprovalStatuses = [...new Set(issuedVouchers.map(v => v.approval_status || 'none'))];

	// Apply filters reactively
	$: {
		filteredVouchers = issuedVouchers.filter(voucher => {
			if (filterPVId && voucher.purchase_voucher_id !== filterPVId) return false;
			if (filterSerialNumber && !voucher.serial_number.toString().includes(filterSerialNumber)) return false;
			if (filterValue && voucher.value !== parseFloat(filterValue)) return false;
			if (filterIssuedTo && voucher.issued_to !== filterIssuedTo) return false;
			if (filterApprovalStatus) {
				const voucherStatus = voucher.approval_status || 'none';
				if (voucherStatus !== filterApprovalStatus) return false;
			}
			return true;
		});
	}

	onMount(async () => {
		await loadAllData();

		// Auto-apply filters if provided
		if (autoFilterSerial) filterSerialNumber = autoFilterSerial;
		if (autoFilterValue) filterValue = autoFilterValue;
	});

	async function loadAllData() {
		isLoading = true;
		try {
			const { data, error } = await supabase.rpc('get_close_purchase_voucher_data');
			if (error) {
				console.error('Error loading close voucher data:', error);
				return;
			}

			issuedVouchers = data?.vouchers || [];
			branches = data?.branches || [];
			expenseCategories = data?.expense_categories || [];
			console.log(`📋 Loaded ${issuedVouchers.length} vouchers, ${branches.length} branches, ${expenseCategories.length} categories via RPC`);
		} catch (error) {
			console.error('Error:', error);
		} finally {
			isLoading = false;
		}
	}

	function toggleSelectVoucher(id) {
		if (selectedVouchers.has(id)) {
			selectedVouchers.delete(id);
		} else {
			selectedVouchers.add(id);
		}
		selectedVouchers = selectedVouchers;
	}

	function toggleSelectAll() {
		if (selectedVouchers.size === filteredVouchers.length) {
			selectedVouchers.clear();
		} else {
			selectedVouchers = new Set(filteredVouchers.map(v => v.id));
		}
		selectedVouchers = selectedVouchers;
	}

	async function handleCloseSelected() {
		if (selectedVouchers.size === 0) {
			alert('Please select at least one voucher to close');
			return;
		}

		const confirmMsg = `Are you sure you want to close ${selectedVouchers.size} voucher(s)?`;
		if (!confirm(confirmMsg)) return;

		isLoading = true;
		try {
			const voucherIds = Array.from(selectedVouchers);
			const { error } = await supabase
				.from('purchase_voucher_items')
				.update({
					status: 'closed',
					closed_date: new Date().toISOString()
				})
				.in('id', voucherIds);

			if (error) {
				console.error('Error closing vouchers:', error);
				alert('Error closing vouchers: ' + error.message);
			} else {
				alert(`Successfully closed ${selectedVouchers.size} voucher(s)`);
				selectedVouchers.clear();
				await loadAllData();
			}
		} catch (error) {
			console.error('Error:', error);
			alert('Error closing vouchers');
		} finally {
			isLoading = false;
		}
	}

	function clearFilters() {
		filterPVId = '';
		filterSerialNumber = '';
		filterValue = '';
		filterIssuedTo = '';
		filterApprovalStatus = '';
	}

	function openCloseModal(voucher) {
		selectedVoucherForModal = voucher;
		closeBillNumber = '';
		closeRemarks = '';
		selectedExpenseCategoryId = null;
		expenseCategorySearch = '';
		showCategoryDropdown = false;
		showCloseModal = true;
	}

	function closeModal() {
		showCloseModal = false;
		selectedVoucherForModal = null;
		closeBillNumber = '';
		closeRemarks = '';
		selectedExpenseCategoryId = null;
		expenseCategorySearch = '';
		showCategoryDropdown = false;
	}

	function selectExpenseCategory(category) {
		selectedExpenseCategoryId = category.id;
		expenseCategorySearch = '';
		showCategoryDropdown = false;
	}

	function clearSelectedCategory() {
		selectedExpenseCategoryId = null;
		expenseCategorySearch = '';
	}

	async function handleSaveClose() {
		if (!selectedVoucherForModal) return;
		
		const issueType = selectedVoucherForModal.issue_type;
		
		if (issueType === 'sales' && !closeBillNumber.trim()) {
			alert('Please enter the close bill number');
			return;
		}
		
		if (issueType === 'gift') {
			if (!selectedExpenseCategoryId) {
				alert('Please select an expense category');
				return;
			}
			if (!closeBillNumber.trim()) {
				alert('Please enter the close bill number');
				return;
			}
		}
		
		isClosing = true;
		try {
			const updateData = {
				status: 'closed',
				closed_date: new Date().toISOString(),
				close_bill_number: closeBillNumber.trim() || null,
				close_remarks: closeRemarks.trim() || null
			};
			
			const { error } = await supabase
				.from('purchase_voucher_items')
				.update(updateData)
				.eq('id', selectedVoucherForModal.id);
			
			if (error) {
				console.error('Error closing voucher:', error);
				alert('Error closing voucher: ' + error.message);
				return;
			}
			
			if (issueType === 'gift') {
				if (!$currentUser?.id) {
					alert('Error: Unable to get current user. Please log in again.');
					return;
				}
				
				const selectedCategory = expenseCategories.find(c => c.id === selectedExpenseCategoryId);
				const branch = branches.find(b => b.id === selectedVoucherForModal.stock_location);
				
				const expenseData = {
					branch_id: selectedVoucherForModal.stock_location,
					branch_name: branch ? `${branch.name_en} - ${branch.location_en}` : 'Unknown Branch',
					expense_category_id: selectedExpenseCategoryId,
					expense_category_name_en: selectedCategory?.name_en || null,
					expense_category_name_ar: selectedCategory?.name_ar || null,
					co_user_id: $currentUser.id,
					co_user_name: $currentUser.username || 'Unknown User',
					bill_type: 'purchase_voucher_gift',
					bill_number: closeBillNumber.trim(),
					bill_date: new Date().toISOString().split('T')[0],
					payment_method: 'redemption',
					amount: selectedVoucherForModal.value,
					description: `Gift Purchase Voucher - ${selectedVoucherForModal.purchase_voucher_id} - Serial: ${selectedVoucherForModal.serial_number}`,
					notes: closeRemarks.trim() || null,
					is_paid: true,
					paid_date: new Date().toISOString(),
					status: 'completed',
					created_by: $currentUser.id,
					schedule_type: 'single_bill',
					due_date: new Date().toISOString().split('T')[0]
				};
				
				const { error: expenseError } = await supabase
					.from('expense_scheduler')
					.insert(expenseData);
				
				if (expenseError) {
					console.error('Error creating expense record:', expenseError);
					alert('Voucher closed but failed to create expense record: ' + expenseError.message);
					closeModal();
					await loadAllData();
					return;
				}
			}
			
			alert('Voucher closed successfully');
			closeModal();
			await loadAllData();
		} catch (error) {
			console.error('Error:', error);
			alert('Error closing voucher');
		} finally {
			isClosing = false;
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">🔒</span>
			<div>
				<h2 class="text-base font-black text-slate-800 uppercase tracking-wide">Close Purchase Vouchers</h2>
				<p class="text-[11px] text-slate-500">Select issued vouchers to close</p>
			</div>
		</div>
		<div class="flex gap-2">
			<button
				class="group flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-slate-200 text-slate-700 hover:bg-slate-300 hover:shadow-md"
				on:click={loadAllData}
			>
				<span class="text-base transition-transform duration-500 group-hover:rotate-180">🔄</span>
				<span>Refresh</span>
			</button>
			{#if selectedVouchers.size > 0}
				<button
					class="group flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-rose-600 text-white shadow-lg shadow-rose-200 hover:bg-rose-700 hover:shadow-xl hover:scale-[1.02]"
					on:click={handleCloseSelected}
				>
					<span class="text-base">🔒</span>
					<span>Close {selectedVouchers.size} Selected</span>
				</button>
			{/if}
		</div>
	</div>

	<!-- Main Content -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-rose-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-purple-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">

			{#if isLoading}
				<div class="flex items-center justify-center flex-1">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-rose-200 border-t-rose-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">Loading vouchers...</p>
					</div>
				</div>

			{:else if issuedVouchers.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex-1 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📭</div>
					<p class="text-slate-600 font-semibold">No issued vouchers found</p>
					<p class="text-sm text-slate-400 mt-1">Only vouchers with status "issued" can be closed</p>
				</div>

			{:else}
				<!-- Stats Cards -->
				<div class="grid grid-cols-6 gap-3 mb-4">
					<div class="bg-white/50 backdrop-blur-sm rounded-2xl border border-slate-200 p-4 text-center">
						<div class="text-[11px] font-bold uppercase tracking-wide text-slate-500 mb-1">Total Issued</div>
						<div class="text-2xl font-black text-slate-800">{issuedVouchers.length}</div>
					</div>
					<div class="bg-emerald-500/10 backdrop-blur-sm rounded-2xl border border-emerald-200 p-4 text-center">
						<div class="text-[11px] font-bold uppercase tracking-wide text-emerald-600 mb-1">Approved</div>
						<div class="text-2xl font-black text-emerald-700">{issuedVouchers.filter(v => v.approval_status === 'approved' || !v.approval_status).length}</div>
					</div>
					<div class="bg-amber-500/10 backdrop-blur-sm rounded-2xl border border-amber-200 p-4 text-center">
						<div class="text-[11px] font-bold uppercase tracking-wide text-amber-600 mb-1">Pending</div>
						<div class="text-2xl font-black text-amber-700">{issuedVouchers.filter(v => v.approval_status === 'pending').length}</div>
					</div>
					<div class="bg-red-500/10 backdrop-blur-sm rounded-2xl border border-red-200 p-4 text-center">
						<div class="text-[11px] font-bold uppercase tracking-wide text-red-600 mb-1">Rejected</div>
						<div class="text-2xl font-black text-red-700">{issuedVouchers.filter(v => v.approval_status === 'rejected').length}</div>
					</div>
					<div class="bg-white/50 backdrop-blur-sm rounded-2xl border border-slate-200 p-4 text-center">
						<div class="text-[11px] font-bold uppercase tracking-wide text-slate-500 mb-1">Filtered</div>
						<div class="text-2xl font-black text-slate-800">{filteredVouchers.length}</div>
					</div>
					<div class="bg-purple-500/10 backdrop-blur-sm rounded-2xl border border-purple-200 p-4 text-center">
						<div class="text-[11px] font-bold uppercase tracking-wide text-purple-600 mb-1">Selected</div>
						<div class="text-2xl font-black text-purple-700">{selectedVouchers.size}</div>
					</div>
				</div>

				<!-- Filters Row -->
				<div class="mb-4 grid grid-cols-6 gap-3">
					<div>
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="cpv-filterPVId">PV ID</label>
						<select id="cpv-filterPVId" bind:value={filterPVId}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;">
							<option value="" style="color: #000 !important;">All</option>
							{#each uniquePVIds as pvId}
								<option value={pvId} style="color: #000 !important;">{pvId}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="cpv-filterSerial">Serial #</label>
						<input
							id="cpv-filterSerial"
							type="text"
							placeholder="Search serial..."
							bind:value={filterSerialNumber}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
						/>
					</div>
					<div>
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="cpv-filterValue">Value</label>
						<select id="cpv-filterValue" bind:value={filterValue}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;">
							<option value="" style="color: #000 !important;">All</option>
							{#each uniqueValues as val}
								<option value={val} style="color: #000 !important;">{val}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="cpv-filterIssuedTo">Issued To</label>
						<select id="cpv-filterIssuedTo" bind:value={filterIssuedTo}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;">
							<option value="" style="color: #000 !important;">All</option>
							{#each uniqueIssuedTo as userId}
								<option value={userId} style="color: #000 !important;">{issuedVouchers.find(v => v.issued_to === userId)?.issued_to_name || userId}</option>
							{/each}
						</select>
					</div>
					<div>
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="cpv-filterApproval">Approval</label>
						<select id="cpv-filterApproval" bind:value={filterApprovalStatus}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
							style="color: #000 !important; background-color: #fff !important;">
							<option value="" style="color: #000 !important;">All</option>
							<option value="approved" style="color: #000 !important;">Approved</option>
							<option value="pending" style="color: #000 !important;">Pending</option>
							<option value="rejected" style="color: #000 !important;">Rejected</option>
							<option value="none" style="color: #000 !important;">No Approval</option>
						</select>
					</div>
					<div class="flex items-end">
						<button
							class="w-full px-4 py-2.5 text-xs font-black uppercase tracking-wide bg-slate-200 text-slate-600 rounded-xl hover:bg-slate-300 transition-all"
							on:click={clearFilters}
						>Clear Filters</button>
					</div>
				</div>

				<!-- Table Card -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<div class="overflow-auto flex-1">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-rose-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 bg-rose-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400 w-10">
										<input
											type="checkbox"
											checked={selectedVouchers.size === filteredVouchers.length && filteredVouchers.length > 0}
											on:change={toggleSelectAll}
											class="w-4 h-4 cursor-pointer rounded accent-rose-300"
										/>
									</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">PV ID</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Serial #</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Value</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Issue Type</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Location</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Issued By</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Issued To</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Date</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Approval</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Remarks</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-rose-400">Action</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each filteredVouchers as voucher, index (voucher.id)}
									<tr class="transition-colors duration-200 {selectedVouchers.has(voucher.id) ? 'bg-rose-50/40' : index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} hover:bg-rose-50/30">
										<td class="px-3 py-3 text-center">
											<input
												type="checkbox"
												checked={selectedVouchers.has(voucher.id)}
												on:change={() => toggleSelectVoucher(voucher.id)}
												class="w-4 h-4 cursor-pointer rounded accent-rose-500"
											/>
										</td>
										<td class="px-4 py-3 text-sm text-slate-700 font-semibold">{voucher.purchase_voucher_id}</td>
										<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{voucher.serial_number}</td>
										<td class="px-4 py-3 text-sm text-center font-bold text-emerald-700">{voucher.value}</td>
										<td class="px-4 py-3 text-center">
											<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-indigo-100 text-indigo-800">{voucher.issue_type || 'N/A'}</span>
										</td>
										<td class="px-4 py-3 text-xs text-slate-500">{voucher.stock_location_name || '-'}</td>
										<td class="px-4 py-3 text-xs text-slate-500">{voucher.issued_by_name || '-'}</td>
										<td class="px-4 py-3 text-xs text-slate-600 font-medium">{voucher.issued_to_name || '-'}</td>
										<td class="px-4 py-3 text-xs text-center text-slate-500">{voucher.issued_date ? new Date(voucher.issued_date).toLocaleDateString() : '-'}</td>
										<td class="px-4 py-3 text-center">
											{#if voucher.approval_status === 'approved'}
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-emerald-100 text-emerald-800">Approved</span>
											{:else if voucher.approval_status === 'pending'}
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-amber-100 text-amber-800">Pending</span>
											{:else if voucher.approval_status === 'rejected'}
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-red-100 text-red-800">Rejected</span>
											{:else}
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-slate-200 text-slate-600">None</span>
											{/if}
										</td>
										<td class="px-4 py-3 text-xs text-slate-400 max-w-[150px] truncate">{voucher.issue_remarks || '-'}</td>
										<td class="px-4 py-3 text-center">
											{#if voucher.approval_status === 'approved' || !voucher.approval_status}
												<button
													class="px-3 py-1.5 text-[10px] font-black uppercase tracking-wide bg-rose-600 text-white rounded-lg hover:bg-rose-700 transition-all duration-200 hover:shadow-md"
													on:click={() => openCloseModal(voucher)}
												>Close</button>
											{:else}
												<span class="text-[10px] font-bold text-slate-400 uppercase">Pending</span>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
					<!-- Footer -->
					<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
						Showing {filteredVouchers.length} of {issuedVouchers.length} vouchers
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- ═══════════════════════════════════ Close Modal ═══════════════════════════════════ -->
{#if showCloseModal && selectedVoucherForModal}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[1000]" on:click={closeModal}>
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
		<div class="bg-white rounded-2xl shadow-2xl max-w-xl w-[90%] max-h-[90vh] overflow-y-auto" on:click|stopPropagation>
			<div class="flex justify-between items-center px-6 py-4 border-b border-slate-200">
				<h3 class="text-base font-black text-slate-800 flex items-center gap-2">
					<span class="w-8 h-8 rounded-lg bg-rose-100 flex items-center justify-center text-lg">🔒</span>
					Close Voucher
				</h3>
				<button class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors text-xl" on:click={closeModal}>&times;</button>
			</div>

			<div class="p-6 space-y-5">
				<!-- Voucher Info -->
				<div class="bg-slate-50 rounded-xl p-4 space-y-2">
					<div class="flex justify-between text-sm">
						<span class="text-slate-500 font-medium">PV ID</span>
						<span class="text-slate-800 font-bold">{selectedVoucherForModal.purchase_voucher_id}</span>
					</div>
					<div class="flex justify-between text-sm">
						<span class="text-slate-500 font-medium">Serial Number</span>
						<span class="text-slate-800 font-bold font-mono">{selectedVoucherForModal.serial_number}</span>
					</div>
					<div class="flex justify-between text-sm">
						<span class="text-slate-500 font-medium">Value</span>
						<span class="text-emerald-700 font-black">{selectedVoucherForModal.value}</span>
					</div>
					<div class="flex justify-between text-sm">
						<span class="text-slate-500 font-medium">Issue Type</span>
						<span class="inline-block px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase bg-indigo-100 text-indigo-800">{selectedVoucherForModal.issue_type || 'N/A'}</span>
					</div>
				</div>

				{#if selectedVoucherForModal.issue_type === 'sales'}
					<!-- Sales Close Form -->
					<div class="space-y-4">
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="closeBillNumber">Close Bill Number <span class="text-red-500">*</span></label>
							<input
								type="text"
								id="closeBillNumber"
								bind:value={closeBillNumber}
								placeholder="Enter bill number"
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="closeRemarks">Remarks</label>
							<textarea
								id="closeRemarks"
								bind:value={closeRemarks}
								placeholder="Enter remarks (optional)"
								rows="3"
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all resize-y"
							></textarea>
						</div>
					</div>
				{:else if selectedVoucherForModal.issue_type === 'gift'}
					<!-- Gift Close Form -->
					<div class="space-y-4">
						<div>
							<!-- svelte-ignore a11y-label-has-associated-control -->
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Expense Category <span class="text-red-500">*</span></label>
							<div class="relative">
								{#if selectedCategoryDisplay}
									<div class="flex items-center justify-between px-4 py-2.5 bg-emerald-50 border border-emerald-200 rounded-xl text-sm">
										<span class="text-emerald-800 font-medium">{selectedCategoryDisplay.name_en} ({selectedCategoryDisplay.name_ar})</span>
										<button type="button" class="text-slate-400 hover:text-red-500 transition-colors text-lg" on:click={clearSelectedCategory}>&times;</button>
									</div>
								{:else}
									<input
										type="text"
										placeholder="Search expense category..."
										bind:value={expenseCategorySearch}
										on:focus={() => showCategoryDropdown = true}
										class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
									/>
								{/if}
								{#if showCategoryDropdown && !selectedCategoryDisplay}
									<div class="absolute top-full left-0 right-0 mt-1 max-h-[200px] overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-xl z-50">
										{#if filteredExpenseCategories.length === 0}
											<div class="px-4 py-3 text-sm text-slate-400 text-center">No categories found</div>
										{:else}
											{#each filteredExpenseCategories as category}
												<button
													type="button"
													class="w-full px-4 py-2.5 text-left text-sm text-slate-700 hover:bg-rose-50 transition-colors border-b border-slate-100 last:border-b-0"
													on:click={() => selectExpenseCategory(category)}
												>
													{category.name_en} ({category.name_ar})
												</button>
											{/each}
										{/if}
									</div>
								{/if}
							</div>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="closeBillNumberGift">Close Bill Number <span class="text-red-500">*</span></label>
							<input
								type="text"
								id="closeBillNumberGift"
								bind:value={closeBillNumber}
								placeholder="Enter bill number"
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="closeRemarksGift">Remarks</label>
							<textarea
								id="closeRemarksGift"
								bind:value={closeRemarks}
								placeholder="Enter remarks (optional)"
								rows="3"
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all resize-y"
							></textarea>
						</div>
					</div>
				{:else}
					<!-- Other issue types -->
					<div class="p-4 bg-amber-50 border border-amber-200 rounded-xl text-center">
						<p class="text-sm text-amber-800">Issue type: <strong class="uppercase">{selectedVoucherForModal.issue_type || 'N/A'}</strong></p>
						<p class="text-xs text-amber-600 mt-1">Close functionality for this issue type will be added later.</p>
					</div>
				{/if}
			</div>

			<div class="flex gap-3 justify-end px-6 py-4 border-t border-slate-200">
				<button
					class="px-5 py-2.5 text-xs font-black uppercase tracking-wide bg-slate-200 text-slate-700 rounded-xl hover:bg-slate-300 transition-all"
					on:click={closeModal}
				>Cancel</button>
				{#if selectedVoucherForModal.issue_type === 'sales' || selectedVoucherForModal.issue_type === 'gift'}
					<button
						class="px-5 py-2.5 text-xs font-black uppercase tracking-wide bg-rose-600 text-white rounded-xl hover:bg-rose-700 hover:shadow-lg shadow-rose-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={handleSaveClose}
						disabled={isClosing}
					>{isClosing ? 'Saving...' : 'Save & Close'}</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}
</style>
