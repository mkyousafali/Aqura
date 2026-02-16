<script>
	import { onMount } from 'svelte';
	import XLSX from 'xlsx-js-style';
	import ClearanceCertificateManager from './ClearanceCertificateManager.svelte';
	import ManualScheduling from '$lib/components/desktop-interface/master/finance/ManualScheduling.svelte';
	import PriceVerifier from './PriceVerifier.svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { realtimeService } from '$lib/utils/realtimeService';
	import { openWindow } from '$lib/utils/windowManagerUtils';

	// State for receiving records
	let receivingRecords = []; // Current page records
	let allLoadedRecords = []; // All records loaded so far (accumulates as user scrolls)
	let paginatedRecords = [];
	let archivedRecords = [];
	let branches = [];
	let loading = false;
	let uploadingBillId = null;
	let uploadingExcelId = null;
	let generatingCertificateId = null;
	let updatingBillId = null;
	let deletingRecordId = null;
	let showArchived = false; // Toggle for archived records
	let selectedBranchFilter = ''; // Filter by branch
	let selectedPrExcelFilter = ''; // Filter by PR Excel verification ('' = all, 'verified', 'unverified')
	let vendorSearchTerm = ''; // Search by vendor name
	let selectedErpRefFilter = ''; // Filter by ERP invoice reference ('' = all, 'entered', 'not_entered')

	// Pagination state (disabled UI but optimized loading)
	let currentPage = 1;
	let pageSize = 500; // Load 500 records at once via RPC
	let totalPages = 1;
	let totalRecords = 0;

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
						console.log('✨ New record inserted, fetching details...');
						// Fetch just the new record via RPC instead of full reload
						try {
							const { supabase } = await import('$lib/utils/supabase');
							const newId = payload.new?.id;
							if (!newId) { await loadReceivingRecords(); return; }
							
							// Fetch the single new record with all joined details
							const { data: records, error } = await supabase
								.rpc('get_receiving_records_with_details', {
									p_limit: 500,
									p_offset: 0,
									p_branch_id: null,
									p_vendor_search: null,
									p_pr_excel_filter: null,
									p_erp_ref_filter: null
								});
							
							if (error || !records) { await loadReceivingRecords(); return; }
							
							const newRec = records.find(r => r.id === newId);
							if (!newRec) { await loadReceivingRecords(); return; }
							
							// Transform to nested shape
							const newRecord = {
								id: newRec.id,
								bill_number: newRec.bill_number,
								vendor_id: newRec.vendor_id,
								branch_id: newRec.branch_id,
								bill_date: newRec.bill_date,
								bill_amount: newRec.bill_amount,
								created_at: newRec.created_at,
								user_id: newRec.user_id,
								original_bill_url: newRec.original_bill_url,
								erp_purchase_invoice_reference: newRec.erp_purchase_invoice_reference,
								certificate_url: newRec.certificate_url,
								due_date: newRec.due_date,
								pr_excel_file_url: newRec.pr_excel_file_url,
								final_bill_amount: newRec.final_bill_amount,
								payment_method: newRec.payment_method,
								credit_period: newRec.credit_period,
								bank_name: newRec.bank_name,
								iban: newRec.iban,
								branches: newRec.branch_name_en ? { name_en: newRec.branch_name_en, location_en: newRec.branch_location_en } : null,
								vendors: newRec.vendor_name ? { erp_vendor_id: newRec.vendor_id, vendor_name: newRec.vendor_name, vat_number: newRec.vat_number, branch_id: newRec.branch_id } : null,
								users: newRec.username ? { username: newRec.username, hr_employees: { name: newRec.user_display_name } } : null,
								schedule_status: newRec.is_scheduled ? {
									receiving_record_id: newRec.id,
									is_paid: newRec.is_paid,
									pr_excel_verified: newRec.pr_excel_verified,
									pr_excel_verified_by: newRec.pr_excel_verified_by,
									pr_excel_verified_date: newRec.pr_excel_verified_date
								} : null,
								is_scheduled: newRec.is_scheduled,
								is_paid: newRec.is_paid,
								has_multiple_schedules: false,
								pr_excel_verified: newRec.pr_excel_verified,
								pr_excel_verified_by: newRec.pr_excel_verified_by,
								pr_excel_verified_date: newRec.pr_excel_verified_date
							};

							// Prepend to arrays (newest first) and avoid duplicates
							if (!receivingRecords.some(r => r.id === newId)) {
								receivingRecords = [newRecord, ...receivingRecords];
								allLoadedRecords = [newRecord, ...allLoadedRecords];
								totalRecords += 1;
								updatePaginatedRecords();
								console.log('✅ New record added to table without full reload');
							}
						} catch (err) {
							console.error('Error fetching new record, falling back to full reload:', err);
							await loadReceivingRecords();
						}
					} else if (payload.eventType === 'UPDATE') {
						console.log('📝 Record updated, refreshing...');
						// Update the specific record in the local arrays
						const updatedRecord = payload.new;
						const index = receivingRecords.findIndex(r => r.id === updatedRecord.id);
						if (index !== -1) {
							receivingRecords[index] = { ...receivingRecords[index], ...updatedRecord };
						}
						const allIndex = allLoadedRecords.findIndex(r => r.id === updatedRecord.id);
						if (allIndex !== -1) {
							allLoadedRecords[allIndex] = { ...allLoadedRecords[allIndex], ...updatedRecord };
						}
						updatePaginatedRecords();
					} else if (payload.eventType === 'DELETE') {
						console.log('🗑️ Record deleted, updating list...');
						// Remove the deleted record from local arrays
						receivingRecords = receivingRecords.filter(r => r.id !== payload.old?.id);
						allLoadedRecords = allLoadedRecords.filter(r => r.id !== payload.old?.id);
						updatePaginatedRecords();
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
						}
						// Also update in allLoadedRecords
						const allIndex = allLoadedRecords.findIndex(r => r.id === receivingRecordId);
						if (allIndex !== -1) {
							allLoadedRecords[allIndex].pr_excel_verified = payload.new.pr_excel_verified;
							allLoadedRecords[allIndex].pr_excel_verified_by = payload.new.pr_excel_verified_by;
							allLoadedRecords[allIndex].pr_excel_verified_date = payload.new.pr_excel_verified_date;
							if (allLoadedRecords[allIndex].schedule_status) {
								allLoadedRecords[allIndex].schedule_status.pr_excel_verified = payload.new.pr_excel_verified;
								allLoadedRecords[allIndex].schedule_status.pr_excel_verified_by = payload.new.pr_excel_verified_by;
								allLoadedRecords[allIndex].schedule_status.pr_excel_verified_date = payload.new.pr_excel_verified_date;
							}
						}
						updatePaginatedRecords();
					}
				}
			);

			console.log('✅ Real-time subscriptions setup complete');
		} catch (error) {
			console.error('❌ Error setting up real-time subscriptions:', error);
		}
	}

	// Load all branches for filter dropdown
	async function loadBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.order('name_en');
			if (!error && data) {
				branches = data;
			}
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadReceivingRecords() {
		loading = true;
		try {
			const startTime = performance.now();
			
			console.log('📋 Starting RPC-based receiving records load (500 per page)...');
			
			// Reset loaded records and filters
			allLoadedRecords = [];
			selectedBranchFilter = '';
			selectedPrExcelFilter = '';
			vendorSearchTerm = '';
			selectedErpRefFilter = '';
			currentPage = 1;

			// Load first page via RPC (count is returned from RPC itself)
			await loadPageData(1);
			loading = false; // Table displays immediately
			
			const endTime = performance.now();
			console.log(`✅ First batch (${pageSize} records) loaded via RPC in ${(endTime - startTime).toFixed(0)}ms`);
		} catch (err) {
			console.error('Error in loadReceivingRecords:', err);
			receivingRecords = [];
			allLoadedRecords = [];
			loading = false;
		}
	}

	// Load data for a specific page using RPC (with server-side filters)
	async function loadPageData(pageNum) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const startIdx = (pageNum - 1) * pageSize;

			// Build RPC params with filters
			const rpcParams = {
				p_limit: pageSize,
				p_offset: startIdx,
				p_branch_id: selectedBranchFilter || null,
				p_vendor_search: vendorSearchTerm?.trim() || null,
				p_pr_excel_filter: selectedPrExcelFilter || null,
				p_erp_ref_filter: selectedErpRefFilter || null
			};

			console.log(`📄 Loading page ${pageNum} via RPC (offset: ${startIdx}, limit: ${pageSize}, filters: ${JSON.stringify(rpcParams)})...`);
			
			// Single RPC call - all JOINs + filters done server-side
			const { data: records, error: rpcError } = await supabase
				.rpc('get_receiving_records_with_details', rpcParams);

			if (rpcError) {
				console.error(`❌ Error loading page ${pageNum}:`, rpcError);
				throw rpcError;
			}

			if (!records || records.length === 0) {
				console.log(`📊 No records on page ${pageNum}`);
				totalRecords = 0;
				totalPages = 1;
				receivingRecords = [];
				allLoadedRecords = [];
				paginatedRecords = [];
				return;
			}

			// Extract total count from first record (returned by RPC)
			totalRecords = records[0]?.total_count || records.length;
			totalPages = Math.ceil(totalRecords / pageSize);
			console.log(`📊 Loaded ${records.length} records for page ${pageNum} via RPC (total matching: ${totalRecords}, pages: ${totalPages})`);

			// Transform flat RPC response into nested shape the template expects
			const recordsWithDetails = records.map(record => ({
				id: record.id,
				bill_number: record.bill_number,
				vendor_id: record.vendor_id,
				branch_id: record.branch_id,
				bill_date: record.bill_date,
				bill_amount: record.bill_amount,
				created_at: record.created_at,
				user_id: record.user_id,
				original_bill_url: record.original_bill_url,
				erp_purchase_invoice_reference: record.erp_purchase_invoice_reference,
				certificate_url: record.certificate_url,
				due_date: record.due_date,
				pr_excel_file_url: record.pr_excel_file_url,
				final_bill_amount: record.final_bill_amount,
				payment_method: record.payment_method,
				credit_period: record.credit_period,
				bank_name: record.bank_name,
				iban: record.iban,
				// Nested objects for template compatibility
				branches: record.branch_name_en ? { name_en: record.branch_name_en, location_en: record.branch_location_en } : null,
				vendors: record.vendor_name ? { erp_vendor_id: record.vendor_id, vendor_name: record.vendor_name, vat_number: record.vat_number, branch_id: record.branch_id } : null,
				users: record.username ? { username: record.username, hr_employees: { name: record.user_display_name } } : null,
				// Payment schedule data
				schedule_status: record.is_scheduled ? {
					receiving_record_id: record.id,
					is_paid: record.is_paid,
					pr_excel_verified: record.pr_excel_verified,
					pr_excel_verified_by: record.pr_excel_verified_by,
					pr_excel_verified_date: record.pr_excel_verified_date
				} : null,
				is_scheduled: record.is_scheduled,
				is_paid: record.is_paid,
				has_multiple_schedules: false,
				pr_excel_verified: record.pr_excel_verified,
				pr_excel_verified_by: record.pr_excel_verified_by,
				pr_excel_verified_date: record.pr_excel_verified_date
			}));

			receivingRecords = recordsWithDetails;
			allLoadedRecords = recordsWithDetails;
			paginatedRecords = [...recordsWithDetails];
			console.log(`✅ Page ${pageNum} loaded via RPC (${recordsWithDetails.length} records shown)`);
		} catch (err) {
			console.error(`Error loading page ${pageNum}:`, err);
			receivingRecords = [];
			paginatedRecords = [];
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
				supabase.from('branches').select('id, name_en, location_en').in('id', uniqueBranchIds),
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


	// Load paginated data for filtered results - optimized to load only needed records
	// Filter loading function - currently disabled, will be implemented later
	// All filtering will use the initial loading system
	async function loadFilteredPageData(pageNum, filterCriteria) {
		console.log(`📄 Filter loading disabled - using initial loading system instead`);
		return;
	}

	// Update paginated records - no client-side filtering needed, server handles it
	function updatePaginatedRecords() {
		paginatedRecords = [...allLoadedRecords];
		console.log(`📄 Showing ${paginatedRecords.length} records`);
	}

	// Debounce timer for vendor search
	let vendorSearchTimer = null;

	// Server-side filter reload helper
	async function reloadWithFilters() {
		currentPage = 1;
		loading = true;
		await loadPageData(1);
		loading = false;
	}

	// Called by on:change on select filters
	function onFilterChange() {
		reloadWithFilters();
	}

	// Called by on:input on vendor search (debounced)
	function onVendorSearchInput() {
		if (vendorSearchTimer) clearTimeout(vendorSearchTimer);
		vendorSearchTimer = setTimeout(() => {
			reloadWithFilters();
		}, 500);
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

			// Update the display
			updatePaginatedRecords();
			
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

	// Download empty XLSX template for receiving
	function downloadReceivingTemplate() {
		const headers = ['Barcode', 'Product Name_En', 'Product Name_Ar', 'Received Qty', 'Free Qty', 'Unit', 'Cost', 'Sales Price'];
		// Each column gets its own professional light color
		const headerColors = [
			'D6E4F0', // Barcode - soft blue
			'E2EFDA', // Product Name_En - soft green
			'FCE4D6', // Product Name_Ar - soft peach
			'DAEEF3', // Received Qty - soft cyan
			'E4DFEC', // Free Qty - soft lavender
			'FFF2CC', // Unit - soft yellow
			'D9E2F3', // Cost - soft steel blue
			'E2F0D9', // Sales Price - soft mint
		];
		const border = {
			top: { style: 'thin', color: { rgb: '999999' } },
			bottom: { style: 'thin', color: { rgb: '999999' } },
			left: { style: 'thin', color: { rgb: '999999' } },
			right: { style: 'thin', color: { rgb: '999999' } }
		};
		const ws = XLSX.utils.aoa_to_sheet([headers]);
		// Apply individual header styles per column
		headers.forEach((_, i) => {
			const cell = XLSX.utils.encode_cell({ r: 0, c: i });
			if (ws[cell]) {
				ws[cell].s = {
					fill: { fgColor: { rgb: headerColors[i] } },
					font: { bold: true, color: { rgb: '333333' }, sz: 11, name: 'Calibri' },
					alignment: { horizontal: 'center', vertical: 'center' },
					border
				};
			}
		});
		// Set column widths
		ws['!cols'] = [
			{ wch: 18 }, // Barcode
			{ wch: 30 }, // Product Name_En
			{ wch: 30 }, // Product Name_Ar
			{ wch: 14 }, // Received Qty
			{ wch: 12 }, // Free Qty
			{ wch: 10 }, // Unit
			{ wch: 18 }, // Cost
			{ wch: 14 }, // Sales Price
		];
		// Set row height for header
		ws['!rows'] = [{ hpt: 28 }];
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Receiving Template');
		XLSX.writeFile(wb, 'Receiving_Template.xlsx');
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
			const updatedRecords = receivingRecords.map(record => 
				record.id === selectedRecord.id 
					? { ...record, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: record
			);
			receivingRecords = updatedRecords;

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
			allLoadedRecords = allLoadedRecords.filter(r => r.id !== recordId);
			updatePaginatedRecords();

			alert('Receiving record deleted successfully');
		} catch (error) {
			console.error('Error deleting receiving record:', error);
			alert(`Failed to delete receiving record: ${error.message}`);
		} finally {
			deletingRecordId = null;
		}
	}
</script>

<!-- Receiving Records Window Content -->
<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">

	<!-- Filter Controls -->
	<div class="px-8 pt-6">
		<div class="mb-4 flex gap-3 flex-wrap">
			<div class="flex-1 min-w-[160px]">
				<label for="branch-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">Filter by Branch</label>
				<select id="branch-filter" bind:value={selectedBranchFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">All Branches</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
					{/each}
				</select>
			</div>
			<div class="flex-1 min-w-[140px]">
				<label for="pr-excel-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">PR Excel Status</label>
				<select id="pr-excel-filter" bind:value={selectedPrExcelFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">All Records</option>
					<option value="verified">✅ Verified</option>
					<option value="unverified">❌ Unverified</option>
				</select>
			</div>
			<div class="flex-1 min-w-[160px]">
				<label for="vendor-search" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">Search Vendor</label>
				<input 
					id="vendor-search" 
					type="text" 
					bind:value={vendorSearchTerm} 
					on:input={onVendorSearchInput}
					placeholder="Type vendor name..." 
					class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all"
				/>
			</div>
			<div class="flex-1 min-w-[140px]">
				<label for="erp-ref-filter" class="block mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">ERP Invoice Ref</label>
				<select id="erp-ref-filter" bind:value={selectedErpRefFilter} on:change={onFilterChange} class="w-full px-4 py-2.5 text-sm border border-slate-200 rounded-xl bg-white/80 backdrop-blur-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all">
					<option value="">All Records</option>
					<option value="entered">✓ Entered</option>
					<option value="not_entered">✗ Not Entered</option>
				</select>
			</div>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 px-8 pb-6 relative overflow-hidden flex flex-col">
		<!-- Decorative blurred circles -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] pointer-events-none"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col w-full">
			<!-- Table Container (glassmorphism card) -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
		{#if loading}
			<div class="flex items-center justify-center py-20">
				<div class="spinner"></div>
				<p class="ml-4 text-slate-500">⏳ Loading receiving records...</p>
			</div>
		{:else if paginatedRecords.length === 0}
			<div class="flex items-center justify-center py-20">
				<p class="text-slate-500 text-lg">📭 No receiving records found.</p>
			</div>
		{:else}
			<!-- Table scroll wrapper -->
			<div class="overflow-x-auto flex-1">
				<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
					<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
						<tr>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">#</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Certificate</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Original Bill</th>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">PR Excel</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Bill Info</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Vendor Details</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Branch</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Payment Info</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Days to Due</th>
							<th class="px-3 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Amounts</th>
							{#if isMasterAdmin}
								<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Actions</th>
							{/if}
						</tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
				
				{#each paginatedRecords as record, index}
					<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
					<td class="px-3 py-3 text-sm text-center font-semibold text-slate-500">
						{index + 1 + (currentPage - 1) * pageSize}
					</td>
					<td class="px-3 py-3 text-sm text-center">
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
											<span>📜</span>
											<small>Generate Certificate</small>
										</button>
									{/if}
								</div>
							{/if}
					</td>
					<td class="px-3 py-3 text-sm text-center">
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
					</td>
					<td class="px-3 py-3 text-sm text-center">
							{#if record.pr_excel_file_url}
								<div class="excel-file-container">
									<button 
										class="excel-file-link"
										on:click={() => openWindow({
											id: `price-verifier-${record.id}`,
											title: 'Price Verifier',
											component: PriceVerifier,
											props: { record },
											icon: '🔍',
											size: { width: 1000, height: 700 },
											minSize: { width: 600, height: 400 },
											position: { x: 150, y: 100 }
										})}
									>
										<div class="excel-icon">📊</div>
										<small>PR Excel</small>
									</button>
									{#if record.pr_excel_verified}
										<span class="text-green-600 text-lg" title="Verified">✓</span>
									{:else}
										<label class="verification-checkbox">
											<input
												type="checkbox"
												checked={false}
												on:change={(e) => handlePRExcelVerification(record.id, e.target.checked)}
											/>
											<span class="checkbox-label">Verify</span>
										</label>
									{/if}
									<button class="update-bill-btn" on:click={() => uploadPRExcel(record.id)} title="Upload updated PR Excel">
										<span>🔄</span>
										<small>Update</small>
									</button>
								</div>
							{:else}
								<div class="upload-excel-container">
									{#if uploadingExcelId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>Uploading...</small>
										</div>
									{:else}
										<div class="flex items-center gap-1.5" style="height: 50px;">
											<button class="upload-excel-btn" style="flex: 1; height: 100%;" on:click={() => uploadPRExcel(record.id)}>
												<span>📊</span>
												<small>Upload</small>
											</button>
											<button class="upload-excel-btn" style="flex: 1; height: 100%; background: #f0fdf4; border-color: #10b981; color: #047857;" on:click={downloadReceivingTemplate} title="Download empty PR Excel template">
												<span>📥</span>
												<small>Template</small>
											</button>
										</div>
									{/if}
								</div>
							{/if}
						</td>
						
						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div class="font-semibold text-slate-800">#{record.bill_number || 'N/A'}</div>
								<div class="text-xs text-slate-400">Bill Date: {formatDate(record.bill_date)}</div>
								<div class="text-xs text-slate-400">Received: {formatDate(record.created_at)}</div>
								<div class="text-xs text-slate-400">By: {record.users?.hr_employees?.name || record.users?.username || 'N/A'}</div>
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div class="font-semibold text-slate-800">{record.vendors?.vendor_name || 'N/A'}</div>
								<div class="text-xs text-slate-400">ID: {record.vendors?.erp_vendor_id || 'N/A'}</div>
								<div class="text-xs text-slate-400">VAT: {record.vendors?.vat_number || 'N/A'}</div>
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div>{record.branches?.name_en || 'N/A'}</div>
								{#if record.branches?.location_en}
									<div class="text-xs text-slate-400">{record.branches.location_en}</div>
								{/if}
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-slate-700">
							<div>
								<div class="font-semibold text-slate-800">{record.payment_method || 'N/A'}</div>
								<div class="text-xs text-slate-400">Due: {formatDate(record.due_date)}</div>
								{#if record.credit_period}
									<div class="text-xs text-slate-400">{record.credit_period} days</div>
								{/if}
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-left text-slate-700">
							<div>
								{#if record.payment_method?.toLowerCase()?.includes('on delivery') || record.is_paid || record.schedule_status?.is_paid}
									<div class="text-xs text-emerald-600">✓ Paid</div>
								{:else if record.is_scheduled || record.schedule_status}
									<div class:text-red-600={record.due_date && getDaysRemaining(record.due_date).includes('-')}>{getDaysRemaining(record.due_date)}</div>
									<div class="text-xs text-blue-600">📅 {record.has_multiple_schedules ? 'Split Scheduled' : 'Scheduled'}</div>
								{:else}
									<div class:text-red-600={record.due_date && getDaysRemaining(record.due_date).includes('-')}>{getDaysRemaining(record.due_date)}</div>
									<button 
										class="text-xs text-white bg-orange-500 hover:bg-orange-600 px-2 py-0.5 rounded cursor-pointer border-none transition-colors duration-200"
										title="Schedule payment for this record"
										on:click={() => openWindow({
											id: `manual-scheduling-${Date.now()}`,
											title: 'Manual Scheduling',
											component: ManualScheduling,
											props: {},
											icon: '📅',
											size: { width: 900, height: 650 },
											minSize: { width: 600, height: 400 },
											position: { x: 140, y: 140 }
										})}
									>
										📅 Schedule
									</button>
								{/if}
							</div>
						</td>
						
						<td class="px-3 py-3 text-sm text-left text-slate-700">
							<div>
								<div>Bill: {parseFloat(record.bill_amount || 0).toFixed(2)}</div>
								<div class="font-bold text-emerald-700">Final: {parseFloat(record.final_bill_amount || 0).toFixed(2)}</div>
								{#if record.erp_purchase_invoice_reference}
									<div class="text-xs text-slate-500">ERP: {record.erp_purchase_invoice_reference}</div>
								{:else}
									<button 
										class="text-xs text-red-400 hover:text-red-600 cursor-pointer bg-transparent border-none p-0 text-left" 
										on:click={() => openErpPopup(record)}
										title="Click to enter ERP invoice reference"
									>
										ERP: Not Entered
									</button>
								{/if}
							</div>
						</td>
						
						{#if isMasterAdmin}
							<td class="px-3 py-3 text-sm text-center">
								{#if deletingRecordId === record.id}
									<div class="deleting-indicator">
										<div class="spinner-small"></div>
										<small>Deleting...</small>
									</div>
								{:else}
									<button 
										class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
										on:click={() => deleteReceivingRecord(record.id)}
										title="Delete this receiving record (Master Admin only)"
									>
										🗑️
									</button>
								{/if}
							</td>
						{/if}
					</tr>
				{/each}
					</tbody>
				</table>
			</div>
		{/if}

		<!-- Footer -->
		<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold flex items-center justify-between">
			<span>📊 Total: {totalRecords} • Page: {currentPage}/{totalPages} • Showing: {paginatedRecords.length}</span>
			{#if totalPages > 1}
				<div class="flex items-center gap-2">
					<button 
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage = 1; loading = true; loadPageData(1).then(() => loading = false); }}
						disabled={currentPage <= 1 || loading}
					>⏮ First</button>
					<button 
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage--; loading = true; loadPageData(currentPage).then(() => loading = false); }}
						disabled={currentPage <= 1 || loading}
					>◀ Prev</button>
					<span class="px-3 py-1.5 text-sm font-bold text-slate-700">Page {currentPage} of {totalPages}</span>
					<button 
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage++; loading = true; loadPageData(currentPage).then(() => loading = false); }}
						disabled={currentPage >= totalPages || loading}
					>Next ▶</button>
					<button 
						class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
						on:click={() => { currentPage = totalPages; loading = true; loadPageData(currentPage).then(() => loading = false); }}
						disabled={currentPage >= totalPages || loading}
					>Last ⏭</button>
				</div>
			{/if}
		</div>
			</div>
		</div>
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
	/* Spinner animations */
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

	/* Certificate styles */
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
		height: 50px;
	}

	.upload-excel-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 50px;
		background: #f0f9ff;
		border: 2px dashed #0ea5e9;
		border-radius: 6px;
		color: #0369a1;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px;
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
		flex-direction: row;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 50px;
		gap: 6px;
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

	.excel-file-link {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 50px;
		background: #f0fdf4;
		border: 2px solid #22c55e;
		border-radius: 6px;
		color: #15803d;
		text-decoration: none;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px 8px;
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

</style>





