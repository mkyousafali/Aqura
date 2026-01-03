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
		await loadBranches();
		await loadUsers();
		await loadEmployees();
		await loadNotIssuedStats();
		await loadIssuedStats();
		await loadClosedStats();
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
				await Promise.all([
					loadNotIssuedStats(),
					loadIssuedStats(),
					loadClosedStats()
				]);
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
				// Reload book summary to recalculate aggregates
				loadBookSummary();
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
				loadBookSummary();
			}
		} else if (eventType === 'DELETE' && oldRecord) {
			// For deleted items, remove from list
			voucherItems = voucherItems.filter(item => item.id !== oldRecord.id);
			
			if (viewMode === 'book') {
				loadBookSummary();
			}
		}

		// Update stats
		handleStatsUpdate();
	}

	// Manual refresh function
	function handleRefresh() {
		if (viewMode === 'voucher') {
			loadVoucherItems();
		} else if (viewMode === 'book') {
			loadBookSummary();
		}
		loadNotIssuedStats();
		loadIssuedStats();
		loadClosedStats();
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.limit(100);
			if (!error) {
				branches = data || [];
			}
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadUsers() {
		try {
			const { data, error } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.limit(500);
			if (!error) {
				users = data || [];
			}
		} catch (error) {
			console.error('Error loading users:', error);
		}
	}

	async function loadEmployees() {
		try {
			const { data, error } = await supabase
				.from('hr_employees')
				.select('id, name')
				.limit(500);
			if (!error) {
				employees = data || [];
			}
		} catch (error) {
			console.error('Error loading employees:', error);
		}
	}

	async function loadNotIssuedStats() {
		if (!isComponentMounted) return;
		
		try {
			const [vouchersRes, itemsRes] = await Promise.all([
				supabase
					.from('purchase_vouchers')
					.select('id, book_number')
					.limit(1000),
				supabase
					.from('purchase_voucher_items')
					.select('purchase_voucher_id, value, stock_location')
					.eq('issue_type', 'not issued')
					.limit(10000)
			]);

			if (vouchersRes.error || itemsRes.error) {
				console.error('Error loading not issued stats:', vouchersRes.error || itemsRes.error);
				return;
			}

			const items = itemsRes.data || [];
			const allVoucherIds = new Set();
			
			// Group by branch and then by value
			const branchValueCounts = {};

			items.forEach(item => {
				const branchId = item.stock_location || 'unassigned';
				const voucherId = item.purchase_voucher_id;
				const value = item.value || 0;

				allVoucherIds.add(voucherId);

				if (!branchValueCounts[branchId]) {
					branchValueCounts[branchId] = {};
				}

				if (!branchValueCounts[branchId][value]) {
					branchValueCounts[branchId][value] = {
						vouchers: 0, // count of items (PV ID + serial)
						books: new Set() // unique PV IDs
					};
				}
				
				// Count each item (voucher = PV ID + serial)
				branchValueCounts[branchId][value].vouchers++;
				// Track unique PV IDs for book count
				branchValueCounts[branchId][value].books.add(voucherId);
			});

			// Convert Set to count for books
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					branchValueCounts[branchId][value].books = branchValueCounts[branchId][value].books.size;
				});
			});

			// Calculate summary by value (across all branches)
			const valueSummary = {};
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					if (!valueSummary[value]) {
						valueSummary[value] = {
							vouchers: 0,
							books: 0
						};
					}
					valueSummary[value].vouchers += branchValueCounts[branchId][value].vouchers;
					valueSummary[value].books += branchValueCounts[branchId][value].books;
				});
			});

			notIssuedStats = {
				totalVouchers: allVoucherIds.size,
				byBranch: branchValueCounts,
				byValue: valueSummary
			};

		} catch (error) {
			console.error('Error loading not issued stats:', error);
		}
	}

	async function loadIssuedStats() {
		if (!isComponentMounted) return;
		
		try {
			const { data: items, error } = await supabase
				.from('purchase_voucher_items')
				.select('purchase_voucher_id, value, stock_location, issue_type')
				.neq('issue_type', 'not issued')
				.limit(10000);

			if (error) {
				console.error('Error loading issued stats:', error);
				return;
			}

			const allVoucherIds = new Set();
			
			// Group by branch, then by value, then by issue_type
			const branchValueCounts = {};

			items.forEach(item => {
				const branchId = item.stock_location || 'unassigned';
				const voucherId = item.purchase_voucher_id;
				const value = item.value || 0;
				const issueType = item.issue_type || 'unknown';

				allVoucherIds.add(voucherId);

				if (!branchValueCounts[branchId]) {
					branchValueCounts[branchId] = {};
				}

				if (!branchValueCounts[branchId][value]) {
					branchValueCounts[branchId][value] = {};
				}

				if (!branchValueCounts[branchId][value][issueType]) {
					branchValueCounts[branchId][value][issueType] = {
						vouchers: 0, // count of items (PV ID + serial)
						books: new Set() // unique PV IDs
					};
				}
				
				// Count each item (voucher = PV ID + serial)
				branchValueCounts[branchId][value][issueType].vouchers++;
				// Track unique PV IDs for book count
				branchValueCounts[branchId][value][issueType].books.add(voucherId);
			});

			// Convert Set to count for books
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						branchValueCounts[branchId][value][issueType].books = branchValueCounts[branchId][value][issueType].books.size;
					});
				});
			});

			// Calculate summary by value only (across all branches, all issue types)
			const valueSummary = {};
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					if (!valueSummary[value]) {
						valueSummary[value] = {
							vouchers: 0,
							books: 0
						};
					}
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						valueSummary[value].vouchers += branchValueCounts[branchId][value][issueType].vouchers;
						valueSummary[value].books += branchValueCounts[branchId][value][issueType].books;
					});
				});
			});

			issuedStats = {
				totalVouchers: allVoucherIds.size,
				byBranch: branchValueCounts,
				byValue: valueSummary
			};

		} catch (error) {
			console.error('Error loading issued stats:', error);
		}
	}

	async function loadClosedStats() {
		if (!isComponentMounted) return;
		
		try {
			const { data: items, error } = await supabase
				.from('purchase_voucher_items')
				.select('purchase_voucher_id, value, stock_location, issue_type')
				.eq('status', 'closed')
				.limit(10000);

			if (error) {
				console.error('Error loading closed stats:', error);
				return;
			}

			const allVoucherIds = new Set();
			
			// Group by branch, then by value, then by issue_type
			const branchValueCounts = {};

			items.forEach(item => {
				const branchId = item.stock_location || 'unassigned';
				const voucherId = item.purchase_voucher_id;
				const value = item.value || 0;
				const issueType = item.issue_type || 'unknown';

				allVoucherIds.add(voucherId);

				if (!branchValueCounts[branchId]) {
					branchValueCounts[branchId] = {};
				}

				if (!branchValueCounts[branchId][value]) {
					branchValueCounts[branchId][value] = {};
				}

				if (!branchValueCounts[branchId][value][issueType]) {
					branchValueCounts[branchId][value][issueType] = {
						vouchers: 0,
						books: new Set()
					};
				}
				
				branchValueCounts[branchId][value][issueType].vouchers++;
				branchValueCounts[branchId][value][issueType].books.add(voucherId);
			});

			// Convert Set to count for books
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						branchValueCounts[branchId][value][issueType].books = branchValueCounts[branchId][value][issueType].books.size;
					});
				});
			});

			// Calculate summary by value only (across all branches, all issue types)
			const valueSummary = {};
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					if (!valueSummary[value]) {
						valueSummary[value] = {
							vouchers: 0,
							books: 0
						};
					}
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						valueSummary[value].vouchers += branchValueCounts[branchId][value][issueType].vouchers;
						valueSummary[value].books += branchValueCounts[branchId][value][issueType].books;
					});
				});
			});

			closedStats = {
				totalVouchers: allVoucherIds.size,
				byBranch: branchValueCounts,
				byValue: valueSummary
			};

		} catch (error) {
			console.error('Error loading closed stats:', error);
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

	async function loadBookSummary() {
		isLoading = true;
		try {
			const [vouchersRes, itemsRes] = await Promise.all([
				supabase
					.from('purchase_vouchers')
					.select('id, book_number, serial_start, serial_end, voucher_count, total_value')
					.limit(1000),
				supabase
					.from('purchase_voucher_items')
					.select('purchase_voucher_id, value, stock, status, stock_location, stock_person')
					.limit(10000)
			]);

			if (vouchersRes.error || itemsRes.error) {
				console.error('Error loading data:', vouchersRes.error || itemsRes.error);
				bookSummary = [];
				return;
			}

			const vouchers = vouchersRes.data || [];
			const items = itemsRes.data || [];

			const voucherMap = {};
			vouchers.forEach(v => {
				voucherMap[v.id] = v;
			});

			const grouped = {};
			items.forEach(item => {
				const vid = item.purchase_voucher_id;
				if (!grouped[vid]) {
					const voucher = voucherMap[vid];
					grouped[vid] = {
						voucher_id: vid,
						book_number: voucher?.book_number || vid,
						serial_range: voucher ? `${voucher.serial_start} - ${voucher.serial_end}` : '-',
						total_count: 0,
						total_value: 0,
						stock_count: 0,
						stocked_count: 0,
						issued_count: 0,
						closed_count: 0,
						stock_locations: new Set(),
						stock_persons: new Set()
					};
				}
				
				grouped[vid].total_count += 1;
				grouped[vid].total_value += item.value || 0;
				
				if (item.stock > 0) {
					grouped[vid].stock_count += 1;
				}
				
				if (item.status === 'stocked') {
					grouped[vid].stocked_count += 1;
				} else if (item.status === 'issued') {
					grouped[vid].issued_count += 1;
				} else if (item.status === 'closed') {
					grouped[vid].closed_count += 1;
				}

				if (item.stock_location) {
					grouped[vid].stock_locations.add(item.stock_location);
				}
				if (item.stock_person) {
					grouped[vid].stock_persons.add(item.stock_person);
				}
			});

			const branchMap = {};
			branches.forEach(b => {
				branchMap[b.id] = `${b.name_en} - ${b.location_en}`;
			});

			const employeeMap = {};
			employees.forEach(e => {
				employeeMap[e.id] = e.name;
			});

			const userEmployeeMap = {};
			users.forEach(u => {
				const empName = employeeMap[u.employee_id];
				userEmployeeMap[u.id] = empName ? `${u.username} - ${empName}` : u.username;
			});

			const allBooks = Object.values(grouped).map(book => {
				const locIds = Array.from(book.stock_locations);
				book.stock_locations = locIds.map(id => branchMap[id] || `Unknown (${id})`).join(', ') || '-';
				
				const personIds = Array.from(book.stock_persons);
				book.stock_persons = personIds.map(id => userNameMap[id] || `Unknown (${id})`).join(', ') || '-';
				
				return book;
			});

			bookSummary = allBooks.sort((a, b) => {
				const aUnassigned = a.stock_locations === '-' || a.stock_persons === '-' ? 0 : 1;
				const bUnassigned = b.stock_locations === '-' || b.stock_persons === '-' ? 0 : 1;
				return aUnassigned - bUnassigned;
			});

		} catch (error) {
			console.error('Error:', error);
		} finally {
			isLoading = false;
		}
	}

	function setViewMode(mode) {
		viewMode = mode;
		if (mode === 'book') {
			loadBookSummary();
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

<div class="purchase-voucher-manager">
	<div class="status-grid">
		<div class="status-card clickable" on:click={() => showCard1Breakdown = !showCard1Breakdown}>
			<h3 class="card-title">Available Vouchers {showCard1Breakdown ? '▼' : '▶'}</h3>
			<div class="total-count">Total: {notIssuedStats.totalVouchers} {notIssuedStats.totalVouchers === 1 ? 'voucher' : 'vouchers'}</div>
			
			{#if !showCard1Breakdown}
				<!-- Summary by value -->
				<div class="value-summary">
					{#if Object.keys(notIssuedStats.byValue || {}).length > 0}
						{#each Object.entries(notIssuedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
							<div class="value-item">
								<span class="value-label">Value {Number(value).toFixed(2)}:</span>
								<span class="value-count">{counts.vouchers} {counts.vouchers === 1 ? 'voucher' : 'vouchers'}, {counts.books} {counts.books === 1 ? 'book' : 'books'} valued {(Number(value) * counts.vouchers).toFixed(2)}</span>
							</div>
						{/each}
					{:else}
						<p class="no-branch">No not issued vouchers</p>
					{/if}
				</div>
			{:else}
				<!-- Detailed breakdown by branch -->
				<div class="branch-breakdown">
					{#if Object.keys(notIssuedStats.byBranch).length > 0}
						{#each Object.entries(notIssuedStats.byBranch) as [branchId, valueCounts]}
							<div class="branch-section">
								<h4 class="branch-section-title">{branchMap[branchId] || branchId}</h4>
							{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
								<div class="value-item">
									<span class="value-label">Value {Number(value).toFixed(2)}:</span>
									<span class="value-count">{counts.vouchers} {counts.vouchers === 1 ? 'voucher' : 'vouchers'}, {counts.books} {counts.books === 1 ? 'book' : 'books'} valued {(Number(value) * counts.vouchers).toFixed(2)}</span>
									</div>
								{/each}
							</div>
						{/each}
					{:else}
						<p class="no-branch">No not issued vouchers</p>
					{/if}
				</div>
			{/if}
		</div>
		<div class="status-card clickable" on:click={() => showCard2Breakdown = !showCard2Breakdown}>
			<h3 class="card-title">Issued Vouchers {showCard2Breakdown ? '▼' : '▶'}</h3>
			<div class="total-count">Total: {issuedStats.totalVouchers} {issuedStats.totalVouchers === 1 ? 'voucher' : 'vouchers'}</div>
			
			{#if !showCard2Breakdown}
				<!-- Summary by value -->
				<div class="value-summary">
					{#if Object.keys(issuedStats.byValue || {}).length > 0}
						{#each Object.entries(issuedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
							<div class="value-item">
								<span class="value-label">Value {Number(value).toFixed(2)}:</span>
								<span class="value-count">{counts.vouchers} {counts.vouchers === 1 ? 'voucher' : 'vouchers'}, {counts.books} {counts.books === 1 ? 'book' : 'books'} valued {(Number(value) * counts.vouchers).toFixed(2)}</span>
							</div>
						{/each}
					{:else}
						<p class="no-branch">No issued vouchers</p>
					{/if}
				</div>
			{:else}
				<!-- Detailed breakdown by branch -->
				<div class="branch-breakdown">
					{#if Object.keys(issuedStats.byBranch).length > 0}
						{#each Object.entries(issuedStats.byBranch) as [branchId, valueCounts]}
							<div class="branch-section">
								<h4 class="branch-section-title">{branchMap[branchId] || branchId}</h4>
							{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, issueTypes]}
								{#each Object.entries(issueTypes) as [issueType, counts]}
									<div class="value-item">
										<span class="value-label">Value {Number(value).toFixed(2)}:</span>
										<span class="value-count">{counts.vouchers} {counts.vouchers === 1 ? 'voucher' : 'vouchers'}, {counts.books} {counts.books === 1 ? 'book' : 'books'} valued {(Number(value) * counts.vouchers).toFixed(2)} {issueType}</span>
										</div>
								{/each}
								{/each}
							</div>
						{/each}
					{:else}
						<p class="no-branch">No issued vouchers</p>
					{/if}
				</div>
			{/if}
		</div>
		<div class="status-card clickable" on:click={() => showCard3Breakdown = !showCard3Breakdown}>
			<h3 class="card-title">Closed Vouchers {showCard3Breakdown ? '▼' : '▶'}</h3>
			<div class="total-count">Total: {closedStats.totalVouchers} {closedStats.totalVouchers === 1 ? 'voucher' : 'vouchers'}</div>
			
			{#if !showCard3Breakdown}
				<!-- Summary by value -->
				<div class="value-summary">
					{#if Object.keys(closedStats.byValue || {}).length > 0}
						{#each Object.entries(closedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
							<div class="value-item">
								<span class="value-label">Value {Number(value).toFixed(2)}:</span>
								<span class="value-count">{counts.vouchers} {counts.vouchers === 1 ? 'voucher' : 'vouchers'}, {counts.books} {counts.books === 1 ? 'book' : 'books'} valued {(Number(value) * counts.vouchers).toFixed(2)}</span>
							</div>
						{/each}
					{:else}
						<p class="no-branch">No closed vouchers</p>
					{/if}
				</div>
			{:else}
				<!-- Detailed breakdown by branch -->
				<div class="branch-breakdown">
					{#if Object.keys(closedStats.byBranch).length > 0}
						{#each Object.entries(closedStats.byBranch) as [branchId, valueCounts]}
							<div class="branch-section">
								<h4 class="branch-section-title">{branchMap[branchId] || branchId}</h4>
							{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, issueTypes]}
								{#each Object.entries(issueTypes) as [issueType, counts]}
									<div class="value-item">
										<span class="value-label">Value {Number(value).toFixed(2)}:</span>
										<span class="value-count">{counts.vouchers} {counts.vouchers === 1 ? 'voucher' : 'vouchers'}, {counts.books} {counts.books === 1 ? 'book' : 'books'} valued {(Number(value) * counts.vouchers).toFixed(2)} {issueType}</span>
										</div>
								{/each}
								{/each}
							</div>
						{/each}
					{:else}
						<p class="no-branch">No closed vouchers</p>
					{/if}
				</div>
			{/if}
		</div>
	</div>
	<div class="button-group">
		<button class="action-button" on:click={handleAddPurchaseVoucher}>Add Purchase Voucher</button>
		<button class="action-button" on:click={handleIssuePurchaseVoucher}>Issue Purchase Voucher</button>
		<button class="action-button" on:click={handleClosePurchaseVoucher}>Close Purchase Voucher</button>
		<button class="action-button" on:click={handlePurchaseVoucherStockManager}>Purchase Voucher Stock Manager</button>
	</div>

	<!-- View Mode Toggle Buttons -->
	<div class="view-toggle">
		<button 
			class="toggle-btn" 
			class:active={viewMode === 'book'}
			on:click={() => setViewMode('book')}
		>
			📚 Book Wise
		</button>
		<button 
			class="toggle-btn" 
			class:active={viewMode === 'voucher'}
			on:click={() => setViewMode('voucher')}
		>
			🎫 Voucher Wise
		</button>
		<button 
			class="toggle-btn refresh-btn" 
			on:click={handleRefresh}
			title="Refresh data"
		>
			🔄 Refresh
		</button>
		{#if viewMode === 'voucher'}
			<div class="filter-group">
				<label for="status-filter">Filter by Status:</label>
				<select id="status-filter" bind:value={statusFilter} on:change={() => loadVoucherItems(true)}>
					<option value="all">All</option>
					<option value="stock">Stock</option>
					<option value="stocked">Stocked</option>
					<option value="issued">Issued</option>
					<option value="closed">Closed</option>
				</select>
			</div>
		{/if}
	</div>

	<!-- Voucher Items Table -->
	{#if isLoading}
		<p class="loading">Loading voucher items...</p>
	{:else if viewMode === 'book'}
		<!-- Book Wise View -->
		{#if bookSummary.length === 0}
			<p class="no-data">No book data found</p>
		{:else}
			<!-- Search by ID Filter -->
			<div class="view-toggle" style="margin-top: 16px;">
				<div class="filter-group">
					<label for="book-search-id">Search by ID:</label>
					<input 
						id="book-search-id" 
						type="text" 
						placeholder="Search PV ID or Book Number..." 
						bind:value={bookSearchId}
						style="padding: 8px; border: 1px solid #cbd5e0; border-radius: 6px; min-width: 300px;"
					/>
					{#if bookSearchId}
						<button 
							class="toggle-btn" 
							on:click={() => bookSearchId = ''}
							style="padding: 8px 16px; margin-left: 8px;"
						>
							Clear
						</button>
					{/if}
				</div>
			</div>
			<div class="count-header">
				<span class="count-label">Total Books:</span>
				<span class="count-value">{filteredBookSummary.length} {bookSearchId ? `(filtered from ${bookSummary.length})` : ''}</span>
			</div>
			<div class="table-container">
				<table class="vouchers-table">
					<thead>
						<tr>
							<th>Voucher ID</th>
							<th>Book Number</th>
							<th>Serial Range</th>
							<th>Total Count</th>
							<th>Total Value</th>
							<th>Stock Count</th>
							<th>Stocked</th>
							<th>Issued</th>
							<th>Closed</th>
							<th>Stock Location</th>
							<th>Stock Person</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredBookSummary as book (book.voucher_id)}
							<tr>
								<td>{book.voucher_id}</td>
								<td>{book.book_number}</td>
								<td>{book.serial_range}</td>
								<td>{book.total_count}</td>
								<td>{book.total_value}</td>
								<td><span class="badge">{book.stock_count}</span></td>
								<td><span class="badge stocked">{book.stocked_count}</span></td>
								<td><span class="badge issued">{book.issued_count}</span></td>
								<td><span class="badge closed">{book.closed_count}</span></td>
								<td>{book.stock_locations}</td>
								<td>{book.stock_persons}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{:else}
		<!-- Voucher Wise View -->
		{#if voucherItems.length === 0}
			<p class="no-data">No voucher items found</p>
		{:else}
			<div class="count-header">
				<span class="count-label">Total Vouchers:</span>
				<span class="count-value">{voucherItems.length}</span>
			</div>
			<div class="table-container">
				<table class="vouchers-table">
					<thead>
						<tr>
							<th>PV ID</th>
							<th>Serial Number</th>
							<th>Value</th>
							<th>Status</th>
							<th>Issue Type</th>
							<th>Stock</th>
							<th>Stock Location</th>						<th>Stock Person</th>							<th>Issued By</th>
							<th>Issued To</th>
							<th>Issued Date</th>
						</tr>
					</thead>
					<tbody>
						{#each voucherItems as item (item.id)}
							<tr>
								<td>{item.purchase_voucher_id}</td>
								<td>{item.serial_number}</td>
								<td>{item.value}</td>
								<td>
									<span class="status-badge status-{item.status}">
										{item.status || 'N/A'}
									</span>
								</td>
								<td>{item.issue_type || 'N/A'}</td>
								<td>{item.stock}</td>
							<td>{item.stock_location ? (branchMap[item.stock_location] || item.stock_location) : 'N/A'}</td>
							<td>{item.stock_person ? (userNameMap[item.stock_person] || item.stock_person) : 'N/A'}</td>
							<td>{item.issued_by ? (userEmployeeMap[item.issued_by] || item.issued_by) : 'N/A'}</td>
								<td>{item.issued_to ? (userEmployeeMap[item.issued_to] || item.issued_to) : 'N/A'}</td>
								<td>{item.issued_date ? new Date(item.issued_date).toLocaleDateString() : 'N/A'}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			{#if hasMoreVouchers}
				<div class="load-more-container">
					<button 
						class="load-more-btn" 
						on:click={loadMoreVouchers}
						disabled={isLoadingMore}
					>
						{#if isLoadingMore}
							Loading...
						{:else}
							Load More
						{/if}
					</button>
				</div>
			{/if}
		{/if}
	{/if}
</div>

<style>
	.purchase-voucher-manager {
		position: relative;
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
	}

	.status-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 24px;
	}

	@media (max-width: 1200px) {
		.status-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	@media (max-width: 768px) {
		.status-grid {
			grid-template-columns: 1fr;
		}
	}

	.status-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 16px;
		padding: 32px 24px;
		min-height: 200px;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
		transition: all 0.3s ease;
	}

	.status-card.clickable {
		cursor: pointer;
		user-select: none;
	}

	.status-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
		border-color: #d1d5db;
	}

	.status-card.clickable:hover {
		border-color: #3b82f6;
	}

	.card-title {
		font-size: 1.1rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0 0 12px 0;
		text-align: center;
	}

	.total-count {
		font-size: 1rem;
		font-weight: 600;
		color: #3b82f6;
		text-align: center;
		margin-bottom: 16px;
		padding-bottom: 12px;
		border-bottom: 2px solid #e5e7eb;
	}

	.card-stats {
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin-bottom: 16px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
	}

	.stat-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.stat-label {
		color: #6b7280;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.stat-value {
		color: #1f2937;
		font-size: 1.25rem;
		font-weight: 700;
	}

	.branch-breakdown {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.value-summary {
		display: flex;
		flex-direction: column;
		gap: 8px;
		margin-top: 12px;
	}

	.branch-section {
		background: #f9fafb;
		border-radius: 8px;
		padding: 12px;
	}

	.branch-section-title {
		font-size: 0.95rem;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 10px 0;
		padding-bottom: 8px;
		border-bottom: 2px solid #e5e7eb;
	}

	.value-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 6px 8px;
		margin: 4px 0;
		background: white;
		border-radius: 4px;
	}

	.value-label {
		color: #6b7280;
		font-size: 0.9rem;
		font-weight: 500;
	}

	.value-count {
		color: #3b82f6;
		font-size: 0.9rem;
		font-weight: 700;
	}

	.no-branch {
		color: #9ca3af;
		font-size: 0.85rem;
		font-style: italic;
		text-align: center;
		margin: 8px 0;
	}

	.value-list {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.button-group {
		display: flex;
		gap: 16px;
		margin-top: 24px;
	}

	.action-button {
		padding: 12px 24px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.action-button:hover {
		background: #2563eb;
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.action-button:active {
		transform: translateY(0);
	}
	.view-toggle {
		display: flex;
		gap: 12px;
		margin-top: 24px;
		justify-content: center;
		align-items: center;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: auto;
	}

	.filter-group label {
		font-size: 0.9rem;
		color: #374151;
		font-weight: 500;
	}

	.filter-group select {
		padding: 8px 12px;
		background: white;
		color: #374151;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-weight: 500;
		font-size: 0.9rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.filter-group select:hover {
		border-color: #3b82f6;
	}

	.filter-group select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.toggle-btn {
		padding: 10px 20px;
		background: white;
		color: #374151;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.toggle-btn:hover {
		border-color: #3b82f6;
		color: #3b82f6;
	}

	.toggle-btn.active {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.toggle-btn.refresh-btn {
		background: #10b981;
		color: white;
		border-color: #10b981;
	}

	.toggle-btn.refresh-btn:hover {
		background: #059669;
		border-color: #059669;
	}

	.count-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		margin-top: 24px;
		background: #f0f9ff;
		border: 1px solid #bfdbfe;
		border-radius: 8px 8px 0 0;
		font-weight: 600;
	}

	.count-label {
		color: #374151;
		font-size: 0.95rem;
	}

	.count-value {
		color: #3b82f6;
		font-size: 1.1rem;
		font-weight: 700;
	}

	.table-container {
		background: white;
		border-radius: 0 0 12px 12px;
		border: 1px solid #bfdbfe;
		border-top: none;
		box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
		max-height: 500px;
		overflow: auto;
		position: relative;
	}

	.vouchers-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.9rem;
	}

	.vouchers-table thead {
		position: sticky;
		top: 0;
		background: #f9fafb;
		z-index: 10;
	}

	.vouchers-table th {
		padding: 12px 8px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		white-space: nowrap;
		background: #f9fafb;
	}

	.vouchers-table td {
		padding: 10px 8px;
		border-bottom: 1px solid #f3f4f6;
		color: #6b7280;
	}

	.vouchers-table tbody tr:hover {
		background: #f9fafb;
	}

	.status-badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-stocked {
		background: #dbeafe;
		color: #1e40af;
	}

	.status-issued {
		background: #d1fae5;
		color: #065f46;
	}

	.status-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.status-available {
		background: #e0e7ff;
		color: #3730a3;
	}

	.badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 8px;
		font-size: 0.75rem;
		font-weight: 600;
		background: #e5e7eb;
		color: #374151;
	}

	.badge.stocked {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge.issued {
		background: #d1fae5;
		color: #065f46;
	}

	.badge.closed {
		background: #fee2e2;
		color: #991b1b;
	}

	.load-more-container {
		display: flex;
		justify-content: center;
		padding: 20px;
		margin-top: 16px;
		background: white;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.load-more-btn {
		padding: 10px 24px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.95rem;
		cursor: pointer;
		transition: all 0.2s ease;
		min-width: 120px;
	}

	.load-more-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.load-more-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading,
	.no-data {
		text-align: center;
		padding: 40px;
		color: #6b7280;
		font-size: 1rem;
	}</style>
