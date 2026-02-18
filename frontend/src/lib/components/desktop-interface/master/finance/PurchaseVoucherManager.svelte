<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import AddPurchaseVoucher from '$lib/components/desktop-interface/master/finance/AddPurchaseVoucher.svelte';
	import IssuePurchaseVoucher from '$lib/components/desktop-interface/master/finance/IssuePurchaseVoucher.svelte';
	import ClosePurchaseVoucher from '$lib/components/desktop-interface/master/finance/ClosePurchaseVoucher.svelte';
	import PurchaseVoucherStockManager from '$lib/components/desktop-interface/master/finance/PurchaseVoucherStockManager.svelte';

	let voucherItems = [];
	let bookSummary = [];
	let isLoading = false;
	let isLoadingMore = false;
	let voucherOffset = 0;
	let voucherPageSize = 500;
	let hasMoreVouchers = true;
	let viewMode = 'voucher'; // 'voucher' or 'book'
	let statusFilter = 'all'; // 'all', 'stock', 'stocked', 'issued', 'closed'
	let showCard1Breakdown = false;
	let showCard2Breakdown = false;
	let showCard3Breakdown = false;
	let branches = [];
	let users = [];
	let employees = [];
	let bookSearchId = ''; // Search by book ID/PV ID
	
	// Status card 1 data - Not Issued
	let notIssuedStats = {
		totalVouchers: 0,
		byBranch: {} // { branchId: { value1: count, value2: count } }
	};

	// Status card 2 data - Issued
	let issuedStats = {
		totalVouchers: 0,
		byBranch: {} // { branchId: { value1: { vouchers, books }, value2: { vouchers, books } } }
	};

	// Status card 3 data - Closed
	let closedStats = {
		totalVouchers: 0,
		byBranch: {}
	};

	// Create lookup maps for display
	$: branchMap = branches.reduce((map, b) => {
		map[b.id] = `${b.name_en} - ${b.location_en}`;
		return map;
	}, {});

	$: employeeMap = employees.reduce((map, e) => {
		map[e.id] = e.name;
		return map;
	}, {});

	$: userEmployeeMap = users.reduce((map, u) => {
		const empName = employeeMap[u.employee_id];
		map[u.id] = empName ? `${u.username} - ${empName}` : u.username;
		return map;
	}, {});

	$: userNameMap = users.reduce((map, u) => {
		map[u.id] = u.username;
		return map;
	}, {});

	// Filter bookSummary based on search ID
	$: filteredBookSummary = bookSummary.filter(book => {
		if (!bookSearchId.trim()) return true;
		const searchLower = bookSearchId.toLowerCase().trim();
		return book.voucher_id?.toLowerCase().includes(searchLower) || 
		       book.book_number?.toLowerCase().includes(searchLower);
	});

	let subscription;
	let reloadTimeout = null;
	let isLoadingStats = false;
	let isComponentMounted = true;

	onMount(async () => {
		await loadAllData();
		await loadVoucherItems();

		// Setup realtime subscription
		setupRealtimeSubscriptions();

		return () => {
			// Cleanup subscription on unmount
			isComponentMounted = false;
			if (reloadTimeout) clearTimeout(reloadTimeout);
			if (subscription) {
				subscription.unsubscribe();
			}
		};
	});

	function setupRealtimeSubscriptions() {
		const channelName = `pv_manager_${Date.now()}`;
		console.log('📡 PurchaseVoucherManager: Setting up realtime subscription on channel:', channelName);
		
		subscription = supabase
			.channel(channelName)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'purchase_vouchers'
				},
				(payload) => {
					console.log('📦 PurchaseVoucherManager: purchase_vouchers changed', payload.eventType);
					// For book changes, just update stats (books don't change often)
					handleStatsUpdate();
				}
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'purchase_voucher_items'
				},
				(payload) => {
					console.log('🎫 PurchaseVoucherManager: purchase_voucher_items changed', payload.eventType, payload.new?.serial_number || payload.old?.serial_number);
					handleVoucherItemUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('📡 PurchaseVoucherManager: Realtime subscription status:', status);
			});
	}

	function handleStatsUpdate() {
		// Debounce stats reload - skip if already loading or component unmounted
		if (isLoadingStats || !isComponentMounted) return;
		
		if (reloadTimeout) clearTimeout(reloadTimeout);
		reloadTimeout = setTimeout(async () => {
			if (!isComponentMounted || isLoadingStats) return;
			
			isLoadingStats = true;
			try {
				await loadAllData();
			} catch (error) {
				console.error('Error updating stats:', error);
			} finally {
				isLoadingStats = false;
			}
		}, 500);
	}

	function handleVoucherItemUpdate(payload) {
		const { eventType, new: newRecord, old: oldRecord } = payload;
		
		if (eventType === 'UPDATE' && newRecord) {
			console.log('🔄 PurchaseVoucherManager: Updating item in place:', newRecord.id);
			
			// Update the item in voucherItems array without reloading
			voucherItems = voucherItems.map(item => {
				if (item.id === newRecord.id) {
					// Merge the new data with display names
					return {
						...item,
						...newRecord,
						// Recalculate display names
						stock_location_name: newRecord.stock_location ? (branchMap[newRecord.stock_location] || `Unknown (${newRecord.stock_location})`) : '-',
						stock_person_name: newRecord.stock_person ? (userEmployeeMap[newRecord.stock_person] || `Unknown (${newRecord.stock_person})`) : '-',
						issued_by_name: newRecord.issued_by ? (userNameMap[newRecord.issued_by] || newRecord.issued_by) : null,
						issued_to_name: newRecord.issued_to ? (userNameMap[newRecord.issued_to] || newRecord.issued_to) : null
					};
				}
				return item;
			});

			// Also update book summary if in book view
			if (viewMode === 'book') {
				// Reload all data to recalculate aggregates
				loadAllData();
			}
		} else if (eventType === 'INSERT' && newRecord) {
			// For new items, add to the list
			const newItem = {
				...newRecord,
				stock_location_name: newRecord.stock_location ? (branchMap[newRecord.stock_location] || `Unknown (${newRecord.stock_location})`) : '-',
				stock_person_name: newRecord.stock_person ? (userEmployeeMap[newRecord.stock_person] || `Unknown (${newRecord.stock_person})`) : '-',
				issued_by_name: newRecord.issued_by ? (userNameMap[newRecord.issued_by] || newRecord.issued_by) : null,
				issued_to_name: newRecord.issued_to ? (userNameMap[newRecord.issued_to] || newRecord.issued_to) : null
			};
			voucherItems = [newItem, ...voucherItems];
			
			if (viewMode === 'book') {
				loadAllData();
			}
		} else if (eventType === 'DELETE' && oldRecord) {
			// For deleted items, remove from list
			voucherItems = voucherItems.filter(item => item.id !== oldRecord.id);
			
			if (viewMode === 'book') {
				loadAllData();
			}
		}

		// Update stats
		handleStatsUpdate();
	}

	// Manual refresh function
	function handleRefresh() {
		loadAllData();
		if (viewMode === 'voucher') {
			loadVoucherItems();
		}
	}

	// Single RPC call to load ALL data (stats + book summary + lookups)
	async function loadAllData() {
		if (!isComponentMounted) return;
		
		try {
			const { data: rpcResult, error } = await supabase.rpc('get_purchase_voucher_manager_data');
			
			if (error) {
				console.error('Error loading purchase voucher data:', error);
				return;
			}

			// Parse lookups
			branches = rpcResult.branches || [];
			users = rpcResult.users || [];
			employees = rpcResult.employees || [];

			// Build lookup maps for display names
			const _branchMap = {};
			branches.forEach(b => { _branchMap[b.id] = `${b.name_en} - ${b.location_en}`; });
			
			const _employeeMap = {};
			employees.forEach(e => { _employeeMap[e.id] = e.name; });

			const _userNameMap = {};
			users.forEach(u => { _userNameMap[u.id] = u.username; });

			// --- Not Issued Stats ---
			const niByBranch = {};
			const niByValue = {};
			const niAllVoucherIds = new Set();
			(rpcResult.not_issued_stats || []).forEach(row => {
				const branchId = row.stock_location || 'unassigned';
				const value = row.value || 0;
				if (!niByBranch[branchId]) niByBranch[branchId] = {};
				niByBranch[branchId][value] = { vouchers: Number(row.voucher_count), books: Number(row.book_count) };
				if (!niByValue[value]) niByValue[value] = { vouchers: 0, books: 0 };
				niByValue[value].vouchers += Number(row.voucher_count);
				niByValue[value].books += Number(row.book_count);
			});
			// Compute total distinct books from byValue
			let niTotal = 0;
			Object.values(niByValue).forEach(v => { niTotal += v.books; });
			notIssuedStats = { totalVouchers: niTotal, byBranch: niByBranch, byValue: niByValue };

			// --- Issued Stats ---
			const isByBranch = {};
			const isByValue = {};
			let isTotal = 0;
			(rpcResult.issued_stats || []).forEach(row => {
				const branchId = row.stock_location || 'unassigned';
				const value = row.value || 0;
				const issueType = row.issue_type || 'unknown';
				if (!isByBranch[branchId]) isByBranch[branchId] = {};
				if (!isByBranch[branchId][value]) isByBranch[branchId][value] = {};
				isByBranch[branchId][value][issueType] = { vouchers: Number(row.voucher_count), books: Number(row.book_count) };
				if (!isByValue[value]) isByValue[value] = { vouchers: 0, books: 0 };
				isByValue[value].vouchers += Number(row.voucher_count);
				isByValue[value].books += Number(row.book_count);
				isTotal += Number(row.book_count);
			});
			issuedStats = { totalVouchers: isTotal, byBranch: isByBranch, byValue: isByValue };

			// --- Closed Stats ---
			const clByBranch = {};
			const clByValue = {};
			let clTotal = 0;
			(rpcResult.closed_stats || []).forEach(row => {
				const branchId = row.stock_location || 'unassigned';
				const value = row.value || 0;
				const issueType = row.issue_type || 'unknown';
				if (!clByBranch[branchId]) clByBranch[branchId] = {};
				if (!clByBranch[branchId][value]) clByBranch[branchId][value] = {};
				clByBranch[branchId][value][issueType] = { vouchers: Number(row.voucher_count), books: Number(row.book_count) };
				if (!clByValue[value]) clByValue[value] = { vouchers: 0, books: 0 };
				clByValue[value].vouchers += Number(row.voucher_count);
				clByValue[value].books += Number(row.book_count);
				clTotal += Number(row.book_count);
			});
			closedStats = { totalVouchers: clTotal, byBranch: clByBranch, byValue: clByValue };

			// --- Book Summary ---
			bookSummary = (rpcResult.book_summary || []).map(book => {
				const locIds = book.stock_locations || [];
				const personIds = book.stock_persons || [];
				return {
					...book,
					stock_locations: locIds.length > 0 
						? locIds.map(id => _branchMap[id] || `Unknown (${id})`).join(', ')
						: '-',
					stock_persons: personIds.length > 0
						? personIds.map(id => _userNameMap[id] || `Unknown (${id})`).join(', ')
						: '-'
				};
			});

			console.log(`📦 PV Manager: Loaded ${bookSummary.length} books, ${branches.length} branches, ${users.length} users via RPC`);
		} catch (error) {
			console.error('Error in loadAllData:', error);
		}
	}



	async function loadVoucherItems(reset = true) {
		if (reset) {
			isLoading = true;
			voucherOffset = 0;
			voucherItems = [];
		} else {
			isLoadingMore = true;
		}
		
		try {
			let query = supabase
				.from('purchase_voucher_items')
				.select('*')
				.order('purchase_voucher_id', { ascending: true })
				.order('serial_number', { ascending: true });
			
			if (statusFilter !== 'all') {
				query = query.eq('status', statusFilter);
			}
			
			const { data, error } = await query.range(voucherOffset, voucherOffset + voucherPageSize - 1);

			if (error) {
				console.error('Error loading voucher items:', error);
				if (reset) voucherItems = [];
			} else {
				const newData = data || [];
				if (reset) {
					voucherItems = newData;
				} else {
					voucherItems = [...voucherItems, ...newData];
				}
				hasMoreVouchers = newData.length === voucherPageSize;
				voucherOffset += newData.length;
			}
		} catch (error) {
			console.error('Error:', error);
			if (reset) voucherItems = [];
		} finally {
			isLoading = false;
			isLoadingMore = false;
			isLoadingMore = false;
		}
	}

	async function loadMoreVouchers() {
		if (!isLoadingMore && hasMoreVouchers) {
			await loadVoucherItems(false);
		}
	}

	function setViewMode(mode) {
		viewMode = mode;
		if (mode === 'book') {
			// Book data already loaded via RPC, just refresh if needed
			loadAllData();
		} else {
			loadVoucherItems();
		}
	}

	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function handleAddPurchaseVoucher() {
		const windowId = generateWindowId('add-purchase-voucher');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Add Purchase Voucher #${instanceNumber}`,
			component: AddPurchaseVoucher,
			icon: '➕',
			size: { width: 1000, height: 700 },
			position: { x: 100, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handleIssuePurchaseVoucher() {
		const windowId = generateWindowId('issue-purchase-voucher');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Issue Purchase Voucher #${instanceNumber}`,
			component: IssuePurchaseVoucher,
			icon: '📤',
			size: { width: 1000, height: 700 },
			position: { x: 150, y: 150 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handleClosePurchaseVoucher() {
		const windowId = generateWindowId('close-purchase-voucher');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Close Purchase Voucher #${instanceNumber}`,
			component: ClosePurchaseVoucher,
			icon: '✅',
			size: { width: 1000, height: 700 },
			position: { x: 200, y: 200 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function handlePurchaseVoucherStockManager() {
		const windowId = generateWindowId('purchase-voucher-stock-manager');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Purchase Voucher Stock Manager #${instanceNumber}`,
			component: PurchaseVoucherStockManager,
			icon: '📦',
			size: { width: 1000, height: 700 },
			position: { x: 250, y: 250 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header / Navigation Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<!-- Action Buttons -->
		<div class="flex gap-2">
			<button 
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:shadow-xl hover:scale-[1.02]"
				on:click={handleAddPurchaseVoucher}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">➕</span>
				<span>Add Book</span>
			</button>
			<button 
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700 hover:shadow-xl hover:scale-[1.02]"
				on:click={handleIssuePurchaseVoucher}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📤</span>
				<span>Issue</span>
			</button>
			<button 
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-orange-600 text-white shadow-lg shadow-orange-200 hover:bg-orange-700 hover:shadow-xl hover:scale-[1.02]"
				on:click={handleClosePurchaseVoucher}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">✅</span>
				<span>Close</span>
			</button>
			<button 
				class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-purple-600 text-white shadow-lg shadow-purple-200 hover:bg-purple-700 hover:shadow-xl hover:scale-[1.02]"
				on:click={handlePurchaseVoucherStockManager}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📦</span>
				<span>Stock Manager</span>
			</button>
		</div>

		<!-- View Mode Tabs -->
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{viewMode === 'book' 
					? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => setViewMode('book')}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📚</span>
				<span class="relative z-10">Book Wise</span>
				{#if viewMode === 'book'}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{viewMode === 'voucher' 
					? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => setViewMode('voucher')}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🎫</span>
				<span class="relative z-10">Voucher Wise</span>
				{#if viewMode === 'voucher'}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
			<button 
				class="group relative flex items-center gap-2.5 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden text-slate-500 hover:bg-white hover:text-emerald-700 hover:shadow-md"
				on:click={handleRefresh}
				title="Refresh data"
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-180">🔄</span>
				<span class="relative z-10">Refresh</span>
			</button>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			<!-- Status Summary Cards -->
			<div class="grid grid-cols-3 gap-4 mb-6">
				<!-- Available Vouchers Card -->
				<button 
					class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-5 text-left transition-all duration-300 hover:shadow-[0_16px_48px_-12px_rgba(0,0,0,0.1)] hover:scale-[1.01] cursor-pointer"
					on:click={() => showCard1Breakdown = !showCard1Breakdown}
				>
					<div class="flex items-center justify-between mb-3">
						<h3 class="text-sm font-black uppercase tracking-wide text-slate-700 flex items-center gap-2">
							<span class="w-8 h-8 rounded-lg bg-emerald-100 flex items-center justify-center text-lg">📋</span>
							Available
						</h3>
						<span class="text-xs font-bold text-slate-400">{showCard1Breakdown ? '▼' : '▶'}</span>
					</div>
					<div class="text-2xl font-black text-emerald-600 mb-2">{notIssuedStats.totalVouchers}</div>
					<div class="text-xs text-slate-500 font-semibold">{notIssuedStats.totalVouchers === 1 ? 'book' : 'books'} not issued</div>

					{#if !showCard1Breakdown}
						<div class="mt-3 space-y-1.5">
							{#if Object.keys(notIssuedStats.byValue || {}).length > 0}
								{#each Object.entries(notIssuedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
									<div class="flex justify-between items-center px-2.5 py-1.5 bg-emerald-50/50 rounded-lg text-xs">
										<span class="text-slate-600 font-semibold">Value {Number(value).toFixed(0)}</span>
										<span class="text-emerald-700 font-black">{counts.vouchers} vouchers · {counts.books} books · {(Number(value) * counts.vouchers).toFixed(0)} total</span>
									</div>
								{/each}
							{:else}
								<p class="text-xs text-slate-400 italic text-center mt-2">No available vouchers</p>
							{/if}
						</div>
					{:else}
						<div class="mt-3 space-y-3">
							{#if Object.keys(notIssuedStats.byBranch).length > 0}
								{#each Object.entries(notIssuedStats.byBranch) as [branchId, valueCounts]}
									<div class="bg-slate-50 rounded-xl p-3">
										<h4 class="text-xs font-black text-slate-700 mb-2 pb-1.5 border-b border-slate-200">{branchMap[branchId] || branchId}</h4>
										{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
											<div class="flex justify-between items-center px-2 py-1 text-xs">
												<span class="text-slate-500 font-semibold">Value {Number(value).toFixed(0)}</span>
												<span class="text-emerald-700 font-bold">{counts.vouchers} vouchers · {counts.books} books</span>
											</div>
										{/each}
									</div>
								{/each}
							{:else}
								<p class="text-xs text-slate-400 italic text-center">No available vouchers</p>
							{/if}
						</div>
					{/if}
				</button>

				<!-- Issued Vouchers Card -->
				<button 
					class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-5 text-left transition-all duration-300 hover:shadow-[0_16px_48px_-12px_rgba(0,0,0,0.1)] hover:scale-[1.01] cursor-pointer"
					on:click={() => showCard2Breakdown = !showCard2Breakdown}
				>
					<div class="flex items-center justify-between mb-3">
						<h3 class="text-sm font-black uppercase tracking-wide text-slate-700 flex items-center gap-2">
							<span class="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center text-lg">📤</span>
							Issued
						</h3>
						<span class="text-xs font-bold text-slate-400">{showCard2Breakdown ? '▼' : '▶'}</span>
					</div>
					<div class="text-2xl font-black text-blue-600 mb-2">{issuedStats.totalVouchers}</div>
					<div class="text-xs text-slate-500 font-semibold">{issuedStats.totalVouchers === 1 ? 'book' : 'books'} issued</div>

					{#if !showCard2Breakdown}
						<div class="mt-3 space-y-1.5">
							{#if Object.keys(issuedStats.byValue || {}).length > 0}
								{#each Object.entries(issuedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
									<div class="flex justify-between items-center px-2.5 py-1.5 bg-blue-50/50 rounded-lg text-xs">
										<span class="text-slate-600 font-semibold">Value {Number(value).toFixed(0)}</span>
										<span class="text-blue-700 font-black">{counts.vouchers} vouchers · {counts.books} books · {(Number(value) * counts.vouchers).toFixed(0)} total</span>
									</div>
								{/each}
							{:else}
								<p class="text-xs text-slate-400 italic text-center mt-2">No issued vouchers</p>
							{/if}
						</div>
					{:else}
						<div class="mt-3 space-y-3">
							{#if Object.keys(issuedStats.byBranch).length > 0}
								{#each Object.entries(issuedStats.byBranch) as [branchId, valueCounts]}
									<div class="bg-slate-50 rounded-xl p-3">
										<h4 class="text-xs font-black text-slate-700 mb-2 pb-1.5 border-b border-slate-200">{branchMap[branchId] || branchId}</h4>
										{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, issueTypes]}
											{#each Object.entries(issueTypes) as [issueType, counts]}
												<div class="flex justify-between items-center px-2 py-1 text-xs">
													<span class="text-slate-500 font-semibold">Value {Number(value).toFixed(0)} · {issueType}</span>
													<span class="text-blue-700 font-bold">{counts.vouchers} vouchers · {counts.books} books</span>
												</div>
											{/each}
										{/each}
									</div>
								{/each}
							{:else}
								<p class="text-xs text-slate-400 italic text-center">No issued vouchers</p>
							{/if}
						</div>
					{/if}
				</button>

				<!-- Closed Vouchers Card -->
				<button 
					class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] p-5 text-left transition-all duration-300 hover:shadow-[0_16px_48px_-12px_rgba(0,0,0,0.1)] hover:scale-[1.01] cursor-pointer"
					on:click={() => showCard3Breakdown = !showCard3Breakdown}
				>
					<div class="flex items-center justify-between mb-3">
						<h3 class="text-sm font-black uppercase tracking-wide text-slate-700 flex items-center gap-2">
							<span class="w-8 h-8 rounded-lg bg-orange-100 flex items-center justify-center text-lg">🔒</span>
							Closed
						</h3>
						<span class="text-xs font-bold text-slate-400">{showCard3Breakdown ? '▼' : '▶'}</span>
					</div>
					<div class="text-2xl font-black text-orange-600 mb-2">{closedStats.totalVouchers}</div>
					<div class="text-xs text-slate-500 font-semibold">{closedStats.totalVouchers === 1 ? 'book' : 'books'} closed</div>

					{#if !showCard3Breakdown}
						<div class="mt-3 space-y-1.5">
							{#if Object.keys(closedStats.byValue || {}).length > 0}
								{#each Object.entries(closedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
									<div class="flex justify-between items-center px-2.5 py-1.5 bg-orange-50/50 rounded-lg text-xs">
										<span class="text-slate-600 font-semibold">Value {Number(value).toFixed(0)}</span>
										<span class="text-orange-700 font-black">{counts.vouchers} vouchers · {counts.books} books · {(Number(value) * counts.vouchers).toFixed(0)} total</span>
									</div>
								{/each}
							{:else}
								<p class="text-xs text-slate-400 italic text-center mt-2">No closed vouchers</p>
							{/if}
						</div>
					{:else}
						<div class="mt-3 space-y-3">
							{#if Object.keys(closedStats.byBranch).length > 0}
								{#each Object.entries(closedStats.byBranch) as [branchId, valueCounts]}
									<div class="bg-slate-50 rounded-xl p-3">
										<h4 class="text-xs font-black text-slate-700 mb-2 pb-1.5 border-b border-slate-200">{branchMap[branchId] || branchId}</h4>
										{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, issueTypes]}
											{#each Object.entries(issueTypes) as [issueType, counts]}
												<div class="flex justify-between items-center px-2 py-1 text-xs">
													<span class="text-slate-500 font-semibold">Value {Number(value).toFixed(0)} · {issueType}</span>
													<span class="text-orange-700 font-bold">{counts.vouchers} vouchers · {counts.books} books</span>
												</div>
											{/each}
										{/each}
									</div>
								{/each}
							{:else}
								<p class="text-xs text-slate-400 italic text-center">No closed vouchers</p>
							{/if}
						</div>
					{/if}
				</button>
			</div>

			<!-- Loading State -->
			{#if isLoading}
				<div class="flex items-center justify-center flex-1">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">Loading voucher data...</p>
					</div>
				</div>

			{:else if viewMode === 'book'}
				<!-- Book Wise View -->
				{#if bookSummary.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex-1 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">No book data found</p>
					</div>
				{:else}
					<!-- Filters Row -->
					<div class="mb-4 flex gap-3">
						<div class="flex-1">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="book-search-id">Search by ID</label>
							<input 
								id="book-search-id" 
								type="text" 
								placeholder="Search PV ID or Book Number..." 
								bind:value={bookSearchId}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>
						{#if bookSearchId}
							<div class="flex items-end">
								<button 
									class="px-4 py-2.5 text-xs font-bold uppercase tracking-wide bg-slate-200 text-slate-700 rounded-xl hover:bg-slate-300 transition-all"
									on:click={() => bookSearchId = ''}
								>
									Clear
								</button>
							</div>
						{/if}
					</div>

					<!-- Table Card -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Voucher ID</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Book #</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Serial Range</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Count</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Value</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Stock</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Stocked</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Issued</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Closed</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Location</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Person</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredBookSummary as book, index (book.voucher_id)}
										<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-4 py-3 text-sm text-slate-700 font-semibold">{book.voucher_id}</td>
											<td class="px-4 py-3 text-sm text-slate-700">{book.book_number}</td>
											<td class="px-4 py-3 text-sm text-slate-500 font-mono">{book.serial_range}</td>
											<td class="px-4 py-3 text-sm text-center font-bold text-slate-800">{book.total_count}</td>
											<td class="px-4 py-3 text-sm text-center font-bold text-emerald-700">{book.total_value}</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-slate-200 text-slate-700">{book.stock_count}</span>
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-blue-100 text-blue-800">{book.stocked_count}</span>
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-emerald-100 text-emerald-800">{book.issued_count}</span>
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black bg-red-100 text-red-800">{book.closed_count}</span>
											</td>
											<td class="px-4 py-3 text-xs text-slate-500">{book.stock_locations}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{book.stock_persons}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<!-- Footer -->
						<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
							Showing {filteredBookSummary.length} books {bookSearchId ? `(filtered from ${bookSummary.length})` : ''}
						</div>
					</div>
				{/if}

			{:else}
				<!-- Voucher Wise View -->
				<!-- Filter Controls -->
				<div class="mb-4 flex gap-3">
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="status-filter">Filter by Status</label>
						<select 
							id="status-filter" 
							bind:value={statusFilter} 
							on:change={() => loadVoucherItems(true)}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;"
						>
							<option value="all" style="color: #000000 !important; background-color: #ffffff !important;">All Statuses</option>
							<option value="stock" style="color: #000000 !important; background-color: #ffffff !important;">Stock</option>
							<option value="stocked" style="color: #000000 !important; background-color: #ffffff !important;">Stocked</option>
							<option value="issued" style="color: #000000 !important; background-color: #ffffff !important;">Issued</option>
							<option value="closed" style="color: #000000 !important; background-color: #ffffff !important;">Closed</option>
						</select>
					</div>
				</div>

				{#if voucherItems.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex-1 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">No voucher items found</p>
					</div>
				{:else}
					<!-- Table Card -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">PV ID</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Serial #</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Value</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Status</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Issue Type</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Stock</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Location</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Person</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Issued By</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Issued To</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Issue Date</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each voucherItems as item, index (item.id)}
										<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-4 py-3 text-sm text-slate-700 font-semibold">{item.purchase_voucher_id}</td>
											<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{item.serial_number}</td>
											<td class="px-4 py-3 text-sm text-center font-bold text-emerald-700">{item.value}</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase
													{item.status === 'stocked' ? 'bg-blue-100 text-blue-800' : 
													 item.status === 'issued' ? 'bg-emerald-100 text-emerald-800' : 
													 item.status === 'closed' ? 'bg-red-100 text-red-800' : 
													 item.status === 'stock' ? 'bg-slate-200 text-slate-700' : 
													 'bg-amber-100 text-amber-800'}">
													{item.status || 'N/A'}
												</span>
											</td>
											<td class="px-4 py-3 text-xs text-center text-slate-600">{item.issue_type || 'N/A'}</td>
											<td class="px-4 py-3 text-sm text-center text-slate-600">{item.stock}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.stock_location ? (branchMap[item.stock_location] || item.stock_location) : '—'}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.stock_person ? (userNameMap[item.stock_person] || item.stock_person) : '—'}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.issued_by ? (userEmployeeMap[item.issued_by] || item.issued_by) : '—'}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.issued_to ? (userEmployeeMap[item.issued_to] || item.issued_to) : '—'}</td>
											<td class="px-4 py-3 text-xs text-center text-slate-500">{item.issued_date ? new Date(item.issued_date).toLocaleDateString() : '—'}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<!-- Footer -->
						<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold flex items-center justify-between">
							<span>Showing {voucherItems.length} vouchers</span>
							{#if hasMoreVouchers}
								<button 
									class="px-5 py-2 text-xs font-black uppercase tracking-wide bg-blue-600 text-white rounded-xl hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
									on:click={loadMoreVouchers}
									disabled={isLoadingMore}
								>
									{#if isLoadingMore}
										Loading...
									{:else}
										Load More
									{/if}
								</button>
							{/if}
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

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}
</style>
