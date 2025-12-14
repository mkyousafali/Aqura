<script>
	import { onMount } from 'svelte';
	import ClearanceCertificateManager from './ClearanceCertificateManager.svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { realtimeService } from '$lib/utils/realtimeService';

	// State for receiving records
	let receivingRecords = [];
	let filteredRecords = [];
	let paginatedRecords = [];
	let archivedRecords = [];
	let searchTerm = '';
	let filterVendorId = '';
	let filterVatNumber = '';
	let filterVendorName = '';
	let filterFromDays = '';
	let filterToDays = '';
	let filterOverdueDays = '';
	let selectedBranch = '';
	let branchFilterMode = 'all'; // 'all', 'branch'
	let branches = [];
	let loading = false;
	let uploadingBillId = null;
	let uploadingExcelId = null;
	let generatingCertificateId = null;
	let updatingBillId = null;
	let deletingRecordId = null;
	let showArchived = false; // Toggle for archived records

	// Pagination state (disabled UI but optimized loading)
	let currentPage = 1;
	let pageSize = 50; // Load 50 records at once (faster initial load, less data per query)
	let totalPages = 1;
	let totalRecords = 0;

	// Cache for branches, vendors, users to avoid refetching
	let branchCache = new Map();
	let vendorCache = new Map();
	let userCache = new Map();

	// Real-time subscription unsubscribe functions
	let unsubscribeReceivingRecords = null;
	let unsubscribePaymentSchedule = null;

	// Check if current user is master admin
	$: isMasterAdmin = $currentUser?.isMasterAdmin;

	// Certificate generation state
	let showCertificateModal = false;
	let selectedRecordForCertificate = null;

	// ERP Reference popup state
	let showErpPopup = false;
	let selectedRecord = null;
	let erpReferenceValue = '';
	let updatingErp = false;

	onMount(() => {
		loadBranches();
		loadReceivingRecords();
		setupRealtimeSubscriptions();
		
		return () => {
			if (unsubscribeReceivingRecords) {
				unsubscribeReceivingRecords();
			}
			if (unsubscribePaymentSchedule) {
				unsubscribePaymentSchedule();
			}
		};
	});

	async function loadBranches() {
		try {
			console.log('🔍 Loading branches...');
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en');

			if (error) throw error;
			branches = data || [];
			console.log('🔍 Branches loaded:', branches.length);
		} catch (err) {
			console.error('Error loading branches:', err);
			branches = [];
		}
	}

	async function setupRealtimeSubscriptions() {
		try {
			console.log('📡 Setting up real-time subscriptions for receiving records table...');

			// Subscribe to receiving_records changes
			unsubscribeReceivingRecords = realtimeService.subscribeToReceivingRecordsChanges(
				async (payload) => {
					console.log('🔔 Real-time receiving record update:', {
						event: payload.eventType,
						recordId: payload.new?.id || payload.old?.id
					});

					// Handle different event types
					if (payload.eventType === 'INSERT') {
						console.log('✨ New record inserted, reloading...');
						await loadReceivingRecords();
					} else if (payload.eventType === 'UPDATE') {
						console.log('📝 Record updated, refreshing...');
						// Update the specific record in the local array
						const updatedRecord = payload.new;
						const index = receivingRecords.findIndex(r => r.id === updatedRecord.id);
						if (index !== -1) {
							receivingRecords[index] = { ...receivingRecords[index], ...updatedRecord };
							applyFilters();
						}
					} else if (payload.eventType === 'DELETE') {
						console.log('🗑️ Record deleted, updating list...');
						// Remove the deleted record from local array
						receivingRecords = receivingRecords.filter(r => r.id !== payload.old?.id);
						applyFilters();
					}
				}
			);

			// Subscribe to vendor_payment_schedule changes
			unsubscribePaymentSchedule = realtimeService.subscribeToVendorPaymentScheduleChanges(
				(payload) => {
					const receivingRecordId = payload.new?.receiving_record_id || payload.old?.receiving_record_id;
					console.log('💳 Real-time payment schedule update:', {
						event: payload.eventType,
						receivingRecordId: receivingRecordId,
						newData: payload.new
					});

					// Update the specific record's verification status from the payment schedule change
					if (payload.eventType === 'UPDATE' && payload.new) {
						const recordIndex = receivingRecords.findIndex(r => r.id === receivingRecordId);
						if (recordIndex !== -1) {
							console.log('📝 Updating verification status for record:', receivingRecordId);
							// Update verification status from the payment schedule
							receivingRecords[recordIndex].pr_excel_verified = payload.new.pr_excel_verified;
							receivingRecords[recordIndex].pr_excel_verified_by = payload.new.pr_excel_verified_by;
							receivingRecords[recordIndex].pr_excel_verified_date = payload.new.pr_excel_verified_date;
							if (receivingRecords[recordIndex].schedule_status) {
								receivingRecords[recordIndex].schedule_status.pr_excel_verified = payload.new.pr_excel_verified;
								receivingRecords[recordIndex].schedule_status.pr_excel_verified_by = payload.new.pr_excel_verified_by;
								receivingRecords[recordIndex].schedule_status.pr_excel_verified_date = payload.new.pr_excel_verified_date;
							}
							receivingRecords = [...receivingRecords]; // Trigger reactivity
							applyFilters();
						}
					}
				}
			);

			console.log('✅ Real-time subscriptions setup complete');
		} catch (error) {
			console.error('❌ Error setting up real-time subscriptions:', error);
		}
	}

	async function loadReceivingRecords() {
		loading = true;
		try {
			const startTime = performance.now();
			const { supabase } = await import('$lib/utils/supabase');
			
			console.log('📋 Starting optimized receiving records load (lazy loading - load on scroll)...');
			
			// First, get the TOTAL COUNT of records (no limit)
			const { count: totalCount, error: countError } = await supabase
				.from('receiving_records')
				.select('*', { count: 'exact', head: true });

			if (countError) throw countError;

			totalRecords = totalCount || 0;
			totalPages = Math.ceil(totalRecords / pageSize);
			console.log(`📊 Total receiving records available: ${totalRecords}, Pages: ${totalPages}`);

			// Load ONLY the first page initially (2000 records)
			await loadPageData(1);
			
			const endTime = performance.now();
			console.log(`✅ First batch (2000 records) loaded in ${(endTime - startTime).toFixed(0)}ms. More loads on scroll...`);
		} catch (err) {
			console.error('Error in loadReceivingRecords:', err);
			receivingRecords = [];
		} finally {
			loading = false;
		}
	}

	// Load data for a specific page
	async function loadPageData(pageNum) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const startIdx = (pageNum - 1) * pageSize;

			console.log(`📄 Loading page ${pageNum}/${totalPages} (offset: ${startIdx}, limit: ${pageSize})...`);
			
			// 1️⃣ Load ONLY records for current page (no nested JOINs)
			// Note: order BEFORE range for proper pagination
			const { data: records, error: recordsError } = await supabase
				.from('receiving_records')
				.select('id, bill_number, vendor_id, branch_id, bill_date, bill_amount, created_at, user_id, original_bill_url, erp_purchase_invoice_reference, certificate_url, due_date, pr_excel_file_url, final_bill_amount, payment_method, credit_period, bank_name, iban')
				.order('created_at', { ascending: false })
				.range(startIdx, startIdx + pageSize - 1);

			if (recordsError) {
				console.error(`❌ Error loading page ${pageNum}:`, recordsError);
				throw recordsError;
			}

			if (!records || records.length === 0) {
				console.log(`📊 No records on page ${pageNum}`);
				receivingRecords = [];
				updatePaginatedRecords();
				return;
			}

		console.log(`📊 Loaded ${records.length} records for page ${pageNum}`);

		// Get uncached IDs only - avoid refetching known data
		const uniqueBranchIds = [...new Set(records.map(r => r.branch_id))].filter(id => !branchCache.has(id));
		const uniqueVendorIds = [...new Set(records.map(r => r.vendor_id))];
		const uniqueUserIds = [...new Set(records.map(r => r.user_id).filter(Boolean))].filter(id => !userCache.has(id));
		const recordIds = records.map(r => r.id);
		
		const chunkArray = (array, size) => {
			const chunks = [];
			for (let i = 0; i < array.length; i += size) {
				chunks.push(array.slice(i, i + size));
			}
			return chunks;
		};

		const scheduleChunks = chunkArray(recordIds, 25);
		console.log(`⚡ Loading in parallel: ${uniqueBranchIds.length ? 'branches' : 'cache'}, vendors (${uniqueVendorIds.length} IDs), ${uniqueUserIds.length ? 'users' : 'cache'}, payment schedules (${scheduleChunks.length} chunks)...`);
		
		// Load branches, vendors, users FIRST (fast queries)
		const [branchResult, vendorResult, userResult] = await Promise.all([
			uniqueBranchIds.length > 0 
				? supabase.from('branches').select('id, name_en').in('id', uniqueBranchIds)
				: Promise.resolve({ data: [] }),
			uniqueVendorIds.length > 0
				? supabase.from('vendors').select('erp_vendor_id, vendor_name, vat_number, branch_id').in('erp_vendor_id', uniqueVendorIds)
				: Promise.resolve({ data: [] }),
			uniqueUserIds.length > 0
				? supabase.from('users').select('id, username, hr_employees(name)').in('id', uniqueUserIds)
				: Promise.resolve({ data: [] })
		]);

		// Update caches with newly fetched data
		branchResult.data?.forEach(b => branchCache.set(b.id, b));
		// Store vendors by composite key in vendorCache
		vendorResult.data?.forEach(v => {
			const compositeKey = `${v.erp_vendor_id}_${v.branch_id}`;
			vendorCache.set(compositeKey, v);
		});
		userResult.data?.forEach(u => userCache.set(u.id, u));

		// Get all data from cache (old + new)
		const branchMap = new Map([...Array.from(branchCache.entries())]);
		const vendorMap = new Map([...Array.from(vendorCache.entries())]);
		const userMap = new Map([...Array.from(userCache.entries())]);
		
		// SHOW RECORDS IMMEDIATELY without waiting for payment schedules
		const recordsWithDetails = records.map(record => ({
			...record,
			branches: branchMap.get(record.branch_id),
			vendors: vendorMap.get(`${record.vendor_id}_${record.branch_id}`),
			users: userMap.get(record.user_id),
			schedule_status: null, // Will be updated when payment schedules load
			is_scheduled: false,
			has_multiple_schedules: false,
			pr_excel_verified: false,
			pr_excel_verified_by: null,
			pr_excel_verified_date: null
		}));

		receivingRecords = recordsWithDetails;
		updatePaginatedRecords();
		console.log(`✅ Page ${pageNum} data shown immediately (${recordsWithDetails.length} records) - loading payment schedules in background...`);

		// Load payment schedules in background (don't wait for this)
		scheduleChunks.forEach((chunk, idx) => {
			supabase
				.from('vendor_payment_schedule')
				.select('receiving_record_id, is_paid, pr_excel_verified, pr_excel_verified_by, pr_excel_verified_date')
				.in('receiving_record_id', chunk)
				.then(result => {
					if (!result.error && result.data) {
						// Update the records with schedule data
						result.data.forEach(schedule => {
							const recordIdx = receivingRecords.findIndex(r => r.id === schedule.receiving_record_id);
							if (recordIdx >= 0) {
								receivingRecords[recordIdx].schedule_status = schedule;
								receivingRecords[recordIdx].is_paid = schedule.is_paid;
								receivingRecords[recordIdx].is_scheduled = true;
								// Pull verification status from payment schedule
								receivingRecords[recordIdx].pr_excel_verified = schedule.pr_excel_verified;
								receivingRecords[recordIdx].pr_excel_verified_by = schedule.pr_excel_verified_by;
								receivingRecords[recordIdx].pr_excel_verified_date = schedule.pr_excel_verified_date;
							}
						});
						receivingRecords = [...receivingRecords]; // Trigger reactivity
						updatePaginatedRecords(); // Update the visible records
						console.log(`📦 Schedule chunk ${idx + 1} loaded in background`);
					}
				})
				.catch(err => console.warn(`⚠️ Schedule chunk ${idx + 1} error:`, err.message));
		});
	} catch (err) {
		console.error(`Error loading page ${pageNum}:`, err);
		receivingRecords = [];
		updatePaginatedRecords();
		}
	}

	// Load archived records on-demand
	async function loadArchivedRecords() {
		try {
			const startTime = performance.now();
			const { supabase } = await import('$lib/utils/supabase');
			
			console.log('📦 Loading archived records on-demand...');
			
		const { data: records, error: recordsError } = await supabase
			.from('receiving_records')
			.select('id, bill_number, vendor_id, branch_id, bill_date, bill_amount, created_at, user_id, original_bill_url, erp_purchase_invoice_reference, certificate_url, due_date, pr_excel_file_url, final_bill_amount, payment_method, credit_period, bank_name, iban')
			.order('created_at', { ascending: false })
			.limit(200);			if (recordsError) throw recordsError;

			if (!records || records.length === 0) {
				const endTime = performance.now();
				console.log(`✅ No archived records found in ${(endTime - startTime).toFixed(0)}ms`);
				return;
			}

			// Fetch details in bulk for archived records
			const uniqueBranchIds = [...new Set(records.map(r => r.branch_id))];
			const uniqueVendorIds = [...new Set(records.map(r => r.vendor_id))];
			const uniqueUserIds = [...new Set(records.map(r => r.user_id).filter(Boolean))];

			const [branchResult, vendorResult, userResult] = await Promise.all([
				supabase.from('branches').select('id, name_en').in('id', uniqueBranchIds),
				supabase.from('vendors').select('erp_vendor_id, vendor_name, vat_number, salesman_name, salesman_contact, branch_id').in('erp_vendor_id', uniqueVendorIds),
				supabase.from('users').select('id, username, hr_employees(name)').in('id', uniqueUserIds)
			]);

			const branchMap = new Map(branchResult.data?.map(b => [b.id, b]) || []);
			const vendorMap = new Map();
			vendorResult.data?.forEach(vendor => {
				const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
				vendorMap.set(key, vendor);
			});
			const userMap = new Map(userResult.data?.map(u => [u.id, u]) || []);

			const recordsWithDetails = records.map(record => ({
				...record,
				branches: branchMap.get(record.branch_id),
				vendors: vendorMap.get(`${record.vendor_id}_${record.branch_id}`),
				users: userMap.get(record.user_id)
			}));

			archivedRecords = recordsWithDetails;
			const endTime = performance.now();
			console.log(`✅ Archived records loaded in ${(endTime - startTime).toFixed(0)}ms (${recordsWithDetails.length} records)`);
		} catch (error) {
			console.error('Error loading archived records:', error);
		}
	}

	// Reactive: Load archived records when toggle is checked
	$: if (showArchived && archivedRecords.length === 0) {
		loadArchivedRecords();
	}

	function applyFilters() {
		// Apply filters based on filter state
		let filtered = [...receivingRecords];

		// Apply search term filter
		if (searchTerm && String(searchTerm).trim() !== '') {
			const searchLower = String(searchTerm).toLowerCase();
			filtered = filtered.filter(record => {
				const billNumber = (record.bill_number || '').toLowerCase();
				const vendorName = (record.vendors?.vendor_name || '').toLowerCase();
				const vatNumber = (record.vendors?.vat_number || '').toLowerCase();
				const reviewerName = (record.users?.hr_employees?.name || record.users?.username || '').toLowerCase();
				
				return billNumber.includes(searchLower) ||
					   vendorName.includes(searchLower) ||
					   vatNumber.includes(searchLower) ||
					   reviewerName.includes(searchLower);
			});
		}

		// Apply branch filter
		if (selectedBranch && String(selectedBranch).trim() !== '') {
			filtered = filtered.filter(record => record.branch_id === selectedBranch);
		}

		// Apply vendor ID filter
		if (filterVendorId && String(filterVendorId).trim() !== '') {
			filtered = filtered.filter(record => {
				const vendorId = (record.vendors?.erp_vendor_id || '').toString();
				return vendorId.includes(String(filterVendorId).trim());
			});
		}

		// Apply VAT number filter
		if (filterVatNumber && String(filterVatNumber).trim() !== '') {
			filtered = filtered.filter(record => {
				const vatNumber = (record.vendors?.vat_number || '').toLowerCase();
				return vatNumber.includes(String(filterVatNumber).toLowerCase());
			});
		}

		// Apply vendor name filter
		if (filterVendorName && String(filterVendorName).trim() !== '') {
			filtered = filtered.filter(record => {
				const vendorName = (record.vendors?.vendor_name || '').toLowerCase();
				return vendorName.includes(String(filterVendorName).toLowerCase());
			});
		}

		// Apply days range filter
		if ((filterFromDays !== '' && filterFromDays !== null) || (filterToDays !== '' && filterToDays !== null)) {
			filtered = filtered.filter(record => {
				const billDate = new Date(record.bill_date);
				const today = new Date();
				const daysAgo = Math.floor((today - billDate) / (1000 * 60 * 60 * 24));
				
				const fromDays = filterFromDays !== '' && filterFromDays !== null ? parseInt(filterFromDays) : -Infinity;
				const toDays = filterToDays !== '' && filterToDays !== null ? parseInt(filterToDays) : Infinity;
				
				return daysAgo >= fromDays && daysAgo <= toDays;
			});
		}

		// Apply overdue days filter
		if (filterOverdueDays !== '' && filterOverdueDays !== null) {
			const overdueDays = parseInt(filterOverdueDays);
			filtered = filtered.filter(record => {
				const dueDate = new Date(record.due_date);
				const today = new Date();
				const daysSinceDue = Math.floor((today - dueDate) / (1000 * 60 * 60 * 24));
				return daysSinceDue >= overdueDays;
			});
		}

		// Apply archived filter
		if (showArchived) {
			filtered = [...filtered, ...archivedRecords];
		}

		filteredRecords = filtered;
		currentPage = 1;
		console.log(`🔍 Filters applied: ${filtered.length} records match filters`);
		updatePaginatedRecords();
	}

	// Load paginated data for filtered results - optimized to load only needed records
	async function loadFilteredPageData(pageNum, filterCriteria) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			console.log(`📄 Loading filtered page ${pageNum}...`);

		// For branch filter, we can use database query
		if (filterCriteria.selectedBranch && !filterCriteria.searchTerm && !filterCriteria.filterVatNumber && 
		    !filterCriteria.filterVendorName && 
		    filterCriteria.filterFromDays === null && filterCriteria.filterToDays === null && 
		    filterCriteria.filterOverdueDays === null) {
			// Simple branch filter (with optional vendor ID) - use database
			const startIdx = (pageNum - 1) * pageSize;
			const { data: records, error: recordsError, count } = await supabase
				.from('receiving_records')
				.select('id, bill_number, vendor_id, branch_id, bill_date, bill_amount, created_at, user_id, original_bill_url, erp_purchase_invoice_reference, certificate_url, due_date, pr_excel_file_url, final_bill_amount, payment_method, credit_period, bank_name, iban', { count: 'exact' })
				.eq('branch_id', filterCriteria.selectedBranch)
				.order('created_at', { ascending: false })
				.range(startIdx, startIdx + pageSize - 1);

			if (recordsError) throw recordsError;

			// Get total count for pagination
			const { count: totalCount } = await supabase
				.from('receiving_records')
				.select('*', { count: 'exact', head: true })
				.eq('branch_id', filterCriteria.selectedBranch);

			totalRecords = totalCount || 0;
			totalPages = Math.ceil(totalRecords / pageSize);

			if (!records || records.length === 0) {
				receivingRecords = [];
				filteredRecords = [];
				updatePaginatedRecords();
				return;
			}

			// Fetch related data for these records only
			const uniqueBranchIds = [...new Set(records.map(r => r.branch_id))];
			const uniqueVendorIds = [...new Set(records.map(r => r.vendor_id))];
			const uniqueUserIds = [...new Set(records.map(r => r.user_id).filter(Boolean))];

			const [branchResult, vendorResult, userResult] = await Promise.all([
				supabase.from('branches').select('id, name_en').in('id', uniqueBranchIds),
				supabase.from('vendors').select('erp_vendor_id, vendor_name, vat_number, salesman_name, salesman_contact, branch_id').in('erp_vendor_id', uniqueVendorIds),
				supabase.from('users').select('id, username, hr_employees(name)').in('id', uniqueUserIds)
			]);

			const branchMap = new Map(branchResult.data?.map(b => [b.id, b]) || []);
			const vendorMap = new Map();
			vendorResult.data?.forEach(vendor => {
				const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
				vendorMap.set(key, vendor);
			});
			const userMap = new Map(userResult.data?.map(u => [u.id, u]) || []);

			let recordsWithDetails = records.map(record => ({
				...record,
				branches: branchMap.get(record.branch_id),
				vendors: vendorMap.get(`${record.vendor_id}_${record.branch_id}`),
				users: userMap.get(record.user_id)
			}));

			// Apply vendor ID filter if present
			if (filterCriteria.filterVendorId) {
				recordsWithDetails = recordsWithDetails.filter(r => {
					if (r.vendors?.erp_vendor_id) {
						return r.vendors.erp_vendor_id.toString().includes(filterCriteria.filterVendorId);
					}
					return r.vendor_id.toString().includes(filterCriteria.filterVendorId);
				});
			}

			receivingRecords = recordsWithDetails;
			filteredRecords = recordsWithDetails;
			console.log(`✅ Loaded ${recordsWithDetails.length} filtered records for page ${pageNum}`);
			updatePaginatedRecords();
			return;
		}

		// Fast search-only path - load only first 200 records for searching
		if (filterCriteria.searchTerm && !filterCriteria.selectedBranch && !filterCriteria.filterVendorId && 
		    !filterCriteria.filterVatNumber && !filterCriteria.filterVendorName && 
		    filterCriteria.filterFromDays === null && filterCriteria.filterToDays === null && 
		    filterCriteria.filterOverdueDays === null) {
			console.log(`📄 Fast search path - loading records for search...`);
			
			// Load records to search through
			const { data: records, error: recordsError } = await supabase
				.from('receiving_records')
				.select('id, bill_number, vendor_id, branch_id, bill_date, bill_amount, created_at, user_id, original_bill_url, erp_purchase_invoice_reference, certificate_url, due_date, pr_excel_file_url, final_bill_amount, payment_method, credit_period, bank_name, iban')
				.order('created_at', { ascending: false })
				.limit(200);

			if (recordsError) throw recordsError;

			if (!records || records.length === 0) {
				receivingRecords = [];
				filteredRecords = [];
				totalRecords = 0;
				totalPages = 1;
				updatePaginatedRecords();
				return;
			}

			// Fetch related data in bulk
			const uniqueBranchIds = [...new Set(records.map(r => r.branch_id))];
			const uniqueVendorIds = [...new Set(records.map(r => r.vendor_id))];
			const uniqueUserIds = [...new Set(records.map(r => r.user_id).filter(Boolean))];

			const [branchResult, vendorResult, userResult] = await Promise.all([
				supabase.from('branches').select('id, name_en').in('id', uniqueBranchIds),
				supabase.from('vendors').select('erp_vendor_id, vendor_name, vat_number, salesman_name, salesman_contact, branch_id').in('erp_vendor_id', uniqueVendorIds),
				supabase.from('users').select('id, username, hr_employees(name)').in('id', uniqueUserIds)
			]);

			const branchMap = new Map(branchResult.data?.map(b => [b.id, b]) || []);
			const vendorMap = new Map();
			vendorResult.data?.forEach(vendor => {
				const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
				vendorMap.set(key, vendor);
			});
			const userMap = new Map(userResult.data?.map(u => [u.id, u]) || []);

			// Merge data
			const recordsWithDetails = records.map(record => ({
				...record,
				branches: branchMap.get(record.branch_id),
				vendors: vendorMap.get(`${record.vendor_id}_${record.branch_id}`),
				users: userMap.get(record.user_id)
			}));

			// Apply search filter
			let filtered = recordsWithDetails;
			const searchLower = filterCriteria.searchTerm.toLowerCase();
			filtered = filtered.filter(r => {
				const billNumber = (r.bill_number || '').toLowerCase();
				const vendorName = (r.vendors?.vendor_name || '').toLowerCase();
				const vatNumber = (r.vendors?.vat_number || '').toLowerCase();
				const reviewerName = (r.users?.hr_employees?.name || r.users?.username || '').toLowerCase();
				return billNumber.includes(searchLower) || vendorName.includes(searchLower) || 
				       vatNumber.includes(searchLower) || reviewerName.includes(searchLower);
			});

			// Paginate search results
			const startIdx = (pageNum - 1) * pageSize;
			const paginatedFiltered = filtered.slice(startIdx, startIdx + pageSize);
			
			totalRecords = filtered.length;
			totalPages = Math.ceil(filtered.length / pageSize);
			
			receivingRecords = paginatedFiltered;
			filteredRecords = filtered;
			
			console.log(`✅ Search found ${paginatedFiltered.length} matching records (total: ${filtered.length})`);
			updatePaginatedRecords();
			return;
		}

		// Complex filters - need to load more records for in-memory filtering
			// Load first 500 records to filter from
			const { data: records, error: recordsError } = await supabase
				.from('receiving_records')
				.select('id, bill_number, vendor_id, branch_id, bill_date, bill_amount, created_at, user_id, original_bill_url, erp_purchase_invoice_reference, certificate_url, due_date, pr_excel_file_url, final_bill_amount, payment_method, credit_period, bank_name, iban')
				.order('created_at', { ascending: false })
				.limit(500);

			if (recordsError) throw recordsError;

			if (!records || records.length === 0) {
				receivingRecords = [];
				filteredRecords = [];
				totalRecords = 0;
				totalPages = 1;
				updatePaginatedRecords();
				return;
			}

			// Fetch related data in bulk
			const uniqueBranchIds = [...new Set(records.map(r => r.branch_id))];
			const uniqueVendorIds = [...new Set(records.map(r => r.vendor_id))];
			const uniqueUserIds = [...new Set(records.map(r => r.user_id).filter(Boolean))];

			const [branchResult, vendorResult, userResult] = await Promise.all([
				supabase.from('branches').select('id, name_en').in('id', uniqueBranchIds),
				supabase.from('vendors').select('erp_vendor_id, vendor_name, vat_number, salesman_name, salesman_contact, branch_id').in('erp_vendor_id', uniqueVendorIds),
				supabase.from('users').select('id, username, hr_employees(name)').in('id', uniqueUserIds)
			]);

			const branchMap = new Map(branchResult.data?.map(b => [b.id, b]) || []);
			const vendorMap = new Map();
			vendorResult.data?.forEach(vendor => {
				const key = `${vendor.erp_vendor_id}_${vendor.branch_id}`;
				vendorMap.set(key, vendor);
			});
			const userMap = new Map(userResult.data?.map(u => [u.id, u]) || []);

			// Merge data
			const recordsWithDetails = records.map(record => ({
				...record,
				branches: branchMap.get(record.branch_id),
				vendors: vendorMap.get(`${record.vendor_id}_${record.branch_id}`),
				users: userMap.get(record.user_id)
			}));

			// Apply filters in-memory
			let filtered = [...recordsWithDetails];

			if (filterCriteria.searchTerm) {
				const searchLower = filterCriteria.searchTerm.toLowerCase();
				filtered = filtered.filter(r => {
					const billNumber = (r.bill_number || '').toLowerCase();
					const vendorName = (r.vendors?.vendor_name || '').toLowerCase();
					const vatNumber = (r.vendors?.vat_number || '').toLowerCase();
					const reviewerName = (r.users?.hr_employees?.name || r.users?.username || '').toLowerCase();
					return billNumber.includes(searchLower) || vendorName.includes(searchLower) || 
					       vatNumber.includes(searchLower) || reviewerName.includes(searchLower);
				});
			}

			if (filterCriteria.selectedBranch) {
				filtered = filtered.filter(r => r.branch_id === filterCriteria.selectedBranch);
			}

			if (filterCriteria.filterVendorId) {
				filtered = filtered.filter(r => {
					// Check if vendor data exists, if not, match against raw vendor_id
					if (r.vendors?.erp_vendor_id) {
						return r.vendors.erp_vendor_id.toString().includes(filterCriteria.filterVendorId);
					}
					// Fallback: match against raw vendor_id from receiving_records
					return r.vendor_id.toString().includes(filterCriteria.filterVendorId);
				});
			}

			if (filterCriteria.filterVatNumber) {
				filtered = filtered.filter(r => {
					const vatNumber = (r.vendors?.vat_number || '').toLowerCase();
					return vatNumber.includes(filterCriteria.filterVatNumber.toLowerCase());
				});
			}

			if (filterCriteria.filterVendorName) {
				filtered = filtered.filter(r => {
					const vendorName = (r.vendors?.vendor_name || '').toLowerCase();
					return vendorName.includes(filterCriteria.filterVendorName.toLowerCase());
				});
			}

			if (filterCriteria.filterFromDays !== null || filterCriteria.filterToDays !== null) {
				filtered = filtered.filter(r => {
					const billDate = new Date(r.bill_date);
					const today = new Date();
					const daysAgo = Math.floor((today - billDate) / (1000 * 60 * 60 * 24));
					const fromDays = filterCriteria.filterFromDays !== null ? filterCriteria.filterFromDays : -Infinity;
					const toDays = filterCriteria.filterToDays !== null ? filterCriteria.filterToDays : Infinity;
					return daysAgo >= fromDays && daysAgo <= toDays;
				});
			}

			if (filterCriteria.filterOverdueDays !== null) {
				filtered = filtered.filter(r => {
					const dueDate = new Date(r.due_date);
					const today = new Date();
					const daysSinceDue = Math.floor((today - dueDate) / (1000 * 60 * 60 * 24));
					return daysSinceDue >= filterCriteria.filterOverdueDays;
				});
			}

			if (filterCriteria.showArchived) {
				filtered = [...filtered, ...archivedRecords];
			}

			// Paginate filtered results
			const startIdx = (pageNum - 1) * pageSize;
			const paginatedFiltered = filtered.slice(startIdx, startIdx + pageSize);
			
			totalRecords = filtered.length;
			totalPages = Math.ceil(filtered.length / pageSize);
			
			receivingRecords = paginatedFiltered;
			filteredRecords = filtered;
			
			console.log(`✅ Loaded ${paginatedFiltered.length} filtered records for page ${pageNum} (total: ${filtered.length})`);
			updatePaginatedRecords();
		} catch (error) {
			console.error(`Error loading filtered page:`, error);
			alert('Error loading filtered records. Try again.');
		}
	}

	// Update paginated records based on current page
	function updatePaginatedRecords() {
		// Use filteredRecords if filters are active, otherwise use receivingRecords
		const recordsToDisplay = hasActiveFilters ? filteredRecords : receivingRecords;
		paginatedRecords = [...recordsToDisplay]; // Use spread operator to ensure reactivity
		console.log(`📄 Page ${currentPage}/${totalPages}: showing ${paginatedRecords.length} records (hasActiveFilters: ${hasActiveFilters})`);
	}

	// Pagination functions - load data on demand
	async function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
			loading = true;
			await loadPageData(currentPage);
			loading = false;
		}
	}

	async function previousPage() {
		if (currentPage > 1) {
			currentPage--;
			loading = true;
			await loadPageData(currentPage);
			loading = false;
		}
	}

	async function goToPage(page) {
		if (page >= 1 && page <= totalPages) {
			currentPage = page;
			loading = true;
			await loadPageData(currentPage);
			loading = false;
		}
	}

	// Filter values change - do NOT apply filters automatically
	// Filters only apply when user explicitly clicks "Load Records" button

	function viewCertificate(certificateUrl) {
		if (certificateUrl) {
			window.open(certificateUrl, '_blank');
		}
	}

	function viewOriginalBill(billUrl) {
		if (billUrl) {
			window.open(billUrl, '_blank');
		}
	}

	// Helper function to check if file is PDF
	function isPdfFile(url) {
		if (!url) return false;
		return url.toLowerCase().includes('.pdf');
	}

	// Helper function to get file extension
	function getFileExtension(url) {
		if (!url) return '';
		return url.split('.').pop().toLowerCase();
	}

	async function uploadOriginalBill(recordId) {
		uploadingBillId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				uploadingBillId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_original_bill_${Date.now()}.${fileExt}`;

				// Upload file to original-bills storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('original-bills')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading file:', uploadError);
					alert('Error uploading file. Please try again.');
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('original-bills')
					.getPublicUrl(fileName);

				// Update the record with the file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ original_bill_url: publicUrl })
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record:', updateError);
					alert('Error saving file reference. Please try again.');
					return;
				}

				// Reload records to show updated data
				await loadReceivingRecords();
				
			} catch (error) {
				console.error('Error in upload process:', error);
				alert('Error uploading file. Please try again.');
			} finally {
				uploadingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	async function updateOriginalBill(recordId) {
		updatingBillId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				updatingBillId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename with "updated" prefix
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_original_bill_updated_${Date.now()}.${fileExt}`;

				// Upload file to original-bills storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('original-bills')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading updated file:', uploadError);
					alert('Error uploading updated file. Please try again.');
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('original-bills')
					.getPublicUrl(fileName);

				// Update the record with the new file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ 
						original_bill_url: publicUrl,
						updated_at: new Date().toISOString()
					})
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record:', updateError);
					alert('Error saving updated file reference. Please try again.');
					return;
				}

				// Show success message
				alert('Original bill updated successfully!');

				// Reload records to show updated data
				await loadReceivingRecords();
				
			} catch (error) {
				console.error('Error in update process:', error);
				alert('Error updating file. Please try again.');
			} finally {
				updatingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	async function uploadPRExcel(recordId) {
		uploadingExcelId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.xlsx,.xls,.csv';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				uploadingExcelId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_pr_excel_${Date.now()}.${fileExt}`;

				// Upload file to pr-excel-files storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('pr-excel-files')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading PR Excel file:', uploadError);
					alert('Error uploading PR Excel file. Please try again.');
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('pr-excel-files')
					.getPublicUrl(fileName);

				// Update the record with the file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ pr_excel_file_url: publicUrl })
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record with PR Excel:', updateError);
					alert('Error saving PR Excel file reference. Please try again.');
					return;
				}

				// Reload records to show updated data
				await loadReceivingRecords();
				alert('PR Excel file uploaded successfully!');
				
			} catch (error) {
				console.error('Error in PR Excel upload process:', error);
				alert('Error uploading PR Excel file. Please try again.');
			} finally {
				uploadingExcelId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	// Handle PR Excel verification
	async function handlePRExcelVerification(recordId, isVerified) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			console.log('Updating PR Excel verification:', { recordId, isVerified, userId: $currentUser?.id });
			
			const verifiedDate = isVerified ? new Date().toISOString() : null;
			const updateData = {
				pr_excel_verified: isVerified,
				pr_excel_verified_by: isVerified ? $currentUser?.id : null,
				pr_excel_verified_date: verifiedDate
			};

			// Update ALL payment schedules for this receiving record
			// This is important for split payments where there might be multiple schedules
			const { data: scheduleData, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.update(updateData)
				.eq('receiving_record_id', recordId)
				.select();

			if (scheduleError) {
				console.error('Supabase error updating payment schedules:', scheduleError);
				throw scheduleError;
			}

			console.log('✅ Update successful for payment schedules:', scheduleData);

			// Verify we have a payment schedule for this record
			if (!scheduleData || scheduleData.length === 0) {
				console.warn(
					`No payment schedules found for receiving record ${recordId}`);
				alert(`Warning: No payment schedules found for this receiving record. Please ensure the record is properly scheduled before verification.`);
				return;
			}

			// Update local state to reflect changes immediately
			receivingRecords = receivingRecords.map(record => {
				if (record.id === recordId) {
					return {
						...record,
						pr_excel_verified: isVerified,
						pr_excel_verified_by: isVerified ? $currentUser?.id : null,
						pr_excel_verified_date: verifiedDate,
						schedule_status: record.schedule_status ? {
							...record.schedule_status,
							pr_excel_verified: isVerified,
							pr_excel_verified_by: isVerified ? $currentUser?.id : null,
							pr_excel_verified_date: verifiedDate
						} : null
					};
				}
				return record;
			});

			// Reapply filters to update the filtered view
			applyFilters();
			
		} catch (error) {
			console.error('Error updating PR Excel verification:', error);
			alert(`Error updating verification status: ${error.message}`);
		}
	}

	// Helper function to format dates as dd/mm/yyyy
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		try {
			const date = new Date(dateString);
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'Invalid Date';
		}
	}

	// Helper function to calculate days remaining to due date
	function getDaysRemaining(dueDateString) {
		if (!dueDateString) return 'N/A';
		try {
			const dueDate = new Date(dueDateString);
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			dueDate.setHours(0, 0, 0, 0);
			
			const diffTime = dueDate.getTime() - today.getTime();
			const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			
			if (diffDays < 0) {
				return `${diffDays} days`;
			} else if (diffDays === 0) {
				return '0 days';
			} else {
				return `${diffDays} days`;
			}
		} catch (error) {
			return 'Invalid Date';
		}
	}

	// Helper function to format date and time as dd/mm/yyyy HH:mm
	function formatDateTime(dateTimeString) {
		if (!dateTimeString) return 'N/A';
		try {
			const date = new Date(dateTimeString);
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			const hours = date.getHours().toString().padStart(2, '0');
			const minutes = date.getMinutes().toString().padStart(2, '0');
			return `${day}/${month}/${year} ${hours}:${minutes}`;
		} catch (error) {
			return 'Invalid Date';
		}
	}

	// Generate PR Excel filename with vendor name, bill date, and amount
	function getPRExcelFileName(record) {
		try {
			const vendorName = (record.vendors?.vendor_name || 'Unknown_Vendor')
				.replace(/[^a-zA-Z0-9\u0600-\u06FF\s]/g, '') // Remove special characters but keep Arabic
				.replace(/\s+/g, '_') // Replace spaces with underscores
				.substring(0, 50); // Limit length
			
			const billDate = record.bill_date 
				? formatDate(record.bill_date).replace(/\//g, '-') 
				: 'No_Date';
			
			const amount = record.final_bill_amount || record.bill_amount || 0;
			const amountFormatted = parseFloat(amount).toFixed(2);
			
			// Get file extension from URL
			const url = record.pr_excel_file_url;
			const urlParts = url.split('.');
			const extension = urlParts[urlParts.length - 1].split('?')[0] || 'xlsx';
			
			return `${vendorName}_${billDate}_${amountFormatted}_SAR.${extension}`;
		} catch (error) {
			console.error('Error generating PR Excel filename:', error);
			return 'PR_Excel.xlsx';
		}
	}

	// Download PR Excel with custom filename
	async function downloadPRExcel(record) {
		try {
			const fileName = getPRExcelFileName(record);
			
			// Fetch the file
			const response = await fetch(record.pr_excel_file_url);
			if (!response.ok) throw new Error('Failed to fetch file');
			
			// Get the blob
			const blob = await response.blob();
			
			// Create download link
			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = fileName;
			document.body.appendChild(link);
			link.click();
			
			// Cleanup
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Error downloading PR Excel:', error);
			// Fallback to opening in new tab
			window.open(record.pr_excel_file_url, '_blank');
		}
	}

	// ERP Invoice Reference Functions
	function openErpPopup(record) {
		selectedRecord = record;
		erpReferenceValue = record.erp_purchase_invoice_reference || '';
		showErpPopup = true;
	}

	function closeErpPopup() {
		showErpPopup = false;
		selectedRecord = null;
		erpReferenceValue = '';
		updatingErp = false;
	}

	async function updateErpReference() {
		if (!selectedRecord || !erpReferenceValue?.trim()) return;

		try {
			updatingErp = true;
			
			const response = await fetch('/api/receiving-records/update-erp', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					receivingRecordId: selectedRecord.id,
					erpReference: erpReferenceValue.trim()
				})
			});

			if (!response.ok) {
				const error = await response.text();
				throw new Error(error);
			}

			// Update the record in our local data
			const updatedRecords = filteredRecords.map(record => 
				record.id === selectedRecord.id 
					? { ...record, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: record
			);
			filteredRecords = updatedRecords;

			// Also update the main records array
			receivingRecords = receivingRecords.map(record => 
				record.id === selectedRecord.id 
					? { ...record, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: record
			);

			closeErpPopup();
			alert('ERP invoice reference updated successfully');
		} catch (error) {
			console.error('Error updating ERP reference:', error);
			alert(`Failed to update ERP reference: ${error.message}`);
		} finally {
			updatingErp = false;
		}
	}

	async function generateCertificate(record) {
		selectedRecordForCertificate = record;
		showCertificateModal = true;
	}

	function closeCertificateModal() {
		showCertificateModal = false;
		selectedRecordForCertificate = null;
	}

	function handleCertificateGenerated() {
		// Reload records to show the updated certificate
		loadReceivingRecords();
		closeCertificateModal();
	}

	async function deleteReceivingRecord(recordId) {
		if (!isMasterAdmin) {
			alert('Only Master Admins can delete receiving records');
			return;
		}

		const record = receivingRecords.find(r => r.id === recordId);
		const confirmMessage = `Are you sure you want to delete this receiving record?\n\nBill: ${record?.bill_number || 'Unknown'}\nVendor: ${record?.vendors?.vendor_name || 'Unknown'}\n\nThis action cannot be undone.`;
		
		if (!confirm(confirmMessage)) {
			return;
		}

		try {
			deletingRecordId = recordId;
			const { supabase } = await import('$lib/utils/supabase');

			const { error } = await supabase
				.from('receiving_records')
				.delete()
				.eq('id', recordId);

			if (error) throw error;

			// Remove from local arrays
			receivingRecords = receivingRecords.filter(r => r.id !== recordId);
			filteredRecords = filteredRecords.filter(r => r.id !== recordId);

			alert('Receiving record deleted successfully');
		} catch (error) {
			console.error('Error deleting receiving record:', error);
			alert(`Failed to delete receiving record: ${error.message}`);
		} finally {
			deletingRecordId = null;
		}
	}

	// Track which filter is active
	let activeFilter = 'none'; // 'none', 'search', 'branch', 'vendor-id', 'vat-number', 'vendor-name', 'days-range', 'overdue-days'
	let hasActiveFilters = false; // Track if any filters are actually applied

	// Load button handler - applies filters and loads paginated data from database
	async function applyFilterLoad() {
		console.log(`🔍 Applying filter: ${activeFilter}`);
		console.log(`📊 Current filter values:`, {
			selectedBranch,
			searchTerm,
			filterVendorId,
			filterVatNumber,
			filterVendorName,
			filterFromDays,
			filterToDays,
			filterOverdueDays
		});
		
		hasActiveFilters = true;
		currentPage = 1;
		loading = true;
		try {
			// Build filter criteria - keep branch ID as is (don't convert to string/trim)
			const filterCriteria = {
				searchTerm: String(searchTerm).trim(),
				selectedBranch: selectedBranch, // Keep as UUID, don't trim
				filterVendorId: String(filterVendorId).trim(),
				filterVatNumber: String(filterVatNumber).trim(),
				filterVendorName: String(filterVendorName).trim(),
				filterFromDays: filterFromDays !== '' && filterFromDays !== null ? parseInt(filterFromDays) : null,
				filterToDays: filterToDays !== '' && filterToDays !== null ? parseInt(filterToDays) : null,
				filterOverdueDays: filterOverdueDays !== '' && filterOverdueDays !== null ? parseInt(filterOverdueDays) : null
			};

			console.log(`🔍 Filter criteria built:`, filterCriteria);

			// Load first page of filtered results (count handled inside function)
			await loadFilteredPageData(1, filterCriteria);
		} catch (error) {
			console.error('❌ Error applying filters:', error);
			alert('Failed to apply filters');
		} finally {
			loading = false;
		}
	}

	// Reset filters when "No Filter" is selected
	$: if (activeFilter === 'none') {
		hasActiveFilters = false;
		searchTerm = '';
		filterVendorId = '';
		filterVatNumber = '';
		filterVendorName = '';
		filterFromDays = '';
		filterToDays = '';
		filterOverdueDays = '';
		selectedBranch = '';
		updatePaginatedRecords();
	}

	// Lazy loading - load more records as user scrolls
	let scrollContainer = null;
	let isLoadingMore = false;

	function handleScroll() {
		if (!scrollContainer || isLoadingMore || loading) return;

		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		const scrollPercentage = (scrollTop + clientHeight) / scrollHeight;

		// Load more when user scrolls to 80% of the table
		if (scrollPercentage > 0.8 && currentPage < totalPages) {
			isLoadingMore = true;
			currentPage++;
			console.log(`📄 Auto-loading page ${currentPage}/${totalPages} (scroll detected at ${(scrollPercentage * 100).toFixed(0)}%)`);
			
			loadPageData(currentPage).then(() => {
				isLoadingMore = false;
			}).catch(err => {
				console.error('Error loading more records on scroll:', err);
				isLoadingMore = false;
			});
		}
	}
</script>

<!-- Receiving Records Window Content -->
<div class="receiving-records-window" bind:this={scrollContainer} on:scroll={handleScroll}>
	<!-- Search and Filter Section - REORGANIZED -->
	<div class="filters-section">
		<!-- Filter Options Container -->
		<div class="filter-options-container">
			<!-- Filter Radio Buttons -->
			<div class="filter-radio-group">
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="none"
					/>
					<span>No Filter</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="search"
					/>
					<span>Search</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="branch"
					/>
					<span>By Branch</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="vendor-id"
					/>
					<span>By Vendor ID</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="vat-number"
					/>
					<span>By VAT Number</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="vendor-name"
					/>
					<span>By Vendor Name</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="days-range"
					/>
					<span>By Days Range</span>
				</label>
				
				<label class="filter-radio">
					<input 
						type="radio" 
						bind:group={activeFilter} 
						value="overdue-days"
					/>
					<span>By Overdue Days</span>
				</label>
			</div>

			<!-- Conditional Filter Input Sections -->
			<div class="filter-input-section">
				<!-- Search Filter -->
				{#if activeFilter === 'search'}
					<div class="active-filter-content">
						<input 
							type="text" 
							placeholder="🔍 Search by bill number, vendor name, VAT number, or reviewer..." 
							bind:value={searchTerm}
							class="filter-input"
						/>
					</div>
				{/if}

				<!-- Branch Filter -->
				{#if activeFilter === 'branch'}
					<div class="active-filter-content">
						<select bind:value={selectedBranch} class="filter-select">
							<option value="">Choose a branch...</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en}</option>
							{/each}
						</select>
					</div>
				{/if}

				<!-- Vendor ID Filter -->
				{#if activeFilter === 'vendor-id'}
					<div class="active-filter-content">
						<input 
							type="text" 
							placeholder="Enter vendor ID..." 
							bind:value={filterVendorId}
							class="filter-input"
						/>
					</div>
				{/if}

				<!-- VAT Number Filter -->
				{#if activeFilter === 'vat-number'}
					<div class="active-filter-content">
						<input 
							type="text" 
							placeholder="Enter VAT number..." 
							bind:value={filterVatNumber}
							class="filter-input"
						/>
					</div>
				{/if}

				<!-- Vendor Name Filter -->
				{#if activeFilter === 'vendor-name'}
					<div class="active-filter-content">
						<input 
							type="text" 
							placeholder="Enter vendor name..." 
							bind:value={filterVendorName}
							class="filter-input"
						/>
					</div>
				{/if}

				<!-- Days Range Filter -->
				{#if activeFilter === 'days-range'}
					<div class="active-filter-content">
						<input 
							type="number" 
							placeholder="From Days (e.g., -10 for overdue)" 
							bind:value={filterFromDays}
							class="filter-input"
						/>
						<input 
							type="number" 
							placeholder="To Days (e.g., 30)" 
							bind:value={filterToDays}
							class="filter-input"
						/>
					</div>
				{/if}

				<!-- Overdue Days Filter -->
				{#if activeFilter === 'overdue-days'}
					<div class="active-filter-content">
						<input 
							type="number" 
							placeholder="Overdue by at least X days" 
							bind:value={filterOverdueDays}
							class="filter-input"
						/>
					</div>
				{/if}
			</div>

			<!-- Load Button -->
			<button 
				class="load-filter-btn"
				on:click={applyFilterLoad}
				disabled={loading}
				title="Apply selected filter and load records"
			>
				{#if loading}
					<span>⏳ Loading...</span>
				{:else}
					<span>📂 Load Records</span>
				{/if}
			</button>
		</div>
	</div>

	<!-- Records Table -->
	<div class="records-container">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>⏳ Loading receiving records...</p>
			</div>
		{:else if paginatedRecords.length === 0}
			<div class="no-records">
				<p>📭 No receiving records found.</p>
			</div>
		{:else}
			<div class="records-table">
				<div class="table-header">
					<div class="header-cell serial-number-cell">#</div>
					<div class="header-cell">Certificate</div>
					<div class="header-cell">Original Bill</div>
					<div class="header-cell">PR Excel</div>
					<div class="header-cell">Bill Info</div>
					<div class="header-cell">Vendor Details</div>
					<div class="header-cell">Branch</div>
					<div class="header-cell">Received By</div>
					<div class="header-cell">Payment Info</div>
					<div class="header-cell">Schedule Status</div>
					<div class="header-cell">Days to Due</div>
					<div class="header-cell">Amounts</div>
					<div class="header-cell">ERP Invoice Ref</div>
					<div class="header-cell">Date</div>
					{#if isMasterAdmin}
						<div class="header-cell">Actions</div>
					{/if}
				</div>
				
				{#each paginatedRecords as record, index}
					<div class="table-row">
					<div class="cell serial-number-cell">
						<strong>{index + 1 + (currentPage - 1) * pageSize}</strong>
					</div>
					<div class="cell certificate-cell">
							{#if record.certificate_url}
								<div class="certificate-thumbnail" on:click={() => viewCertificate(record.certificate_url)}>
									<img src={record.certificate_url} alt="Certificate" loading="lazy" />
									<div class="thumbnail-overlay">
										<span>🔍</span>
									</div>
								</div>
							{:else}
								<div class="generate-certificate-container">
									{#if generatingCertificateId === record.id}
										<div class="generating-indicator">
											<div class="spinner-small"></div>
											<small>Generating...</small>
										</div>
									{:else}
										<button class="generate-certificate-btn" on:click={() => generateCertificate(record)}>
											<span>�</span>
											<small>Generate Certificate</small>
										</button>
									{/if}
								</div>
							{/if}
											</div>
					<div class="cell certificate-cell">
							{#if record.original_bill_url}
								<div class="original-bill-with-update">
									<div class="certificate-thumbnail" on:click={() => viewOriginalBill(record.original_bill_url)}>
										{#if isPdfFile(record.original_bill_url)}
											<div class="pdf-thumbnail">
												<div class="pdf-icon">📄</div>
												<div class="pdf-label">PDF</div>
											</div>
										{:else}
											<img src={record.original_bill_url} alt="Original Bill" loading="lazy" />
										{/if}
										<div class="thumbnail-overlay">
											<span>🔍</span>
										</div>
									</div>
									<div class="update-bill-section">
										{#if updatingBillId === record.id}
											<div class="updating-indicator">
												<div class="spinner-small"></div>
												<small>Updating...</small>
											</div>
										{:else}
											<button class="update-bill-btn" on:click={() => updateOriginalBill(record.id)} title="Upload updated version">
												<span>🔄</span>
												<small>Update</small>
											</button>
										{/if}
									</div>
								</div>
							{:else}
								<div class="upload-bill-container">
									{#if uploadingBillId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>Uploading...</small>
										</div>
									{:else}
										<button class="upload-bill-btn" on:click={() => uploadOriginalBill(record.id)}>
											<span>📎</span>
											<small>Original Bill Not Uploaded</small>
										</button>
									{/if}
								</div>
							{/if}
											</div>
					<div class="cell certificate-cell">
							{#if record.pr_excel_file_url}
								<div class="excel-file-container">
									<button 
										class="excel-file-link"
										on:click={() => downloadPRExcel(record)}
									>
										<div class="excel-icon">📊</div>
										<small>PR Excel</small>
									</button>
									<div class="pr-excel-verification">
										<label class="verification-checkbox">
											<input
												type="checkbox"
												checked={record.pr_excel_verified || false}
												on:change={(e) => handlePRExcelVerification(record.id, e.target.checked)}
											/>
											<span class="checkbox-label">
												{record.pr_excel_verified ? '✓ Verified' : 'Verify'}
											</span>
										</label>
										{#if record.pr_excel_verified && record.pr_excel_verified_date}
											<small class="verification-date">
												{formatDateTime(record.pr_excel_verified_date)}
											</small>
										{/if}
									</div>
								</div>
							{:else}
								<div class="upload-excel-container">
									{#if uploadingExcelId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>Uploading...</small>
										</div>
									{:else}
										<button class="upload-excel-btn" on:click={() => uploadPRExcel(record.id)}>
											<span>📊</span>
											<small>PR Excel Not Uploaded</small>
										</button>
									{/if}
								</div>
							{/if}
						</div>
						
						<div class="cell">
							<div class="bill-info">
								<strong>#{record.bill_number || 'N/A'}</strong>
								<small>{formatDate(record.bill_date)}</small>
							</div>
						</div>
						
						<div class="cell">
							<div class="vendor-info">
								<strong>{record.vendors?.vendor_name || 'N/A'}</strong>
								<small>ID: {record.vendors?.erp_vendor_id || 'N/A'}</small>
								<small>VAT: {record.vendors?.vat_number || 'N/A'}</small>
							</div>
						</div>
						
						<div class="cell">
							<span>{record.branches?.name_en || 'N/A'}</span>
						</div>
						
						<div class="cell">
							<div class="reviewed-by-info">
								<strong>{record.users?.hr_employees?.name || record.users?.username || 'N/A'}</strong>
								<small>@{record.users?.username || 'unknown'}</small>
							</div>
						</div>
						
						<div class="cell">
							<div class="payment-info">
								<strong>{record.payment_method || 'N/A'}</strong>
								<small>Due: {formatDate(record.due_date)}</small>
								{#if record.credit_period}
									<small>{record.credit_period} days</small>
								{/if}
							</div>
						</div>
						
						<div class="cell">
							<div class="schedule-status">
								{#if record.is_scheduled}
									{#if record.schedule_status?.is_paid}
										<span class="status-badge paid">✓ Paid</span>
									{:else}
										<span class="status-badge scheduled">
											📅 {record.has_multiple_schedules ? 'Split Scheduled' : 'Scheduled'}
										</span>
									{/if}
								{:else}
									<span class="status-badge not-scheduled">⏳ Not Scheduled</span>
								{/if}
							</div>
						</div>
						
						<div class="cell">
							<div class="days-remaining" class:overdue={record.due_date && getDaysRemaining(record.due_date).includes('-')}>
								<span>{getDaysRemaining(record.due_date)}</span>
							</div>
						</div>
						
						<div class="cell">
							<div class="amounts">
								<div>Bill: {parseFloat(record.bill_amount || 0).toFixed(2)}</div>
								<div>Final: {parseFloat(record.final_bill_amount || 0).toFixed(2)}</div>
							</div>
						</div>
						
						<div class="cell">
							<div class="erp-reference">
									{#if record.erp_purchase_invoice_reference}
										<span class="erp-ref-value">{record.erp_purchase_invoice_reference}</span>
									{:else}
										<button 
											class="erp-ref-empty clickable" 
											on:click={() => openErpPopup(record)}
											title="Click to enter ERP invoice reference"
										>
											Not Entered
										</button>
									{/if}
							</div>
						</div>
						
						<div class="cell">
							<small>{formatDate(record.created_at)}</small>
						</div>
						
						{#if isMasterAdmin}
							<div class="cell actions-cell">
								{#if deletingRecordId === record.id}
									<div class="deleting-indicator">
										<div class="spinner-small"></div>
										<small>Deleting...</small>
									</div>
								{:else}
									<button 
										class="delete-btn" 
										on:click={() => deleteReceivingRecord(record.id)}
										title="Delete this receiving record (Master Admin only)"
									>
										<span>🗑️</span>
									</button>
								{/if}
							</div>
						{/if}
					</div>
				{/each}
<!-- Load More Button -->
			{#if receivingRecords.length < totalRecords && currentPage < totalPages}
				<div class="load-more-container">
					<button 
						class="load-more-btn" 
						on:click={() => {
							isLoadingMore = true;
							currentPage++;
							console.log(`📄 Loading page ${currentPage}/${totalPages}...`);
							loadPageData(currentPage).then(() => {
								isLoadingMore = false;
							}).catch(err => {
								console.error('Error loading more records:', err);
								isLoadingMore = false;
							});
						}}
						disabled={isLoadingMore || loading}
					>
						{isLoadingMore ? '⏳ Loading...' : '📥 Load More Records'}
					</button>
				</div>
			{/if}
		</div>
		{/if}
	</div>
</div>

<!-- ERP Invoice Reference Popup -->
{#if showErpPopup}
	<div class="erp-popup-overlay" on:click={closeErpPopup}>
		<div class="erp-popup-modal" on:click|stopPropagation>
			<div class="erp-popup-header">
				<h3>Enter ERP Invoice Reference</h3>
				<button class="erp-popup-close" on:click={closeErpPopup}>&times;</button>
			</div>
			<div class="erp-popup-content">
				<p>Record: {selectedRecord?.bill_number || 'Unknown Bill'}</p>
				<p>Vendor: {selectedRecord?.vendor_name || 'Unknown Vendor'}</p>
				<div class="erp-input-group">
					<label for="erpRef">ERP Invoice Reference:</label>
					<input 
						id="erpRef"
						type="text" 
						bind:value={erpReferenceValue}
						placeholder="Enter ERP invoice reference number"
						class="erp-input"
						disabled={updatingErp}
					/>
				</div>
			</div>
			<div class="erp-popup-actions">
				<button 
					class="erp-btn-cancel" 
					on:click={closeErpPopup}
					disabled={updatingErp}
				>
					Cancel
				</button>
				<button 
					class="erp-btn-save" 
					on:click={updateErpReference}
					disabled={updatingErp || !erpReferenceValue?.trim()}
				>
					{#if updatingErp}
						<div class="spinner-small"></div>
						Updating...
					{:else}
						Save Reference
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Certificate Generation Modal -->
{#if showCertificateModal && selectedRecordForCertificate}
	<ClearanceCertificateManager 
		receivingRecord={selectedRecordForCertificate}
		show={true}
		on:certificateGenerated={handleCertificateGenerated}
		on:close={closeCertificateModal}
	/>
{/if}

<style>
	.receiving-records-window {
		padding: 24px;
		height: 100vh;
		background: white;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.window-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e2e8f0;
	}

	.window-title h2 {
		margin: 0 0 4px 0;
		color: #1e293b;
		font-size: 24px;
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.window-title p {
		margin: 0;
		color: #64748b;
		font-size: 14px;
		font-weight: 400;
	}

	.window-actions {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.refresh-btn span {
		font-size: 16px;
		animation: none;
	}

	.refresh-btn:hover:not(:disabled) span {
		animation: rotate 0.6s ease-in-out;
	}

	@keyframes rotate {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.filters-section {
		margin-bottom: 24px;
		padding: 20px;
		background: #f8fafc;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
	}

	.search-bar {
		margin-bottom: 20px;
	}

	.search-input {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 16px;
		transition: border-color 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-options-container {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.filter-radio-group {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		gap: 12px;
		padding: 16px;
		background: white;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.filter-radio {
		display: flex;
		align-items: center;
		gap: 8px;
		cursor: pointer;
		padding: 8px;
		border-radius: 6px;
		transition: background-color 0.2s ease;
		user-select: none;
	}

	.filter-radio:hover {
		background-color: #f0f9ff;
	}

	.filter-radio input[type="radio"] {
		margin: 0;
		cursor: pointer;
		width: 16px;
		height: 16px;
	}

	.filter-radio span {
		font-size: 14px;
		font-weight: 500;
		color: #475569;
	}

	.filter-input-section {
		display: flex;
		gap: 12px;
		align-items: center;
		flex-wrap: wrap;
		min-height: 44px;
	}

	.active-filter-content {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
		flex: 1;
		align-items: center;
	}

	.filter-input {
		padding: 10px 12px;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s ease;
		width: 100%;
	}

	.filter-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.filter-select {
		padding: 10px 12px;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #1e293b;
		cursor: pointer;
		min-width: 250px;
		transition: border-color 0.2s ease;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.load-filter-btn {
		padding: 10px 24px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
		white-space: nowrap;
	}

	.load-filter-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
	}

	.load-filter-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.archived-toggle {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		cursor: pointer;
		font-weight: 500;
		color: #475569;
		padding: 0;
		margin: 0;
	}

	.archived-toggle input[type="checkbox"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
		transform: scale(1.2);
	}

	.toggle-label {
		font-size: 0.95rem;
		user-select: none;
	}

	.records-container {
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
		flex: 1;
		max-height: 70vh;
		display: flex;
		flex-direction: column;
	}

	.loading {
		text-align: center;
		padding: 60px 20px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-left: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.no-records {
		text-align: center;
		padding: 60px 20px;
		color: #6b7280;
	}

	.records-table {
		display: flex;
		flex-direction: column;
		flex: 1;
		overflow: auto;
	}

	.table-header {
		display: grid;
		grid-template-columns: 40px 120px 120px 80px 1fr 1fr 1fr 120px 1fr 120px 120px 1fr 140px 100px 80px;
		gap: 16px;
		padding: 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
		position: sticky;
		top: 0;
		z-index: 10;
		flex-shrink: 0;
	}

	.table-row {
		display: grid;
		grid-template-columns: 40px 120px 120px 80px 1fr 1fr 1fr 120px 1fr 120px 120px 1fr 140px 100px 80px;
		gap: 16px;
		padding: 16px;
		border-bottom: 1px solid #f1f5f9;
		transition: background-color 0.2s ease;
	}

	.table-row:hover {
		background: #f8fafc;
	}

	.cell {
		display: flex;
		align-items: center;
		font-size: 14px;
		color: #374151;
	}

	.serial-number-cell {
		justify-content: center;
		font-weight: 600;
		color: #64748b;
		background: #f0f4f8;
		border-radius: 4px;
		padding: 8px;
	}

	.certificate-cell {
		justify-content: center;
	}

	.certificate-thumbnail {
		width: 80px;
		height: 60px;
		border-radius: 8px;
		overflow: hidden;
		cursor: pointer;
		position: relative;
		border: 2px solid #e2e8f0;
		transition: all 0.2s ease;
	}

	.certificate-thumbnail:hover {
		border-color: #3b82f6;
		transform: scale(1.05);
	}

	.certificate-thumbnail img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumbnail-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s ease;
		color: white;
		font-size: 20px;
	}

	.certificate-thumbnail:hover .thumbnail-overlay {
		opacity: 1;
	}

	.generate-certificate-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
	}

	.generate-certificate-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0f9ff;
		border: 2px dashed #3b82f6;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #1d4ed8;
		font-size: 10px;
		padding: 4px;
	}

	.generate-certificate-btn:hover {
		background: #dbeafe;
		border-color: #2563eb;
		color: #1e40af;
		transform: scale(1.02);
	}

	.generate-certificate-btn span {
		font-size: 16px;
		margin-bottom: 2px;
	}

	.generating-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #fef3c7;
		border: 2px solid #f59e0b;
		border-radius: 8px;
		color: #92400e;
		font-size: 10px;
	}

	.no-certificate {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
		background: #f1f5f9;
		border-radius: 8px;
		color: #6b7280;
		font-size: 12px;
	}

	.no-certificate span {
		font-size: 20px;
		margin-bottom: 4px;
	}

	.bill-info, .vendor-info, .payment-info, .amounts, .reviewed-by-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.bill-info strong, .vendor-info strong, .payment-info strong, .reviewed-by-info strong {
		color: #1f2937;
		font-weight: 600;
	}

	.bill-info small, .vendor-info small, .payment-info small, .reviewed-by-info small {
		color: #6b7280;
		font-size: 12px;
	}

	.schedule-status {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.status-badge {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 6px 12px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.status-badge.scheduled {
		background: #eff6ff;
		color: #2563eb;
		border: 1px solid #bfdbfe;
	}

	.status-badge.paid {
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
	}

	.status-badge.not-scheduled {
		background: #fef3c7;
		color: #d97706;
		border: 1px solid #fde68a;
	}

	.amounts div {
		font-size: 12px;
		color: #374151;
	}

	.erp-reference {
		display: flex;
		align-items: center;
		justify-content: center;
		text-align: center;
		font-size: 12px;
		padding: 4px 8px;
		border-radius: 6px;
		font-weight: 500;
	}

	.erp-ref-value {
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
		padding: 6px 10px;
		border-radius: 6px;
		font-family: 'Courier New', monospace;
		font-weight: 600;
		font-size: 11px;
		word-break: break-all;
	}

	.erp-ref-empty {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
		padding: 6px 10px;
		border-radius: 6px;
		font-style: italic;
		font-size: 11px;
	}

	.erp-ref-empty.clickable {
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.erp-ref-empty.clickable:hover {
		background: #fee2e2;
		border-color: #fca5a5;
		transform: translateY(-1px);
	}

	/* Actions Cell and Delete Button Styles */
	.actions-cell {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.delete-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		padding: 0;
		background: #fee2e2;
		border: 1px solid #fecaca;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #dc2626;
		font-size: 16px;
	}

	.delete-btn:hover {
		background: #fecaca;
		border-color: #fca5a5;
		transform: scale(1.1);
		box-shadow: 0 2px 4px rgba(220, 38, 38, 0.2);
	}

	.delete-btn:active {
		transform: scale(0.95);
	}

	.deleting-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		color: #6b7280;
		font-size: 9px;
		min-width: 50px;
	}

	/* ERP Popup Styles */
	.erp-popup-overlay {
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

	.erp-popup-modal {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow: hidden;
	}

	.erp-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.erp-popup-header h3 {
		margin: 0;
		color: #111827;
		font-size: 18px;
		font-weight: 600;
	}

	.erp-popup-close {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s ease;
	}

	.erp-popup-close:hover {
		background: #e5e7eb;
		color: #374151;
	}

	.erp-popup-content {
		padding: 24px;
	}

	.erp-popup-content p {
		margin: 0 0 16px 0;
		color: #6b7280;
		font-size: 14px;
	}

	.erp-input-group {
		margin-top: 20px;
	}

	.erp-input-group label {
		display: block;
		margin-bottom: 8px;
		color: #374151;
		font-weight: 500;
		font-size: 14px;
	}

	.erp-input {
		width: 100%;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		transition: all 0.2s ease;
		box-sizing: border-box;
	}

	.erp-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.erp-input:disabled {
		background: #f9fafb;
		color: #6b7280;
		cursor: not-allowed;
	}

	.erp-popup-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 20px 24px;
		border-top: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.erp-btn-cancel,
	.erp-btn-save {
		padding: 10px 20px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		border: 1px solid;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.erp-btn-cancel {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.erp-btn-cancel:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.erp-btn-save {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.erp-btn-save:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
	}

	.erp-btn-save:disabled,
	.erp-btn-cancel:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.days-remaining {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 8px 12px;
		border-radius: 8px;
		font-weight: 600;
		font-size: 12px;
		text-align: center;
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
	}

	.days-remaining.overdue {
		background: #fef2f2;
		color: #dc2626;
		border-color: #fecaca;
	}

	.upload-bill-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
	}

	.upload-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f8fafc;
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #6b7280;
		font-size: 12px;
		padding: 4px;
	}

	.upload-bill-btn:hover {
		background: #f0f9ff;
		border-color: #3b82f6;
		color: #3b82f6;
		transform: scale(1.02);
	}

	.upload-bill-btn span {
		font-size: 16px;
		margin-bottom: 2px;
	}

	/* Original Bill with Update Button Styles */
	.original-bill-with-update {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 8px;
		width: 100%;
		justify-content: space-between;
	}

	.update-bill-section {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.update-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #fef3c7;
		border: 1px solid #f59e0b;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #92400e;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	.update-bill-btn:hover {
		background: #fbbf24;
		color: #78350f;
		transform: scale(1.05);
		border-color: #d97706;
	}

	.update-bill-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.updating-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		color: #6b7280;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	/* PR Excel Upload Styles */
	.upload-excel-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		min-height: 50px;
	}

	.upload-excel-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0f9ff;
		border: 2px dashed #0ea5e9;
		border-radius: 6px;
		color: #0369a1;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px;
		min-height: 50px;
	}

	.upload-excel-btn:hover {
		background: #e0f2fe;
		border-color: #0284c7;
		transform: scale(1.02);
	}

	.upload-excel-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.excel-file-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		min-height: 50px;
		gap: 0.5rem;
	}

	.pr-excel-verification {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
		width: 100%;
		margin-top: 0.5rem;
	}

	.verification-checkbox {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		padding: 0.25rem 0.5rem;
		background: #f8fafc;
		border: 1px solid #cbd5e1;
		border-radius: 4px;
		transition: all 0.2s ease;
	}

	.verification-checkbox:hover {
		background: #f1f5f9;
		border-color: #94a3b8;
	}

	.verification-checkbox input[type="checkbox"] {
		cursor: pointer;
		width: 16px;
		height: 16px;
	}

	.verification-checkbox input[type="checkbox"]:checked + .checkbox-label {
		color: #16a34a;
		font-weight: 600;
	}

	.checkbox-label {
		font-size: 0.75rem;
		color: #475569;
		user-select: none;
	}

	.verification-date {
		font-size: 0.625rem;
		color: #64748b;
		font-style: italic;
	}

	.excel-file-link {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0fdf4;
		border: 2px solid #22c55e;
		border-radius: 6px;
		color: #15803d;
		text-decoration: none;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px;
		min-height: 50px;
		cursor: pointer;
	}

	.excel-file-link:hover {
		background: #dcfce7;
		border-color: #16a34a;
		transform: scale(1.02);
	}

	.excel-icon {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.uploading-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #fef3c7;
		border: 2px solid #f59e0b;
		border-radius: 8px;
		color: #92400e;
		font-size: 10px;
	}

	.spinner-small {
		width: 16px;
		height: 16px;
		border: 2px solid #fde68a;
		border-left: 2px solid #f59e0b;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 2px;
	}

	.pdf-thumbnail {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		border-radius: 6px;
		position: relative;
	}

	.pdf-icon {
		font-size: 24px;
		margin-bottom: 2px;
	}

	.pdf-label {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.5px;
	}

	/* Pagination Controls Styles */
	.pagination-controls {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
		padding: 24px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
		margin-top: 12px;
		border-radius: 0 0 8px 8px;
		flex-wrap: wrap;
	}

	.pagination-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		border: 1px solid #3b82f6;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		transition: all 0.2s ease;
		white-space: nowrap;
	}

	.pagination-btn:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px rgba(59, 130, 246, 0.2);
	}

	.pagination-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.pagination-btn:disabled {
		background: #d1d5db;
		border-color: #d1d5db;
		color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.load-more-container {
		display: flex;
		justify-content: center;
		padding: 24px 16px;
		background: #f8fafc;
		border-top: 1px solid #e2e8f0;
		margin-top: 12px;
	}

	.load-more-btn {
		padding: 10px 20px;
		background: #059669;
		color: white;
		border: 1px solid #059669;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		white-space: nowrap;
		transition: all 0.2s ease;
		display: flex;
		gap: 6px;
		align-items: center;
	}

	.load-more-btn:hover:not(:disabled) {
		background: #047857;
		border-color: #047857;
		transform: translateY(-2px);
		box-shadow: 0 4px 6px rgba(5, 150, 105, 0.2);
	}

	.load-more-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.load-more-btn:disabled {
		background: #d1d5db;
		border-color: #d1d5db;
		color: #9ca3af;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.pagination-info {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		color: #6b7280;
		font-size: 14px;
		font-weight: 500;
	}

	.page-number {
		color: #374151;
		font-weight: 600;
	}

	.record-count {
		color: #9ca3af;
		font-size: 12px;
	}

	/* Table Footer Styles */
	/* Responsive adjustments */
	@media (max-width: 768px) {
		.receiving-records-window {
			padding: 16px;
		}

		.window-header {
			flex-direction: column;
			align-items: flex-start;
			gap: 12px;
		}

		.window-title h2 {
			font-size: 20px;
		}

		.window-actions {
			align-self: flex-end;
		}

		.refresh-btn {
			padding: 8px 12px;
			font-size: 12px;
		}

		.refresh-btn span {
			font-size: 14px;
		}

		.table-header, .table-row {
			grid-template-columns: 80px 1fr 1fr 1fr 80px;
			gap: 8px;
			font-size: 12px;
		}

		.table-row .cell:nth-child(2),
		.table-row .cell:nth-child(3),
		.table-row .cell:nth-child(7),
		.table-row .cell:nth-child(8),
		.table-row .cell:nth-child(9),
		.table-row .cell:nth-child(10),
		.table-row .cell:nth-child(11) {
			display: none;
		}

		.certificate-thumbnail {
			width: 60px;
			height: 45px;
		}

		.upload-bill-container {
			width: 60px;
			height: 45px;
		}

		.generate-certificate-container {
			width: 60px;
			height: 45px;
		}

		.generate-certificate-btn {
			font-size: 8px;
		}

		.generate-certificate-btn span {
			font-size: 12px;
		}

		.upload-bill-btn {
			font-size: 10px;
		}

		.upload-bill-btn span {
			font-size: 12px;
		}

		.upload-excel-container {
			width: 50px;
			height: 40px;
		}

		.upload-excel-btn {
			font-size: 7px;
			min-height: 40px;
		}

		.upload-excel-btn span {
			font-size: 10px;
		}

		.excel-file-container {
			width: 50px;
			height: 40px;
		}

		.delete-btn {
			width: 30px;
			height: 30px;
			font-size: 14px;
		}

		.filters-row {
			grid-template-columns: 1fr;
		}

		/* Hide original bill, PR Excel, received by, payment info, days remaining, amounts, and ERP columns on mobile for space */
		.table-header .header-cell:nth-child(2),
		.table-header .header-cell:nth-child(3),
		.table-header .header-cell:nth-child(7),
		.table-header .header-cell:nth-child(8),
		.table-header .header-cell:nth-child(9),
		.table-header .header-cell:nth-child(10),
		.table-header .header-cell:nth-child(11),
		.table-header .header-cell:nth-child(12),
		.table-row .cell:nth-child(2),
		.table-row .cell:nth-child(3),
		.table-row .cell:nth-child(7),
		.table-row .cell:nth-child(8),
		.table-row .cell:nth-child(9),
		.table-row .cell:nth-child(10),
		.table-row .cell:nth-child(11),
		.table-row .cell:nth-child(12) {
			display: none;
		}
	}
</style>





