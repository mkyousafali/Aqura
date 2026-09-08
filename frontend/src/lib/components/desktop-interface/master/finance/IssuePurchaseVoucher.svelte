<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import IssueVoucherModal from '$lib/components/desktop-interface/master/finance/IssueVoucherModal.svelte';
	import BatchIssueModal from '$lib/components/desktop-interface/master/finance/BatchIssueModal.svelte';

	export let autoLoadSerial = '';
	export let autoFilterValue = '';

	let issuedVouchers = [];
	let isLoading = false;
	let selectedItems = new Set();
	let subscription;

	// Search options
	let searchPVId = '';
	let searchSerialNumber = '';
	let hasLoaded = false;
	let loadedBy = '';
	let loadedValue = '';

	// Filter variables
	let filterSerialNumber = '';
	let filterLocation = '';
	let filterValue = '';

	$: selectedCount = selectedItems.size;

	// Unique filter values derived from loaded vouchers
	$: uniqueFilterValues = [...new Set(issuedVouchers.map(i => i.value))].sort((a, b) => a - b);
	$: uniqueLocations = [...new Map(issuedVouchers.filter(i => i.stock_location).map(i => [i.stock_location, i.stock_location_name || i.stock_location])).entries()];

	// Computed filtered list
	$: filteredVouchers = issuedVouchers.filter((item) => {
		if (filterSerialNumber && !item.serial_number.toString().includes(filterSerialNumber)) return false;
		if (filterLocation && String(item.stock_location) !== String(filterLocation)) return false;
		if (filterValue && item.value.toString() !== filterValue) return false;
		return true;
	});

	onMount(() => {
		setupRealtimeSubscription();

		if (autoLoadSerial) {
			searchSerialNumber = autoLoadSerial;
			if (autoFilterValue) filterValue = autoFilterValue;
			loadBySerialNumber(autoLoadSerial);
		}

		return () => {
			if (subscription) subscription.unsubscribe();
		};
	});

	function setupRealtimeSubscription() {
		const channelName = `issue_purchase_voucher_${Date.now()}`;
		subscription = supabase
			.channel(channelName)
			.on('postgres_changes', { event: '*', schema: 'public', table: 'purchase_voucher_items' }, (payload) => {
				handleVoucherItemUpdate(payload);
			})
			.subscribe();
	}

	function handleVoucherItemUpdate(payload) {
		const { eventType, new: newRecord, old: oldRecord } = payload;

		if (eventType === 'UPDATE' && newRecord) {
			if (newRecord.issue_type !== 'not issued') {
				// Issued — remove instantly
				issuedVouchers = issuedVouchers.filter(item => item.id !== newRecord.id);
				selectedItems.delete(newRecord.id);
				selectedItems = selectedItems;
			} else {
				// Still not-issued but updated — reload to get resolved names
				reloadCurrentSearch();
			}
		} else if (eventType === 'INSERT' && newRecord && newRecord.issue_type === 'not issued') {
			reloadCurrentSearch();
		} else if (eventType === 'DELETE' && oldRecord) {
			issuedVouchers = issuedVouchers.filter(item => item.id !== oldRecord.id);
			selectedItems.delete(oldRecord.id);
			selectedItems = selectedItems;
		}
	}

	function reloadCurrentSearch() {
		if (!hasLoaded) return;
		if (loadedBy === 'pvId') loadByPVId(loadedValue);
		else if (loadedBy === 'serial') loadBySerialNumber(loadedValue);
	}

	async function loadByPVId(pvId) {
		if (!pvId || !pvId.trim()) { alert('Please enter a PV ID to load'); return; }
		isLoading = true;
		hasLoaded = true;
		loadedBy = 'pvId';
		loadedValue = pvId.trim();
		selectedItems.clear();
		selectedItems = selectedItems;
		try {
			const { data, error } = await supabase.rpc('get_issue_pv_vouchers', { p_pv_id: pvId.trim() });
			if (error) { console.error('Error loading vouchers:', error); issuedVouchers = []; }
			else { issuedVouchers = data || []; }
		} catch (error) { console.error('Error:', error); issuedVouchers = []; }
		finally { isLoading = false; }
	}

	async function loadBySerialNumber(serialNum) {
		if (!serialNum || !serialNum.trim()) { alert('Please enter a Serial Number to load'); return; }
		isLoading = true;
		hasLoaded = true;
		loadedBy = 'serial';
		loadedValue = serialNum.trim();
		selectedItems.clear();
		selectedItems = selectedItems;
		try {
			const { data, error } = await supabase.rpc('get_issue_pv_vouchers', { p_serial_number: parseInt(serialNum.trim()) });
			if (error) { console.error('Error loading vouchers:', error); issuedVouchers = []; }
			else { issuedVouchers = data || []; }
		} catch (error) { console.error('Error:', error); issuedVouchers = []; }
		finally { isLoading = false; }
	}

	function handlePVIdKeyPress(e) { if (e.key === 'Enter') loadByPVId(searchPVId); }
	function handleSerialKeyPress(e) { if (e.key === 'Enter') loadBySerialNumber(searchSerialNumber); }

	function toggleSelectAll() {
		if (selectedItems.size === filteredVouchers.length) selectedItems.clear();
		else filteredVouchers.forEach(item => selectedItems.add(item.id));
		selectedItems = selectedItems;
	}

	function toggleItemSelection(itemId) {
		if (selectedItems.has(itemId)) selectedItems.delete(itemId);
		else selectedItems.add(itemId);
		selectedItems = selectedItems;
	}

	async function handleIssue(itemId) {
		const item = issuedVouchers.find(i => i.id === itemId);
		if (!item) return;
		const windowId = `issue-voucher-${itemId}-${Date.now()}`;
		openWindow({
			id: windowId,
			title: `Issue Voucher - ${item.purchase_voucher_id}`,
			component: IssueVoucherModal,
			icon: '📝',
			size: { width: 500, height: 350 },
			position: { x: 400, y: 300 },
			resizable: true, minimizable: true, maximizable: true, closable: true,
			props: { item, itemId, windowId, onIssueComplete: () => console.log('✅ Issue complete - realtime will update') }
		});
	}

	async function handleBatchIssue() {
		if (selectedItems.size === 0) return;
		const windowId = `batch-issue-${Date.now()}`;
		openWindow({
			id: windowId,
			title: `Batch Issue Vouchers (${selectedItems.size})`,
			component: BatchIssueModal,
			icon: '📦',
			size: { width: 500, height: 350 },
			position: { x: 450, y: 350 },
			resizable: true, minimizable: true, maximizable: true, closable: true,
			props: {
				itemIds: Array.from(selectedItems),
				count: selectedItems.size,
				windowId,
				onIssueComplete: () => { selectedItems.clear(); selectedItems = selectedItems; }
			}
		});
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">📝</span>
			<div>
				<h2 class="text-base font-black text-slate-800 uppercase tracking-wide">Issue Purchase Vouchers</h2>
				<p class="text-[11px] text-slate-500">Search by PV ID or Serial Number to load non-issued vouchers</p>
			</div>
		</div>
		<div class="flex gap-2">
			{#if selectedCount > 0}
				<button
					class="group flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-amber-500 text-white shadow-lg shadow-amber-200 hover:bg-amber-600 hover:shadow-xl hover:scale-[1.02]"
					on:click={handleBatchIssue}
				>
					<span class="text-base">📦</span>
					<span>Batch Issue ({selectedCount})</span>
				</button>
			{/if}
		</div>
	</div>

	<!-- Main Content -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-indigo-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-cyan-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">

			<!-- Search Section -->
			<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-5 mb-4">
				<div class="flex gap-5 items-end">
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="pvIdSearch">Search by PV ID</label>
						<div class="flex gap-3">
							<input
								type="text"
								id="pvIdSearch"
								placeholder="Enter PV ID (e.g., 100PV0001)"
								bind:value={searchPVId}
								on:keypress={handlePVIdKeyPress}
								class="flex-1 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
							/>
							<button
								class="px-6 py-2.5 text-xs font-black uppercase tracking-wide bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 hover:shadow-lg shadow-indigo-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
								on:click={() => loadByPVId(searchPVId)}
								disabled={isLoading}
							>{isLoading ? 'Loading...' : 'Load'}</button>
						</div>
					</div>

					<div class="flex items-center pb-2">
						<span class="px-3 py-1 bg-slate-200 rounded-full text-[10px] font-black uppercase text-slate-500">OR</span>
					</div>

					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="serialSearch">Search by Serial Number</label>
						<div class="flex gap-3">
							<input
								type="text"
								id="serialSearch"
								placeholder="Enter Serial Number (e.g., 101)"
								bind:value={searchSerialNumber}
								on:keypress={handleSerialKeyPress}
								class="flex-1 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
							<button
								class="px-6 py-2.5 text-xs font-black uppercase tracking-wide bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 hover:shadow-lg shadow-emerald-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
								on:click={() => loadBySerialNumber(searchSerialNumber)}
								disabled={isLoading}
							>{isLoading ? 'Loading...' : 'Load'}</button>
						</div>
					</div>
				</div>

				{#if hasLoaded && loadedValue}
					<div class="mt-3 px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-xs text-emerald-700 font-semibold">
						Currently loaded by {loadedBy === 'pvId' ? 'PV ID' : 'Serial Number'}: <strong class="font-black">{loadedValue}</strong>
					</div>
				{/if}
			</div>

			{#if hasLoaded}
				{#if isLoading}
					<div class="flex items-center justify-center flex-1">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-indigo-200 border-t-indigo-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading non-issued vouchers...</p>
						</div>
					</div>

				{:else if issuedVouchers.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex-1 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">No non-issued vouchers found</p>
						<p class="text-sm text-slate-400 mt-1">for {loadedBy === 'pvId' ? 'PV ID' : 'Serial Number'}: {loadedValue}</p>
					</div>

				{:else}
					<!-- Stats Cards -->
					<div class="grid grid-cols-3 gap-3 mb-4">
						<div class="bg-white/50 backdrop-blur-sm rounded-2xl border border-slate-200 p-4 text-center">
							<div class="text-[11px] font-bold uppercase tracking-wide text-slate-500 mb-1">Total Loaded</div>
							<div class="text-2xl font-black text-slate-800">{issuedVouchers.length}</div>
						</div>
						<div class="bg-white/50 backdrop-blur-sm rounded-2xl border border-slate-200 p-4 text-center">
							<div class="text-[11px] font-bold uppercase tracking-wide text-slate-500 mb-1">Filtered</div>
							<div class="text-2xl font-black text-slate-800">{filteredVouchers.length}</div>
						</div>
						<div class="bg-amber-500/10 backdrop-blur-sm rounded-2xl border border-amber-200 p-4 text-center">
							<div class="text-[11px] font-bold uppercase tracking-wide text-amber-600 mb-1">Selected</div>
							<div class="text-2xl font-black text-amber-700">{selectedCount}</div>
						</div>
					</div>

					<!-- Filters Row -->
					<div class="mb-4 grid grid-cols-3 gap-3">
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ipv-filterSerial">Serial Number</label>
							<input
								id="ipv-filterSerial"
								type="text"
								placeholder="Search serial..."
								bind:value={filterSerialNumber}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ipv-filterLocation">Stock Location</label>
							<select id="ipv-filterLocation" bind:value={filterLocation}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All Locations</option>
								{#each uniqueLocations as [locId, locName]}
									<option value={locId} style="color: #000 !important;">{locName || locId}</option>
								{/each}
							</select>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="ipv-filterValue">Value</label>
							<select id="ipv-filterValue" bind:value={filterValue}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All Values</option>
								{#each uniqueFilterValues as val}
									<option value={val.toString()} style="color: #000 !important;">{val}</option>
								{/each}
							</select>
						</div>
					</div>

					<!-- Table Card -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-indigo-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-indigo-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400 w-10">
											<input
												type="checkbox"
												checked={selectedItems.size === filteredVouchers.length && filteredVouchers.length > 0}
												on:change={toggleSelectAll}
												class="w-4 h-4 cursor-pointer rounded accent-indigo-300"
											/>
										</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Voucher ID</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Serial #</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Value</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Stock</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Status</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Issue Type</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Location</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Stock Person</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-indigo-400">Action</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredVouchers as item, index (item.id)}
										<tr class="transition-colors duration-200 {selectedItems.has(item.id) ? 'bg-indigo-50/40' : index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} hover:bg-indigo-50/30">
											<td class="px-3 py-3 text-center">
												<input
													type="checkbox"
													checked={selectedItems.has(item.id)}
													on:change={() => toggleItemSelection(item.id)}
													class="w-4 h-4 cursor-pointer rounded accent-indigo-500"
												/>
											</td>
											<td class="px-4 py-3 text-sm text-slate-700 font-semibold">{item.purchase_voucher_id}</td>
											<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{item.serial_number}</td>
											<td class="px-4 py-3 text-sm text-center font-bold text-emerald-700">{item.value}</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-slate-100 text-slate-700">{item.stock}</span>
											</td>
											<td class="px-4 py-3 text-center">
												{#if item.status === 'stocked'}
													<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-blue-100 text-blue-800">Stocked</span>
												{:else if item.status === 'issued'}
													<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-amber-100 text-amber-800">Issued</span>
												{:else if item.status === 'closed'}
													<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-emerald-100 text-emerald-800">Closed</span>
												{:else}
													<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-red-100 text-red-800">{item.status}</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase bg-indigo-100 text-indigo-800">{item.issue_type}</span>
											</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.stock_location_name || '-'}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.stock_person_name || '-'}</td>
											<td class="px-4 py-3 text-center">
												<button
													class="px-3 py-1.5 text-[10px] font-black uppercase tracking-wide bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-all duration-200 hover:shadow-md"
													on:click={() => handleIssue(item.id)}
												>Issue</button>
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
			{/if}
		</div>
	</div>
</div>

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}
</style>
