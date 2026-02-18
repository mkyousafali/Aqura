<script>
	import { supabase } from '$lib/utils/supabase';
	import { onMount } from 'svelte';
	import * as XLSX from 'xlsx';

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

	// Export modal state
	let showExportModal = false;
	let exportStockLocation = '';
	let exportStockPerson = '';
	let exportStockPersonSearch = '';
	let isExporting = false;

	let subscription;
	let ignoreReloadUntil = 0; // Timestamp to ignore reloads until

	let isComponentMounted = true;

	// Debounce book summary updates to batch multiple realtime events
	let pendingBookUpdates = new Set();
	let bookUpdateTimeout = null;

	// Reactive lookup maps
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

	onMount(async () => {
		await loadAllData();
		setupRealtimeSubscriptions();

		return () => {
			isComponentMounted = false;
			if (subscription) {
				subscription.unsubscribe();
			}
			if (bookUpdateTimeout) {
				clearTimeout(bookUpdateTimeout);
			}
		};
	});

	let reloadTimeout = null;

	// Debounced function to queue book updates
	function queueBookSummaryUpdate(voucherId) {
		pendingBookUpdates.add(voucherId);
		
		// Clear existing timeout and set a new one
		if (bookUpdateTimeout) {
			clearTimeout(bookUpdateTimeout);
		}
		
		// Process all pending updates after 500ms of no new updates
		bookUpdateTimeout = setTimeout(async () => {
			const booksToUpdate = Array.from(pendingBookUpdates);
			pendingBookUpdates.clear();
			
			console.log(`📚 Batch updating ${booksToUpdate.length} book(s):`, booksToUpdate);
			
			// Update all affected books
			for (const bookId of booksToUpdate) {
				await updateBookSummaryRow(bookId);
			}
		}, 500);
	}
	
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
						loadAllData();
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

			// Queue book summary update if in book view (debounced)
			if (showManagePerBook && newRecord.purchase_voucher_id) {
				queueBookSummaryUpdate(newRecord.purchase_voucher_id);
			}
		} else if (eventType === 'INSERT' && newRecord) {
			const newItem = {
				...newRecord,
				stock_location_name: newRecord.stock_location ? (branchMap[newRecord.stock_location] || `Unknown (${newRecord.stock_location})`) : '-',
				stock_person_name: newRecord.stock_person ? (userEmployeeMap[newRecord.stock_person] || `Unknown (${newRecord.stock_person})`) : '-'
			};
			voucherItems = [newItem, ...voucherItems];
			applyFilters();
			
			if (showManagePerBook && newRecord.purchase_voucher_id) {
				queueBookSummaryUpdate(newRecord.purchase_voucher_id);
			}
		} else if (eventType === 'DELETE' && oldRecord) {
			voucherItems = voucherItems.filter(item => item.id !== oldRecord.id);
			applyFilters();
			
			if (showManagePerBook && oldRecord.purchase_voucher_id) {
				queueBookSummaryUpdate(oldRecord.purchase_voucher_id);
			}
		}
	}

	// Update only the affected book row in the summary instead of reloading everything
	async function updateBookSummaryRow(voucherId) {
		try {
			// Fetch only items for this voucher
			const [voucherRes, itemsRes] = await Promise.all([
				supabase
					.from('purchase_vouchers')
					.select('id, book_number, serial_start, serial_end, voucher_count, total_value')
					.eq('id', voucherId)
					.single(),
				supabase
					.from('purchase_voucher_items')
					.select('purchase_voucher_id, value, stock, status, stock_location, stock_person')
					.eq('purchase_voucher_id', voucherId)
			]);

			if (voucherRes.error || itemsRes.error) {
				console.error('Error updating book row:', voucherRes.error || itemsRes.error);
				return;
			}

			const voucher = voucherRes.data;
			const items = itemsRes.data || [];

			// Create lookup maps
			const branchMap = {};
			branches.forEach(b => {
				branchMap[b.id] = `${b.name_en} - ${b.location_en}`;
			});

			const employeeMap = {};
			employees.forEach(e => {
				employeeMap[e.id] = e.name;
			});

			const userNameMap = {};
			users.forEach(u => {
				userNameMap[u.id] = u.username;
			});

			// Calculate aggregated data for this book
			const bookData = {
				voucher_id: voucherId,
				book_number: voucher?.book_number || voucherId,
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

			items.forEach(item => {
				bookData.total_count += 1;
				bookData.total_value += item.value || 0;
				
				if (item.stock > 0) {
					bookData.stock_count += 1;
				}
				
				if (item.status === 'stocked') {
					bookData.stocked_count += 1;
				} else if (item.status === 'issued') {
					bookData.issued_count += 1;
				} else if (item.status === 'closed') {
					bookData.closed_count += 1;
				}

				if (item.stock_location) {
					bookData.stock_locations.add(item.stock_location);
				}
				if (item.stock_person) {
					bookData.stock_persons.add(item.stock_person);
				}
			});

			// Convert Sets to display strings
			const locIds = Array.from(bookData.stock_locations);
			bookData.stock_locations = locIds.map(id => branchMap[id] || `Unknown (${id})`).join(', ') || '-';
			
			const personIds = Array.from(bookData.stock_persons);
			bookData.stock_persons = personIds.map(id => userNameMap[id] || `Unknown (${id})`).join(', ') || '-';

			// Update the bookSummary array in place
			const bookIndex = bookSummary.findIndex(b => b.voucher_id === voucherId);
			if (bookIndex >= 0) {
				bookSummary[bookIndex] = bookData;
				bookSummary = bookSummary; // Trigger reactivity
				console.log('🔄 Realtime: Updated book row in place:', voucherId);
			}
			
			applyBookFilters();
		} catch (error) {
			console.error('Error updating book row:', error);
		}
	}

	// Single RPC call to load ALL data (book summary + lookups)
	async function loadAllData() {
		if (!isComponentMounted) return;
		isLoading = true;
		try {
			const { data: rpcResult, error } = await supabase.rpc('get_pv_stock_manager_data');

			if (error) {
				console.error('Error loading stock manager data:', error);
				return;
			}

			branches = rpcResult.branches || [];
			users = rpcResult.users || [];
			employees = rpcResult.employees || [];

			// Build lookup maps for display names
			const _branchMap = {};
			branches.forEach(b => { _branchMap[b.id] = `${b.name_en} - ${b.location_en}`; });

			const _userNameMap = {};
			users.forEach(u => { _userNameMap[u.id] = u.username; });

			// Book Summary
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

			// Build unique filter options for books
			uniqueBookPVIds = [...new Set(bookSummary.map(b => b.voucher_id))];
			uniqueBookNumbers = [...new Set(bookSummary.map(b => b.book_number))];
			uniqueBookLocations = [...new Set(bookSummary.map(b => b.stock_locations))];
			uniqueBookPersons = [...new Set(bookSummary.map(b => b.stock_persons))];

			applyBookFilters();

			console.log(`📦 PV Stock Manager: Loaded ${bookSummary.length} books, ${branches.length} branches, ${users.length} users via RPC`);
		} catch (error) {
			console.error('Error in loadAllData:', error);
		} finally {
			isLoading = false;
		}
	}

	function handleManagePerBook() {
		showManagePerBook = true;
		showManagePerVoucher = false;
		selectedBooks.clear();
		loadAllData();
	}

	function handleManagePerVoucher() {
		showManagePerVoucher = true;
		showManagePerBook = false;
		selectedItems.clear();
		loadVoucherItems();
	}

	function applyFilters() {
		filteredVoucherItems = voucherItems.filter(item => {
			if (filterPVId && !item.purchase_voucher_id.toLowerCase().includes(filterPVId.toLowerCase().trim())) return false;
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
			if (filterBookPVId && !book.voucher_id.toLowerCase().includes(filterBookPVId.toLowerCase().trim())) return false;
			if (filterBookNumber && book.book_number !== filterBookNumber.trim()) return false;
			if (filterBookStockLocation && book.stock_locations !== filterBookStockLocation) return false;
			if (filterBookStockPerson && book.stock_persons !== filterBookStockPerson) return false;
			return true;
		}).sort((a, b) => a.voucher_id.localeCompare(b.voucher_id));
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
							stock_location_name: locationDisplay,
							stock_person_name: personDisplay
						};
					}
					return item;
				});
				applyFilters();

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
							stock_location_name: locationDisplay,
							stock_person_name: personDisplay
						};
					}
					return item;
				});
				applyFilters();

				alert(`Assignment successful for ${itemIds.length} voucher(s)!`);
				closeAssignModal();
				selectedItems.clear();
				assignMultipleMode = false;
			} else if (modalMode === 'multiple-books') {
				// Update all items for multiple selected books in a single query
				const bookIds = Array.from(selectedBooks);
				
				const { error } = await supabase
					.from('purchase_voucher_items')
					.update({
						stock_location: locationInt,
						stock_person: selectedStockPerson
					})
					.in('purchase_voucher_id', bookIds);

				if (error) {
					alert(`Error updating books: ${error.message}`);
					ignoreReloadUntil = 0; // Reset ignore flag on error
					return;
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
		voucherItems = [];
		const CHUNK_SIZE = 2000;

		try {
			// First call to get total count + first chunk
			const { data: firstData, error: firstError } = await supabase.rpc('get_pv_stock_voucher_items', { p_offset: 0, p_limit: CHUNK_SIZE });

			if (firstError) {
				console.error('Error loading voucher items via RPC:', firstError);
				voucherItems = [];
				return;
			}

			const totalCount = firstData?.total_count || 0;
			let allItems = firstData?.items || [];
			console.log(`📦 Chunk 1: ${allItems.length} items (total: ${totalCount})`);

			// Fire remaining chunks in parallel
			if (totalCount > CHUNK_SIZE) {
				const remainingChunks = [];
				for (let offset = CHUNK_SIZE; offset < totalCount; offset += CHUNK_SIZE) {
					remainingChunks.push(
						supabase.rpc('get_pv_stock_voucher_items', { p_offset: offset, p_limit: CHUNK_SIZE })
					);
				}

				const results = await Promise.all(remainingChunks);
				for (const result of results) {
					if (result.error) {
						console.error('Error loading chunk:', result.error);
					} else {
						const chunkItems = result.data?.items || [];
						allItems = [...allItems, ...chunkItems];
					}
				}
			}

			voucherItems = allItems;
			console.log(`📦 Loaded ${voucherItems.length} voucher items via parallel RPC (${Math.ceil(totalCount / CHUNK_SIZE)} chunks)`);

			// Build unique filter options
			uniquePVIds = [...new Set(voucherItems.map(i => i.purchase_voucher_id))];
			uniqueValues = [...new Set(voucherItems.map(i => i.value))];
			uniqueStatuses = [...new Set(voucherItems.map(i => i.status))];
			uniqueLocations = [...new Set(voucherItems.map(i => i.stock_location_name))];
			uniquePersons = [...new Set(voucherItems.map(i => i.stock_person_name))];

			applyFilters();
		} catch (error) {
			console.error('Error:', error);
			voucherItems = [];
		} finally {
			isLoading = false;
		}
	}

	// Manual refresh function
	function handleRefresh() {
		if (showManagePerBook) {
			loadAllData();
		} else if (showManagePerVoucher) {
			loadVoucherItems();
		}
	}

	// Export modal functions
	function openExportModal() {
		exportStockLocation = '';
		exportStockPerson = '';
		exportStockPersonSearch = '';
		showExportModal = true;
	}

	function closeExportModal() {
		showExportModal = false;
		exportStockLocation = '';
		exportStockPerson = '';
		exportStockPersonSearch = '';
	}

	async function handleExportToExcel() {
		if (!exportStockLocation || !exportStockPerson) {
			alert('Please select both Stock Location and Stock Person');
			return;
		}

		isExporting = true;
		try {
			// Get the location and person names for filtering
			const selectedBranch = branches.find(b => b.id === parseInt(exportStockLocation));
			const locationName = selectedBranch ? `${selectedBranch.name_en} - ${selectedBranch.location_en}` : '';
			
			const selectedUser = users.find(u => u.id === exportStockPerson);
			const empName = selectedUser?.employee_id ? employees.find(e => e.id === selectedUser.employee_id)?.name : null;
			const personName = empName ? `${selectedUser.username} - ${empName}` : selectedUser?.username || '';

			// Filter books by selected location and person
			const filteredData = bookSummary.filter(book => {
				const locationMatch = book.stock_locations.includes(locationName);
				const personMatch = book.stock_persons.includes(personName);
				return locationMatch && personMatch;
			});

			if (filteredData.length === 0) {
				alert('No records found matching the selected criteria');
				isExporting = false;
				return;
			}

			// Prepare Excel data
			const excelData = filteredData.map(book => ({
				'Voucher ID': book.voucher_id,
				'Book Number': book.book_number,
				'Serial Range': book.serial_range,
				'Total Count': book.total_count,
				'Total Value': book.total_value,
				'Stock Count': book.stock_count,
				'Stocked': book.stocked_count,
				'Issued': book.issued_count,
				'Closed': book.closed_count,
				'Stock Location': book.stock_locations,
				'Stock Person': book.stock_persons
			}));

			// Create workbook and worksheet
			const ws = XLSX.utils.json_to_sheet(excelData);
			const wb = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(wb, ws, 'Book Stock');

			// Generate filename with location and person
			const safeLocationName = locationName.replace(/[^a-zA-Z0-9]/g, '_');
			const safePersonName = personName.replace(/[^a-zA-Z0-9]/g, '_');
			const filename = `PV_Stock_${safeLocationName}_${safePersonName}_${new Date().toISOString().split('T')[0]}.xlsx`;

			// Download file
			XLSX.writeFile(wb, filename);

			closeExportModal();
			alert(`Successfully exported ${filteredData.length} book(s) to Excel!`);
		} catch (error) {
			console.error('Export error:', error);
			alert('Failed to export data: ' + error.message);
		} finally {
			isExporting = false;
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header / Navigation Bar -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<!-- View Mode Tabs -->
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{showManagePerBook
					? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={handleManagePerBook}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📚</span>
				<span class="relative z-10">Per Book</span>
				{#if showManagePerBook}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
			<button
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{showManagePerVoucher
					? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={handleManagePerVoucher}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🎫</span>
				<span class="relative z-10">Per Voucher</span>
				{#if showManagePerVoucher}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
			{#if showManagePerBook || showManagePerVoucher}
				<button
					class="group relative flex items-center gap-2.5 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden text-slate-500 hover:bg-white hover:text-emerald-700 hover:shadow-md"
					on:click={handleRefresh}
					title="Refresh data"
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-180">🔄</span>
					<span class="relative z-10">Refresh</span>
				</button>
			{/if}
		</div>

		<!-- Right side action buttons -->
		<div class="flex gap-2">
			{#if showManagePerBook}
				<button
					class="group flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-teal-600 text-white shadow-lg shadow-teal-200 hover:bg-teal-700 hover:shadow-xl hover:scale-[1.02]"
					on:click={openExportModal}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📊</span>
					<span>Export Excel</span>
				</button>
			{/if}
			{#if showManagePerBook && selectedBooks.size > 0}
				<button
					class="group flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-purple-600 text-white shadow-lg shadow-purple-200 hover:bg-purple-700 hover:shadow-xl hover:scale-[1.02]"
					on:click={openBatchAssignBooksModal}
				>
					<span class="text-base">✅</span>
					<span>Assign {selectedBooks.size} Book(s)</span>
				</button>
			{/if}
			{#if showManagePerVoucher && selectedItems.size > 0}
				<button
					class="group flex items-center gap-2 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl bg-purple-600 text-white shadow-lg shadow-purple-200 hover:bg-purple-700 hover:shadow-xl hover:scale-[1.02]"
					on:click={openBatchAssignModal}
				>
					<span class="text-base">✅</span>
					<span>Assign {selectedItems.size} Voucher(s)</span>
				</button>
			{/if}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">

			{#if !showManagePerBook && !showManagePerVoucher}
				<!-- Welcome / Empty State -->
				<div class="flex-1 flex items-center justify-center">
					<div class="text-center">
						<div class="text-6xl mb-4">📦</div>
						<h2 class="text-xl font-black text-slate-700 mb-2">Purchase Voucher Stock Manager</h2>
						<p class="text-sm text-slate-500">Select <strong>Per Book</strong> or <strong>Per Voucher</strong> to start managing stock</p>
					</div>
				</div>

			{:else if isLoading}
				<!-- Loading State -->
				<div class="flex items-center justify-center flex-1">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">Loading data...</p>
					</div>
				</div>

			{:else if showManagePerBook}
				<!-- ═══════════════════════════════════ Per Book View ═══════════════════════════════════ -->
				{#if bookSummary.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex-1 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">No book data found</p>
					</div>
				{:else}
					<!-- Filters Row -->
					<div class="mb-4 grid grid-cols-4 gap-3">
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterBookPVId">PV ID</label>
							<input
								id="filterBookPVId"
								type="text"
								placeholder="Search PV ID..."
								bind:value={filterBookPVId}
								on:input={handleBookFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterBookNumber">Book Number</label>
							<input
								id="filterBookNumber"
								type="text"
								placeholder="Enter book number..."
								bind:value={filterBookNumber}
								on:input={handleBookFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterBookStockLocation">Stock Location</label>
							<select id="filterBookStockLocation" bind:value={filterBookStockLocation} on:change={handleBookFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All</option>
								{#each uniqueBookLocations as location}
									<option value={location} style="color: #000 !important;">{location}</option>
								{/each}
							</select>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterBookStockPerson">Stock Person</label>
							<select id="filterBookStockPerson" bind:value={filterBookStockPerson} on:change={handleBookFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All</option>
								{#each uniqueBookPersons as person}
									<option value={person} style="color: #000 !important;">{person}</option>
								{/each}
							</select>
						</div>
					</div>

					<!-- Table Card -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 w-10">
											<input
												type="checkbox"
												checked={selectedBooks.size === filteredBookSummary.length && filteredBookSummary.length > 0}
												on:change={toggleSelectAllBooks}
												class="w-4 h-4 cursor-pointer rounded accent-emerald-300"
											/>
										</th>
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
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Action</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredBookSummary as book, index (book.voucher_id)}
										<tr class="transition-colors duration-200 {selectedBooks.has(book.voucher_id) ? 'bg-emerald-50/40' : index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} hover:bg-emerald-50/30">
											<td class="px-3 py-3 text-center">
												<input
													type="checkbox"
													checked={selectedBooks.has(book.voucher_id)}
													on:change={() => toggleSelectBook(book.voucher_id)}
													class="w-4 h-4 cursor-pointer rounded accent-emerald-500"
												/>
											</td>
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
											<td class="px-4 py-3 text-center">
												<button
													class="px-3 py-1.5 text-[10px] font-black uppercase tracking-wide bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-all duration-200 hover:shadow-md"
													on:click={() => openAssignModal(book)}
												>Assign</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<!-- Footer -->
						<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
							Showing {filteredBookSummary.length} books {filterBookPVId || filterBookNumber || filterBookStockLocation || filterBookStockPerson ? `(filtered from ${bookSummary.length})` : ''}
						</div>
					</div>
				{/if}

			{:else if showManagePerVoucher}
				<!-- ═══════════════════════════════════ Per Voucher View ═══════════════════════════════════ -->
				{#if voucherItems.length === 0}
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex-1 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-600 font-semibold">No voucher items found</p>
					</div>
				{:else}
					<!-- Filters Row -->
					<div class="mb-4 grid grid-cols-6 gap-3">
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterPVId">PV ID</label>
							<input
								id="filterPVId"
								type="text"
								placeholder="Search PV ID..."
								bind:value={filterPVId}
								on:input={handleFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterSerialNumber">Serial #</label>
							<input
								id="filterSerialNumber"
								type="text"
								placeholder="Exact serial..."
								bind:value={filterSerialNumber}
								on:input={handleFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterValue">Value</label>
							<input
								id="filterValue"
								type="text"
								placeholder="Exact value..."
								bind:value={filterValue}
								on:input={handleFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							/>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterStatus">Status</label>
							<select id="filterStatus" bind:value={filterStatus} on:change={handleFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All</option>
								{#each uniqueStatuses as status}
									<option value={status} style="color: #000 !important;">{status}</option>
								{/each}
							</select>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterStockLocation">Location</label>
							<select id="filterStockLocation" bind:value={filterStockLocation} on:change={handleFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All</option>
								{#each uniqueLocations as location}
									<option value={location} style="color: #000 !important;">{location}</option>
								{/each}
							</select>
						</div>
						<div>
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="filterStockPerson">Person</label>
							<select id="filterStockPerson" bind:value={filterStockPerson} on:change={handleFilterChange}
								class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
								style="color: #000 !important; background-color: #fff !important;">
								<option value="" style="color: #000 !important;">All</option>
								{#each uniquePersons as person}
									<option value={person} style="color: #000 !important;">{person}</option>
								{/each}
							</select>
						</div>
					</div>

					<!-- Table Card -->
					<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
						<div class="overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-10">
											<input
												type="checkbox"
												checked={selectedItems.size === filteredVoucherItems.length && filteredVoucherItems.length > 0}
												on:change={toggleSelectAll}
												class="w-4 h-4 cursor-pointer rounded accent-blue-300"
											/>
										</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">PV ID</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Serial #</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Value</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Stock</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Status</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Issue Type</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Location</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Person</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Action</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredVoucherItems as item, index (item.id)}
										<tr class="transition-colors duration-200 {selectedItems.has(item.id) ? 'bg-blue-50/40' : index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} hover:bg-blue-50/30">
											<td class="px-3 py-3 text-center">
												<input
													type="checkbox"
													checked={selectedItems.has(item.id)}
													on:change={() => toggleSelectItem(item.id)}
													class="w-4 h-4 cursor-pointer rounded accent-blue-500"
												/>
											</td>
											<td class="px-4 py-3 text-sm text-slate-700 font-semibold">{item.purchase_voucher_id}</td>
											<td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{item.serial_number}</td>
											<td class="px-4 py-3 text-sm text-center font-bold text-emerald-700">{item.value}</td>
											<td class="px-4 py-3 text-sm text-center text-slate-600">{item.stock}</td>
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
											<td class="px-4 py-3 text-xs text-center text-slate-600">{item.issue_type || '—'}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.stock_location_name}</td>
											<td class="px-4 py-3 text-xs text-slate-500">{item.stock_person_name}</td>
											<td class="px-4 py-3 text-center">
												<button
													class="px-3 py-1.5 text-[10px] font-black uppercase tracking-wide bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-all duration-200 hover:shadow-md"
													on:click={() => openAssignItemModal(item)}
												>Assign</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<!-- Footer -->
						<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
							Showing {filteredVoucherItems.length} of {voucherItems.length} vouchers {filterPVId || filterSerialNumber || filterValue || filterStatus || filterStockLocation || filterStockPerson ? '(filtered)' : ''}
						</div>
					</div>
				{/if}
			{/if}
		</div>
	</div>
</div>

<!-- ═══════════════════════════════════ Assign Modal ═══════════════════════════════════ -->
{#if showAssignModal}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[1000]" on:click={closeAssignModal}>
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
		<div class="bg-white rounded-2xl shadow-2xl max-w-xl w-[90%] max-h-[90vh] overflow-y-auto" on:click|stopPropagation>
			<div class="flex justify-between items-center px-6 py-4 border-b border-slate-200">
				<h3 class="text-base font-black text-slate-800 flex items-center gap-2">
					<span class="w-8 h-8 rounded-lg bg-emerald-100 flex items-center justify-center text-lg">📌</span>
					Assign Stock —
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
				<button class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors text-xl" on:click={closeAssignModal}>&times;</button>
			</div>

			<div class="p-6 space-y-5">
				<div>
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="stockLocation">Stock Location (Branch)</label>
					<select id="stockLocation" bind:value={selectedStockLocation}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
						style="color: #000 !important; background-color: #fff !important;">
						<option value="" style="color: #000 !important;">— Select Branch —</option>
						{#each branches as branch (branch.id)}
							<option value={branch.id} style="color: #000 !important;">{branch.name_en} - {branch.location_en}</option>
						{/each}
					</select>
				</div>

				<div>
					<!-- svelte-ignore a11y-label-has-associated-control -->
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Stock Person</label>
					<input
						type="text"
						placeholder="Search users..."
						bind:value={stockPersonSearch}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all mb-2"
					/>
					<div class="flex flex-col gap-1.5 max-h-[250px] overflow-y-auto p-2 border border-slate-200 rounded-xl bg-slate-50">
						{#each users.filter(u => u.username.toLowerCase().includes(stockPersonSearch.toLowerCase())) as user (user.id)}
							{@const employee = employees.find(e => e.id === user.employee_id)}
							<label class="flex items-center gap-2.5 cursor-pointer px-3 py-2 rounded-lg hover:bg-emerald-50 transition-colors {selectedStockPerson === user.id ? 'bg-emerald-100 ring-1 ring-emerald-300' : ''}">
								<input
									type="radio"
									name="stockPerson"
									value={user.id}
									bind:group={selectedStockPerson}
									class="accent-emerald-600"
								/>
								<span class="text-sm text-slate-700">{user.username} - {employee?.name || 'N/A'}</span>
							</label>
						{/each}
					</div>
				</div>
			</div>

			<div class="flex gap-3 justify-end px-6 py-4 border-t border-slate-200">
				<button
					class="px-5 py-2.5 text-xs font-black uppercase tracking-wide bg-slate-200 text-slate-700 rounded-xl hover:bg-slate-300 transition-all"
					on:click={closeAssignModal}
				>Cancel</button>
				<button
					class="px-5 py-2.5 text-xs font-black uppercase tracking-wide bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 hover:shadow-lg shadow-emerald-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={handleAssignSubmit}
					disabled={!selectedStockLocation || !selectedStockPerson}
				>Assign</button>
			</div>
		</div>
	</div>
{/if}

<!-- ═══════════════════════════════════ Export Modal ═══════════════════════════════════ -->
{#if showExportModal}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[1000]" on:click={closeExportModal}>
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
		<div class="bg-white rounded-2xl shadow-2xl max-w-xl w-[90%] max-h-[90vh] overflow-y-auto" on:click|stopPropagation>
			<div class="flex justify-between items-center px-6 py-4 border-b border-slate-200">
				<h3 class="text-base font-black text-slate-800 flex items-center gap-2">
					<span class="w-8 h-8 rounded-lg bg-teal-100 flex items-center justify-center text-lg">📊</span>
					Export to Excel
				</h3>
				<button class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors text-xl" on:click={closeExportModal}>&times;</button>
			</div>

			<div class="p-6 space-y-5">
				<div class="p-3 bg-blue-50 rounded-xl text-sm text-blue-700 font-medium">
					Select the Stock Location and Stock Person to filter and export.
				</div>

				<div>
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="exportStockLocation">Stock Location (Branch)</label>
					<select id="exportStockLocation" bind:value={exportStockLocation}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all"
						style="color: #000 !important; background-color: #fff !important;">
						<option value="" style="color: #000 !important;">— Select Branch —</option>
						{#each branches as branch (branch.id)}
							<option value={branch.id} style="color: #000 !important;">{branch.name_en} - {branch.location_en}</option>
						{/each}
					</select>
				</div>

				<div>
					<!-- svelte-ignore a11y-label-has-associated-control -->
					<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Stock Person</label>
					<input
						type="text"
						placeholder="Search users..."
						bind:value={exportStockPersonSearch}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent transition-all mb-2"
					/>
					<div class="flex flex-col gap-1.5 max-h-[250px] overflow-y-auto p-2 border border-slate-200 rounded-xl bg-slate-50">
						{#each users.filter(u => {
							const emp = employees.find(e => e.id === u.employee_id);
							const searchTerm = exportStockPersonSearch.toLowerCase();
							return u.username.toLowerCase().includes(searchTerm) || (emp?.name || '').toLowerCase().includes(searchTerm);
						}) as user (user.id)}
							{@const employee = employees.find(e => e.id === user.employee_id)}
							<label class="flex items-center gap-2.5 cursor-pointer px-3 py-2 rounded-lg hover:bg-teal-50 transition-colors {exportStockPerson === user.id ? 'bg-teal-100 ring-1 ring-teal-300' : ''}">
								<input
									type="radio"
									name="exportStockPerson"
									value={user.id}
									bind:group={exportStockPerson}
									class="accent-teal-600"
								/>
								<span class="text-sm text-slate-700">{user.username} - {employee?.name || 'N/A'}</span>
							</label>
						{/each}
					</div>
				</div>
			</div>

			<div class="flex gap-3 justify-end px-6 py-4 border-t border-slate-200">
				<button
					class="px-5 py-2.5 text-xs font-black uppercase tracking-wide bg-slate-200 text-slate-700 rounded-xl hover:bg-slate-300 transition-all"
					on:click={closeExportModal}
				>Cancel</button>
				<button
					class="px-5 py-2.5 text-xs font-black uppercase tracking-wide bg-teal-600 text-white rounded-xl hover:bg-teal-700 hover:shadow-lg shadow-teal-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={handleExportToExcel}
					disabled={isExporting || !exportStockLocation || !exportStockPerson}
				>
					{isExporting ? 'Exporting...' : 'Export'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}
</style>
