<script>
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';

	let showManagePerBook = false;
	let showManagePerVoucher = false;
	let bookSummary = [];
	let filteredBookSummary = [];
	let voucherItems = [];
	let filteredVoucherItems = [];
	let isLoading = false;
	let branches = [];
	let users = [];
	let employees = [];
	let showAssignModal = false;
	let selectedBook = null;
	let selectedItem = null;
	let selectedItems = new Set();
	let selectedBooks = new Set();
	let assignMultipleMode = false;

	// Form state
	let selectedStockLocation = '';
	let selectedStockPerson = '';
	let stockPersonSearch = '';
	let modalMode = 'book'; // 'book' or 'item' or 'multiple' or 'multiple-books'

	// Filter state - Per Voucher
	let filterPVId = '';
	let filterSerialNumber = '';
	let filterValue = '';
	let filterStatus = '';
	let filterStockLocation = '';
	let filterStockPerson = '';
	let uniquePVIds = [];
	let uniqueValues = [];
	let uniqueStatuses = [];
	let uniqueLocations = [];
	let uniquePersons = [];

	// Filter state - Per Book
	let filterBookPVId = '';
	let filterBookNumber = '';
	let filterBookStatus = '';
	let filterBookStockLocation = '';
	let filterBookStockPerson = '';
	let uniqueBookPVIds = [];
	let uniqueBookNumbers = [];
	let uniqueBookStatuses = [];
	let uniqueBookLocations = [];
	let uniqueBookPersons = [];

	let subscription;
	let ignoreReloadUntil = 0; // Timestamp to ignore reloads until

	onMount(async () => {
		// Load branches and users
		await loadBranches();
		await loadUsers();
		await loadEmployees();

		// Subscribe to real-time changes
		setupRealtimeSubscriptions();

		return () => {
			// Cleanup subscription on unmount
			if (subscription) {
				subscription.unsubscribe();
			}
		};
	});

	let reloadTimeout = null;
	
	function setupRealtimeSubscriptions() {
		// Use a unique channel name with timestamp to avoid conflicts
		const channelName = `pv_stock_manager_${Date.now()}`;
		console.log('📡 Setting up realtime subscription on channel:', channelName);
		
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
					console.log('📦 Realtime: purchase_vouchers changed', payload.eventType);
					// For book changes, reload book summary
					if (showManagePerBook) {
						loadBookSummary();
					}
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
					console.log('🎫 Realtime: purchase_voucher_items changed', payload.eventType, payload.new?.serial_number || payload.old?.serial_number);
					handleVoucherItemUpdate(payload);
				}
			)
			.subscribe((status) => {
				console.log('📡 Realtime subscription status:', status);
			});
	}

	function handleVoucherItemUpdate(payload) {
		// Skip if we just made a change ourselves (within last 2 seconds)
		if (Date.now() < ignoreReloadUntil) {
			console.log('⏭️ Skipping reload (own change)');
			return;
		}

		const { eventType, new: newRecord, old: oldRecord } = payload;

		// Create lookup maps
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

		if (eventType === 'UPDATE' && newRecord) {
			console.log('🔄 Realtime: Updating item in place:', newRecord.id);
			
			// Update the item in voucherItems array without reloading
			voucherItems = voucherItems.map(item => {
				if (item.id === newRecord.id) {
					return {
						...item,
						...newRecord,
						stock_location_name: newRecord.stock_location ? (branchMap[newRecord.stock_location] || `Unknown (${newRecord.stock_location})`) : '-',
						stock_person_name: newRecord.stock_person ? (userEmployeeMap[newRecord.stock_person] || `Unknown (${newRecord.stock_person})`) : '-'
					};
				}
				return item;
			});
			applyFilters();

			// Also reload book summary if in book view
			if (showManagePerBook) {
				loadBookSummary();
			}
		} else if (eventType === 'INSERT' && newRecord) {
			const newItem = {
				...newRecord,
				stock_location_name: newRecord.stock_location ? (branchMap[newRecord.stock_location] || `Unknown (${newRecord.stock_location})`) : '-',
				stock_person_name: newRecord.stock_person ? (userEmployeeMap[newRecord.stock_person] || `Unknown (${newRecord.stock_person})`) : '-'
			};
			voucherItems = [newItem, ...voucherItems];
			applyFilters();
			
			if (showManagePerBook) {
				loadBookSummary();
			}
		} else if (eventType === 'DELETE' && oldRecord) {
			voucherItems = voucherItems.filter(item => item.id !== oldRecord.id);
			applyFilters();
			
			if (showManagePerBook) {
				loadBookSummary();
			}
		}
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

	async function loadRequesters() {
		try {
			const { data, error } = await supabase
				.from('requesters')
				.select('*')
				.limit(100);
			if (!error) {
				requesters = data || [];
			}
		} catch (error) {
			console.error('Error loading requesters:', error);
		}
	}

	async function loadBookSummary() {
		isLoading = true;
		try {
			// Use parallel queries with limits for faster loading
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

			// Create a map of vouchers for quick lookup
			const voucherMap = {};
			vouchers.forEach(v => {
				voucherMap[v.id] = v;
			});

			// Group items by purchase_voucher_id
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

			// Create lookup maps
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

			// Convert Sets to arrays and resolve names
			const allBooks = Object.values(grouped).map(book => {
				const locIds = Array.from(book.stock_locations);
				book.stock_locations = locIds.map(id => branchMap[id] || `Unknown (${id})`).join(', ') || '-';
				
				const personIds = Array.from(book.stock_persons);
				book.stock_persons = personIds.map(id => userEmployeeMap[id] || `Unknown (${id})`).join(', ') || '-';
				
				return book;
			});

			// Sort to show unassigned records first, then assigned records
			bookSummary = allBooks.sort((a, b) => {
				const aUnassigned = a.stock_locations === '-' || a.stock_persons === '-' ? 0 : 1;
				const bUnassigned = b.stock_locations === '-' || b.stock_persons === '-' ? 0 : 1;
				return aUnassigned - bUnassigned;
			});

			// Build unique filter options for books
			uniqueBookPVIds = [...new Set(bookSummary.map(b => b.voucher_id))];
			uniqueBookNumbers = [...new Set(bookSummary.map(b => b.book_number))];
			uniqueBookLocations = [...new Set(bookSummary.map(b => b.stock_locations))];
			uniqueBookPersons = [...new Set(bookSummary.map(b => b.stock_persons))];

			// Apply filters
			applyBookFilters();
		} catch (error) {
			console.error('Error:', error);
		} finally {
			isLoading = false;
		}
	}

	function handleManagePerBook() {
		showManagePerBook = true;
		showManagePerVoucher = false;
		selectedBooks.clear();
		loadBookSummary();
	}

	function handleManagePerVoucher() {
		showManagePerVoucher = true;
		showManagePerBook = false;
		selectedItems.clear();
		loadVoucherItems();
	}

	function applyFilters() {
		filteredVoucherItems = voucherItems.filter(item => {
			if (filterPVId && item.purchase_voucher_id !== filterPVId) return false;
			if (filterSerialNumber && item.serial_number !== parseInt(filterSerialNumber.trim())) return false;
			if (filterValue && item.value !== parseFloat(filterValue.trim())) return false;
			if (filterStatus && item.status !== filterStatus) return false;
			if (filterStockLocation && item.stock_location_name !== filterStockLocation) return false;
			if (filterStockPerson && item.stock_person_name !== filterStockPerson) return false;
			return true;
		});
	}

	function applyBookFilters() {
		filteredBookSummary = bookSummary.filter(book => {
			if (filterBookPVId && book.voucher_id !== filterBookPVId) return false;
			if (filterBookNumber && book.book_number !== filterBookNumber.trim()) return false;
			if (filterBookStockLocation && book.stock_locations !== filterBookStockLocation) return false;
			if (filterBookStockPerson && book.stock_persons !== filterBookStockPerson) return false;
			return true;
		});
	}

	function handleFilterChange() {
		applyFilters();
	}

	function handleBookFilterChange() {
		applyBookFilters();
	}

	function toggleSelectItem(itemId) {
		if (selectedItems.has(itemId)) {
			selectedItems.delete(itemId);
		} else {
			selectedItems.add(itemId);
		}
		selectedItems = selectedItems; // Trigger reactivity
	}

	function toggleSelectAll() {
		if (selectedItems.size === filteredVoucherItems.length) {
			selectedItems.clear();
		} else {
			filteredVoucherItems.forEach(item => selectedItems.add(item.id));
		}
		selectedItems = selectedItems; // Trigger reactivity
	}

	function toggleSelectBook(voucherId) {
		if (selectedBooks.has(voucherId)) {
			selectedBooks.delete(voucherId);
		} else {
			selectedBooks.add(voucherId);
		}
		selectedBooks = selectedBooks; // Trigger reactivity
	}

	function toggleSelectAllBooks() {
		if (selectedBooks.size === filteredBookSummary.length) {
			selectedBooks.clear();
		} else {
			filteredBookSummary.forEach(book => selectedBooks.add(book.voucher_id));
		}
		selectedBooks = selectedBooks; // Trigger reactivity
	}

	function openBatchAssignModal() {
		if (selectedItems.size === 0) {
			alert('Please select at least one voucher');
			return;
		}
		assignMultipleMode = true;
		modalMode = 'multiple';
		selectedStockLocation = '';
		selectedStockPerson = '';
		stockPersonSearch = '';
		showAssignModal = true;
	}

	function openBatchAssignBooksModal() {
		if (selectedBooks.size === 0) {
			alert('Please select at least one book');
			return;
		}
		assignMultipleMode = true;
		modalMode = 'multiple-books';
		selectedStockLocation = '';
		selectedStockPerson = '';
		stockPersonSearch = '';
		showAssignModal = true;
	}

	function openAssignModal(book) {
		selectedBook = book;
		selectedItem = null;
		modalMode = 'book';
		selectedStockLocation = '';
		selectedStockPerson = '';
		stockPersonSearch = '';
		showAssignModal = true;
	}

	function openAssignItemModal(item) {
		selectedItem = item;
		selectedBook = null;
		modalMode = 'item';
		selectedStockLocation = '';
		selectedStockPerson = '';
		stockPersonSearch = '';
		showAssignModal = true;
	}

	function closeAssignModal() {
		showAssignModal = false;
		selectedBook = null;
	}

	async function handleAssignSubmit() {
		if (!selectedStockLocation || !selectedStockPerson) {
			alert('Please select stock location and stock person');
			return;
		}

		try {
			// Set flag to ignore realtime reloads for next 2 seconds (our own changes)
			ignoreReloadUntil = Date.now() + 2000;
			
			const locationInt = parseInt(selectedStockLocation);
			const selectedBranchName = branches.find(b => b.id === locationInt);
			const locationDisplay = selectedBranchName ? `${selectedBranchName.name_en} - ${selectedBranchName.location_en}` : locationInt.toString();
			
			const selectedUser = users.find(u => u.id === selectedStockPerson);
			const empName = selectedUser?.employee_id ? employees.find(e => e.id === selectedUser.employee_id)?.name : null;
			const personDisplay = empName ? `${selectedUser.username} - ${empName}` : selectedUser?.username || selectedStockPerson;
			
			if (modalMode === 'book') {
				// Update all items for this voucher book
				const { error } = await supabase
					.from('purchase_voucher_items')
					.update({
						stock_location: locationInt,
						stock_person: selectedStockPerson
					})
					.eq('purchase_voucher_id', selectedBook.voucher_id);

				if (error) {
					alert(`Error: ${error.message}`);
					ignoreReloadUntil = 0; // Reset ignore flag on error
					return;
				}

				// Optimistically update local data
				bookSummary = bookSummary.map(book => {
					if (book.voucher_id === selectedBook.voucher_id) {
						return {
							...book,
							stock_locations: locationDisplay,
							stock_persons: personDisplay
						};
					}
					return book;
				});
				applyBookFilters();

				alert('Assignment successful!');
				closeAssignModal();
			} else if (modalMode === 'item') {
				// Update single item
				const { error } = await supabase
					.from('purchase_voucher_items')
					.update({
						stock_location: locationInt,
						stock_person: selectedStockPerson
					})
					.eq('id', selectedItem.id);

				if (error) {
					alert(`Error: ${error.message}`);
					ignoreReloadUntil = 0; // Reset ignore flag on error
					return;
				}

				// Optimistically update local data
				voucherItems = voucherItems.map(item => {
					if (item.id === selectedItem.id) {
						return {
							...item,
							stock_location: locationInt,
							stock_person: selectedStockPerson,
							stock_location_display: locationDisplay,
							stock_person_display: personDisplay
						};
					}
					return item;
				});
				applyVoucherFilters();

				alert('Assignment successful!');
				closeAssignModal();
			} else if (modalMode === 'multiple') {
				// Update multiple items
				const itemIds = Array.from(selectedItems);
				const { error } = await supabase
					.from('purchase_voucher_items')
					.update({
						stock_location: locationInt,
						stock_person: selectedStockPerson
					})
					.in('id', itemIds);

				if (error) {
					alert(`Error: ${error.message}`);
					ignoreReloadUntil = 0; // Reset ignore flag on error
					return;
				}

				// Optimistically update local data
				voucherItems = voucherItems.map(item => {
					if (itemIds.includes(item.id)) {
						return {
							...item,
							stock_location: locationInt,
							stock_person: selectedStockPerson,
							stock_location_display: locationDisplay,
							stock_person_display: personDisplay
						};
					}
					return item;
				});
				applyVoucherFilters();

				alert(`Assignment successful for ${itemIds.length} voucher(s)!`);
				closeAssignModal();
				selectedItems.clear();
				assignMultipleMode = false;
			} else if (modalMode === 'multiple-books') {
				// Update all items for multiple selected books
				const bookIds = Array.from(selectedBooks);
				
				for (const bookId of bookIds) {
					const { error } = await supabase
						.from('purchase_voucher_items')
						.update({
							stock_location: locationInt,
							stock_person: selectedStockPerson
						})
						.eq('purchase_voucher_id', bookId);

					if (error) {
						alert(`Error updating book ${bookId}: ${error.message}`);
						ignoreReloadUntil = 0; // Reset ignore flag on error
						return;
					}
				}

				// Optimistically update local data
				bookSummary = bookSummary.map(book => {
					if (bookIds.includes(book.voucher_id)) {
						return {
							...book,
							stock_locations: locationDisplay,
							stock_persons: personDisplay
						};
					}
					return book;
				});
				applyBookFilters();

				alert(`Assignment successful for ${bookIds.length} book(s)!`);
				closeAssignModal();
				selectedBooks.clear();
				assignMultipleMode = false;
			}
		} catch (error) {
			console.error('Error:', error);
			alert('Error updating assignment');
		}
	}

	async function loadVoucherItems() {
		isLoading = true;
		try {
			// Load all unassigned voucher items
			const { data, error } = await supabase
				.from('purchase_voucher_items')
				.select('id, purchase_voucher_id, serial_number, value, stock, status, issue_type, stock_location, stock_person')
				.limit(10000);

			if (error) {
				console.error('Error loading voucher items:', error);
				voucherItems = [];
				return;
			}

			// Create lookup maps
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

			// Filter and format items - show all with unassigned first
			const filteredItems = (data || [])
				.map(item => ({
					...item,
					stock_location_name: item.stock_location ? branchMap[item.stock_location] : '-',
					stock_person_name: item.stock_person ? userEmployeeMap[item.stock_person] : '-'
				}))
				.sort((a, b) => {
					const aUnassigned = !a.stock_location || !a.stock_person ? 0 : 1;
					const bUnassigned = !b.stock_location || !b.stock_person ? 0 : 1;
					return aUnassigned - bUnassigned;
				});

			voucherItems = filteredItems;
			
			// Build unique filter options
			uniquePVIds = [...new Set(filteredItems.map(i => i.purchase_voucher_id))];
			uniqueValues = [...new Set(filteredItems.map(i => i.value))];
			uniqueStatuses = [...new Set(filteredItems.map(i => i.status))];
			uniqueLocations = [...new Set(filteredItems.map(i => i.stock_location_name))];
			uniquePersons = [...new Set(filteredItems.map(i => i.stock_person_name))];
			
			// Apply filters
			applyFilters();
		} catch (error) {
			console.error('Error:', error);
		} finally {
			isLoading = false;
		}
	}

	// Manual refresh function
	function handleRefresh() {
		if (showManagePerBook) {
			loadBookSummary();
		} else if (showManagePerVoucher) {
			loadVoucherItems();
		}
	}
</script>

<div class="stock-manager">
	<div class="button-group">
		<button class="action-button" on:click={handleManagePerBook}>Manage Per Book</button>
		<button class="action-button" on:click={handleManagePerVoucher}>Manage Per Voucher</button>
		{#if showManagePerBook || showManagePerVoucher}
			<button class="action-button refresh-btn" on:click={handleRefresh} title="Refresh data">
				🔄 Refresh
			</button>
		{/if}
	</div>

	{#if showManagePerBook}
		<div class="section-content">
			<h3>Manage Per Book</h3>
			{#if isLoading}
				<div class="loading">Loading data...</div>
			{:else if bookSummary.length === 0}
				<div class="empty-state">No records found</div>
			{:else}
				<!-- Filters Section -->
				<div class="filters-section">
					<div class="filter-group">
						<label for="filterBookPVId">PV ID</label>
						<select id="filterBookPVId" bind:value={filterBookPVId} on:change={handleBookFilterChange} class="form-input">
							<option value="">All</option>
							{#each uniqueBookPVIds as pvId}
								<option value={pvId}>{pvId}</option>
							{/each}
						</select>
					</div>

					<div class="filter-group">
						<label for="filterBookNumber">Book Number</label>
						<input 
							id="filterBookNumber" 
							type="text" 
							placeholder="Enter exact book number" 
							bind:value={filterBookNumber} 
							on:input={handleBookFilterChange} 
							class="form-input"
						/>
					</div>

					<div class="filter-group">
						<label for="filterBookStockLocation">Stock Location</label>
						<select id="filterBookStockLocation" bind:value={filterBookStockLocation} on:change={handleBookFilterChange} class="form-input">
							<option value="">All</option>
							{#each uniqueBookLocations as location}
								<option value={location}>{location}</option>
							{/each}
						</select>
					</div>

					<div class="filter-group">
						<label for="filterBookStockPerson">Stock Person</label>
						<select id="filterBookStockPerson" bind:value={filterBookStockPerson} on:change={handleBookFilterChange} class="form-input">
							<option value="">All</option>
							{#each uniqueBookPersons as person}
								<option value={person}>{person}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Batch Action Button -->
				{#if selectedBooks.size > 0}
					<div class="batch-action-section">
						<span class="selection-info">{selectedBooks.size} book(s) selected</span>
						<button class="assign-btn" on:click={openBatchAssignBooksModal}>Assign Selected</button>
					</div>
				{/if}
				<div class="table-wrapper">
					<table class="summary-table">
						<thead>
							<tr>
								<th style="width: 40px;">
									<input
										type="checkbox"
										checked={selectedBooks.size === filteredBookSummary.length && filteredBookSummary.length > 0}
										on:change={toggleSelectAllBooks}
										class="row-checkbox"
									/>
								</th>
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
								<th>Action</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredBookSummary as book (book.voucher_id)}
								<tr class:selected={selectedBooks.has(book.voucher_id)}>
									<td>
										<input
											type="checkbox"
											checked={selectedBooks.has(book.voucher_id)}
											on:change={() => toggleSelectBook(book.voucher_id)}
											class="row-checkbox"
										/>
									</td>
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
									<td>
										<button class="assign-btn" on:click={() => openAssignModal(book)}>Assign</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}

	{#if showManagePerVoucher}
		<div class="section-content">
			<h3>Manage Per Voucher</h3>
			
			{#if isLoading}
				<div class="loading">Loading data...</div>
			{:else if voucherItems.length === 0}
				<div class="empty-state">No records found</div>
			{:else}
				<!-- Filters Section -->
				<div class="filters-section">
					<div class="filter-group">
						<label for="filterPVId">PV ID</label>
						<select id="filterPVId" bind:value={filterPVId} on:change={handleFilterChange} class="form-input">
							<option value="">All</option>
							{#each uniquePVIds as pvId}
								<option value={pvId}>{pvId}</option>
							{/each}
						</select>
					</div>

					<div class="filter-group">
					<label for="filterSerialNumber">Serial Number</label>
					<input 
						id="filterSerialNumber" 
						type="text" 
						placeholder="Enter exact serial number" 
						bind:value={filterSerialNumber} 
						on:input={handleFilterChange} 
						class="form-input"
					/>
				</div>

				<div class="filter-group">
					<label for="filterValue">Value</label>
					<input 
						id="filterValue" 
						type="text" 
						placeholder="Enter exact value" 
						bind:value={filterValue} 
						on:input={handleFilterChange} 
						class="form-input"
					/>
				</div>

				<div class="filter-group">
					<label for="filterStatus">Status</label>
					<select id="filterStatus" bind:value={filterStatus} on:change={handleFilterChange} class="form-input">
						<option value="">All</option>
						{#each uniqueStatuses as status}
							<option value={status}>{status}</option>
						{/each}
					</select>
				</div>

				<div class="filter-group">
					<label for="filterStockLocation">Stock Location</label>
					<select id="filterStockLocation" bind:value={filterStockLocation} on:change={handleFilterChange} class="form-input">
						<option value="">All</option>
						{#each uniqueLocations as location}
							<option value={location}>{location}</option>
						{/each}
					</select>
				</div>

				<div class="filter-group">
					<label for="filterStockPerson">Stock Person</label>
					<select id="filterStockPerson" bind:value={filterStockPerson} on:change={handleFilterChange} class="form-input">
						<option value="">All</option>
						{#each uniquePersons as person}
							<option value={person}>{person}</option>
						{/each}
					</select>
				</div>
			</div>

				<!-- Batch Action Button -->
				{#if selectedItems.size > 0}
					<div class="batch-action-section">
						<span class="selection-info">{selectedItems.size} voucher(s) selected</span>
						<button class="assign-btn" on:click={openBatchAssignModal}>Assign Selected</button>
					</div>
				{/if}
				<div class="table-wrapper">
					<table class="summary-table">
						<thead>
							<tr>
								<th style="width: 40px;">
									<input
										type="checkbox"
										checked={selectedItems.size === filteredVoucherItems.length && filteredVoucherItems.length > 0}
										on:change={toggleSelectAll}
										class="row-checkbox"
									/>
								</th>
								<th>Voucher ID</th>
								<th>Serial Number</th>
								<th>Value</th>
								<th>Stock</th>
								<th>Status</th>
								<th>Issue Type</th>
								<th>Stock Location</th>
								<th>Stock Person</th>
								<th>Action</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredVoucherItems as item (item.id)}
								<tr class:selected={selectedItems.has(item.id)}>
									<td>
										<input
											type="checkbox"
											checked={selectedItems.has(item.id)}
											on:change={() => toggleSelectItem(item.id)}
											class="row-checkbox"
										/>
									</td>
									<td>{item.purchase_voucher_id}</td>
									<td>{item.serial_number}</td>
									<td>{item.value}</td>
									<td>{item.stock}</td>
									<td>
										<span class="badge" class:stocked={item.status === 'stocked'} class:issued={item.status === 'issued'} class:closed={item.status === 'closed'}>
											{item.status}
										</span>
									</td>
									<td>{item.issue_type}</td>
									<td>{item.stock_location_name}</td>
									<td>{item.stock_person_name}</td>
									<td>
										<button class="assign-btn" on:click={() => openAssignItemModal(item)}>Assign</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}

	{#if showAssignModal}
		<div class="modal-overlay" on:click={closeAssignModal}>
			<div class="modal-content" on:click|stopPropagation>
				<div class="modal-header">
				<h3>
					Assign Stock Details - 
					{#if modalMode === 'book'}
						{selectedBook?.voucher_id}
					{:else if modalMode === 'item'}
						Serial {selectedItem?.serial_number}
					{:else if modalMode === 'multiple'}
						{selectedItems.size} Voucher(s)
					{:else if modalMode === 'multiple-books'}
						{selectedBooks.size} Book(s)
					{/if}
				</h3>
				<button class="close-btn" on:click={closeAssignModal}>&times;</button>
			</div>

				<div class="modal-body">
					<div class="form-group">
						<label for="stockLocation">Stock Location (Branch)</label>
						<select id="stockLocation" bind:value={selectedStockLocation} class="form-input">
							<option value="">-- Select Branch --</option>
							{#each branches as branch (branch.id)}
								<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
							{/each}
						</select>
					</div>

					<div class="form-group">
						<label>Stock Person</label>
						<input 
							type="text" 
							placeholder="Search users..." 
							bind:value={stockPersonSearch}
							class="form-input"
						/>
						<div class="radio-group">
							{#each users.filter(u => u.username.toLowerCase().includes(stockPersonSearch.toLowerCase())) as user (user.id)}
								{@const employee = employees.find(e => e.id === user.employee_id)}
								<label class="radio-label">
									<input
										type="radio"
										name="stockPerson"
										value={user.id}
										bind:group={selectedStockPerson}
									/>
									<span>{user.username} - {employee?.name || 'N/A'}</span>
								</label>
							{/each}
						</div>
					</div>
				</div>

				<div class="modal-footer">
					<button class="cancel-btn" on:click={closeAssignModal}>Cancel</button>
					<button class="save-btn" on:click={handleAssignSubmit}>Assign</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.stock-manager {
		width: 100%;
		height: 100%;
		padding: 20px;
	}

	.button-group {
		display: flex;
		gap: 16px;
		margin-bottom: 20px;
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

	.refresh-btn {
		background: #10b981;
	}

	.refresh-btn:hover {
		background: #059669;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
	}

	.section-content {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
		margin-top: 20px;
	}

	.section-content h3 {
		margin: 0 0 16px 0;
		font-size: 18px;
		font-weight: 600;
		color: #1f2937;
	}

	.loading,
	.empty-state {
		padding: 32px 24px;
		text-align: center;
		color: #6b7280;
		font-size: 14px;
	}

	.table-wrapper {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: auto;
		max-height: 400px;
	}

	.summary-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.summary-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
	}

	.summary-table th {
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.summary-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
		color: #4b5563;
	}

	.summary-table tbody tr:hover {
		background: #f9fafb;
	}

	.badge {
		display: inline-block;
		padding: 4px 10px;
		border-radius: 6px;
		font-size: 11px;
		font-weight: 600;
		background: #f3f4f6;
		color: #374151;
		text-align: center;
		min-width: 30px;
	}

	.badge.stocked {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge.issued {
		background: #fef08a;
		color: #a16207;
	}

	.badge.closed {
		background: #dcfce7;
		color: #16a34a;
	}

	.assign-btn {
		padding: 6px 12px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 4px;
		font-size: 12px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.assign-btn:hover {
		background: #059669;
	}

	/* Filters Section */
	.filters-section {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: 12px;
		padding: 16px 0;
		margin-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
	}

	.filter-group label {
		font-size: 12px;
		font-weight: 600;
		margin-bottom: 4px;
		color: #374151;
	}

	.filter-group .form-input {
		padding: 6px 8px;
		font-size: 13px;
	}

	/* Batch Action Section */
	.batch-action-section {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		margin-bottom: 12px;
		background: #dbeafe;
		border-radius: 6px;
	}

	.selection-info {
		font-weight: 600;
		color: #1e40af;
		font-size: 14px;
	}

	/* Checkbox Styles */
	.row-checkbox {
		cursor: pointer;
		width: 18px;
		height: 18px;
	}

	.summary-table tbody tr.selected {
		background: #f0f9ff;
	}

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
	}

	.modal-content {
		background: white;
		border-radius: 8px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
		max-width: 600px;
		width: 90%;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 28px;
		cursor: pointer;
		color: #6b7280;
		padding: 0;
		width: 32px;
		height: 32px;
	}

	.close-btn:hover {
		color: #1f2937;
	}

	.modal-body {
		padding: 20px;
	}

	.form-group {
		margin-bottom: 20px;
	}

	.form-group label {
		display: block;
		font-weight: 600;
		margin-bottom: 8px;
		color: #374151;
		font-size: 14px;
	}

	.form-input {
		width: 100%;
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.radio-group {
		display: flex;
		flex-direction: column;
		gap: 10px;
		max-height: 250px;
		overflow-y: auto;
		padding: 8px;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
	}

	.radio-label {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
		padding: 6px;
		border-radius: 4px;
		transition: background-color 0.2s;
	}

	.radio-label:hover {
		background-color: #f3f4f6;
	}

	.radio-label input {
		cursor: pointer;
	}

	.radio-label span {
		font-size: 14px;
		color: #374151;
	}

	.secondary-btn {
		padding: 8px 16px;
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: background-color 0.2s;
	}

	.secondary-btn:hover {
		background: #4b5563;
	}

	.requesters-table {
		margin-top: 12px;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		overflow: auto;
		max-height: 250px;
	}

	.requesters-table table {
		width: 100%;
		border-collapse: collapse;
		font-size: 12px;
	}

	.requesters-table th {
		background: #f9fafb;
		padding: 8px;
		text-align: left;
		border-bottom: 1px solid #e5e7eb;
		font-weight: 600;
	}

	.requesters-table td {
		padding: 8px;
		border-bottom: 1px solid #f3f4f6;
	}

	.modal-footer {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		padding: 20px;
		border-top: 1px solid #e5e7eb;
	}

	.cancel-btn {
		padding: 8px 16px;
		background: #e5e7eb;
		color: #374151;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 600;
		transition: background-color 0.2s;
	}

	.cancel-btn:hover {
		background: #d1d5db;
	}

	.save-btn {
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 600;
		transition: background-color 0.2s;
	}

	.save-btn:hover {
		background: #2563eb;
	}
</style>
