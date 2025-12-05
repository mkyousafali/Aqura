<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';

	export let windowId;
	export let dataType; // 'bills', 'tasks', 'completed', 'incomplete', 'no-original', 'no-erp'
	export let title;
	export let initialBranchFilter = 'all'; // Receive branch filter from parent
	export let initialSelectedBranch = ''; // Receive selected branch from parent
	export let initialDateFilter = 'all'; // Receive date filter from parent
	export let initialDateFrom = ''; // Receive date from from parent
	export let initialDateTo = ''; // Receive date to from parent
	export let bind = undefined; // Optional callback to bind component instance
	
	// Expose refresh function that window manager can call
	export function onRefresh() {
		console.log('🔄 Refreshing data from database...');
		return loadData();
	}

	let data = [];
	let filteredData = [];
	let searchQuery = '';
	let loading = true;
	let error = null;
	let uploadingBillId = null;
	let updatingBillId = null;
	let sortBy = '';
	let sortOrder = 'asc';
	
	// ERP Reference popup state
	let showErpPopup = false;
	let selectedRecord = null;
	let erpReferenceValue = '';
	let updatingErp = false;
	
	// Branch filtering
	let branches = [];
	let branchFilterMode = initialBranchFilter;
	let selectedBranch = initialSelectedBranch;
	let loadingBranches = false;
	
	// Date filtering
	let dateFilterMode = initialDateFilter;
	let dateFrom = initialDateFrom;
	let dateTo = initialDateTo;

	// Column configurations for different data types
	const columnConfigs = {
		bills: [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
			{ key: 'branch_name', label: 'Branch', sortable: true },
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Created Date', sortable: true, type: 'date' }
		],
		tasks: [
			{ key: 'task_title', label: 'Task Title', sortable: true },
			{ key: 'assigned_user_name', label: 'Assigned To', sortable: true },
			{ key: 'role_type', label: 'Role', sortable: true },
			{ key: 'completion_status', label: 'Status', sortable: true },
			{ key: 'created_at', label: 'Created', sortable: true, type: 'date' }
		],
		completed: [
			{ key: 'task_title', label: 'Task Title', sortable: true },
			{ key: 'completed_by_name', label: 'Completed By', sortable: true },
			{ key: 'completed_at', label: 'Completed At', sortable: true, type: 'date' },
			{ key: 'erp_reference_number', label: 'ERP Reference', sortable: true }
		],
		incomplete: [
			{ key: 'task_title', label: 'Task Title', sortable: true },
			{ key: 'assigned_user_name', label: 'Assigned To', sortable: true },
			{ key: 'role_type', label: 'Role', sortable: true },
			{ key: 'completion_status', label: 'Status', sortable: true },
			{ key: 'created_at', label: 'Created', sortable: true, type: 'date' },
			{ key: 'days_pending', label: 'Days Pending', sortable: true, type: 'number' }
		],
		'no-original': [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
			{ key: 'branch_name', label: 'Branch', sortable: true },
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Received At', sortable: true, type: 'date' },
			{ key: 'upload_action', label: 'Upload', sortable: false, type: 'action' }
		],
		'no-pr-excel': [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
			{ key: 'branch_name', label: 'Branch', sortable: true },
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Received At', sortable: true, type: 'date' },
			{ key: 'upload_action', label: 'Upload PR Excel', sortable: false, type: 'action' }
		],
		'no-erp': [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
			{ key: 'branch_name', label: 'Branch', sortable: true },
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Received At', sortable: true, type: 'date' },
			{ key: 'erp_action', label: 'ERP Reference', sortable: false, type: 'action' }
		]
	};

	$: columns = columnConfigs[dataType] || [];
	$: {
		// First apply search filter
		let filtered;
		if (searchQuery.trim() === '') {
			filtered = [...data];
		} else {
			const query = searchQuery.toLowerCase();
			filtered = data.filter(item => 
				columns.some(col => {
					const value = item[col.key];
					return value && value.toString().toLowerCase().includes(query);
				})
			);
		}
		
		// Then apply sorting if sortBy is set
		if (sortBy && columns.find(col => col.key === sortBy)) {
			filtered = filtered.sort((a, b) => {
				let aVal = a[sortBy];
				let bVal = b[sortBy];
				
				// Handle null/undefined values
				if (aVal == null) aVal = '';
				if (bVal == null) bVal = '';
				
				// Handle different data types
				const column = columns.find(col => col.key === sortBy);
				if (column?.type === 'date') {
					aVal = new Date(aVal).getTime();
					bVal = new Date(bVal).getTime();
				} else if (column?.type === 'currency' || column?.type === 'number') {
					aVal = parseFloat(aVal) || 0;
					bVal = parseFloat(bVal) || 0;
				} else {
					// Convert to string for comparison
					aVal = aVal.toString().toLowerCase();
					bVal = bVal.toString().toLowerCase();
				}
				
				if (sortOrder === 'asc') {
					return aVal < bVal ? -1 : aVal > bVal ? 1 : 0;
				} else {
					return aVal > bVal ? -1 : aVal < bVal ? 1 : 0;
				}
			});
		}
		
		filteredData = filtered;
	}
	
	// Helper functions for date filtering
	function getToday() {
		const today = new Date();
		return today.toISOString().split('T')[0];
	}
	
	function getYesterday() {
		const yesterday = new Date();
		yesterday.setDate(yesterday.getDate() - 1);
		return yesterday.toISOString().split('T')[0];
	}

	async function loadData() {
		try {
			loading = true;
			const { supabase } = await import('$lib/utils/supabase');
			
			let query;
			
			switch (dataType) {
				case 'bills':
					query = supabase
						.from('receiving_records')
						.select(`
							*,
							vendors (
								vendor_name,
								vat_number
							),
							branches (
								name_en
							)
						`);
					
					// Apply branch filter
					if (branchFilterMode === 'branch' && selectedBranch) {
						query = query.eq('branch_id', selectedBranch);
					}
					
					// Apply date filter
					if (dateFilterMode === 'today') {
						const today = getToday();
						query = query.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
					} else if (dateFilterMode === 'yesterday') {
						const yesterday = getYesterday();
						query = query.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
					} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
						query = query.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
					}
					
					query = query.order('created_at', { ascending: false });
					break;
					
				case 'tasks':
					query = supabase.rpc('get_all_receiving_tasks');
					break;
					
				case 'completed':
					query = supabase.rpc('get_completed_receiving_tasks');
					break;
					
				case 'incomplete':
					query = supabase.rpc('get_incomplete_receiving_tasks');
					break;
					
				case 'no-original':
					query = supabase
						.from('receiving_records')
						.select(`
							*,
							vendors (
								vendor_name,
								vat_number
							),
							branches (
								name_en
							)
						`)
						.or('original_bill_url.is.null,original_bill_url.eq.');
					
					// Apply branch filter
					if (branchFilterMode === 'branch' && selectedBranch) {
						query = query.eq('branch_id', selectedBranch);
					}
					
					// Apply date filter
					if (dateFilterMode === 'today') {
						const today = getToday();
						query = query.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
					} else if (dateFilterMode === 'yesterday') {
						const yesterday = getYesterday();
						query = query.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
					} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
						query = query.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
					}
					
					query = query.order('created_at', { ascending: false });
					break;
					
				case 'no-erp':
					query = supabase
						.from('receiving_records')
						.select(`
							id,
							bill_number,
							vendor_id,
							bill_date,
							bill_amount,
							final_bill_amount,
							created_at,
							erp_purchase_invoice_reference,
							branch_id,
							vendors!inner (
								vendor_name,
								vat_number
							),
							branches!inner (
								name_en
							)
						`)
						.or('erp_purchase_invoice_reference.is.null,erp_purchase_invoice_reference.eq.');
					
					// Apply branch filter
					if (branchFilterMode === 'branch' && selectedBranch) {
						query = query.eq('branch_id', selectedBranch);
					}
					
					// Apply date filter
					if (dateFilterMode === 'today') {
						const today = getToday();
						query = query.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
					} else if (dateFilterMode === 'yesterday') {
						const yesterday = getYesterday();
						query = query.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
					} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
						query = query.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
					}
					
					query = query.order('created_at', { ascending: false });
					break;

				case 'no-pr-excel':
					console.log('🔍 Loading records without PR Excel...');
					query = supabase
						.from('receiving_records')
						.select(`
							*,
							vendors (
								vendor_name,
								vat_number
							),
							branches (
								name_en
							)
						`)
						.or('pr_excel_file_url.is.null,pr_excel_file_url.eq.');
					
					// Apply branch filter
					if (branchFilterMode === 'branch' && selectedBranch) {
						query = query.eq('branch_id', selectedBranch);
					}
					
					// Apply date filter
					if (dateFilterMode === 'today') {
						const today = getToday();
						query = query.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
					} else if (dateFilterMode === 'yesterday') {
						const yesterday = getYesterday();
						query = query.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
					} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
						query = query.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
					}
					
					query = query.order('created_at', { ascending: false });
					break;
					
				default:
					throw new Error(`Unknown data type: ${dataType}`);
			}

			const { data: result, error: queryError } = await query;
			
			console.log('🔍 Query result for dataType:', dataType);
			console.log('📊 Data received:', result);
			console.log('❌ Query error:', queryError);

			if (queryError) {
				throw queryError;
			}

			// Transform data for display
			data = transformData(result || []);
			
		} catch (err) {
			console.error('Error loading data:', err);
			error = err.message;
			data = [];
		} finally {
			loading = false;
		}
	}
	
	// Load branches for filtering
	async function loadBranches() {
		loadingBranches = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: branchData, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = branchData || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		} finally {
			loadingBranches = false;
		}
	}

	function transformData(rawData) {
		return rawData.map(item => {
			const transformed = { ...item };
			
			// Flatten joined vendor data for receiving_records queries
			if (dataType === 'bills' || dataType === 'no-original' || dataType === 'no-pr-excel' || dataType === 'no-erp') {
				// Handle vendor data from join
				if (item.vendors) {
					transformed.vendor_name = item.vendors.vendor_name || 'Unknown Vendor';
					transformed.vendor_vat_number = item.vendors.vat_number || 'N/A';
				} else {
					transformed.vendor_name = 'Unknown Vendor';
					transformed.vendor_vat_number = 'N/A';
				}
				
				// Handle branch data from join
				if (item.branches) {
					transformed.branch_name = item.branches.name_en || 'Unknown Branch';
				} else {
					transformed.branch_name = 'Unknown Branch';
				}
			}
			
			// Add computed fields based on data type
			if (dataType === 'tasks' || dataType === 'incomplete') {
				// Data now comes directly from RPC functions with task_title and assigned_user_name already included
				transformed.task_title = item.task_title || 'N/A';
				// assigned_user_name is already provided by the RPC function
				
				if (dataType === 'incomplete') {
					// days_pending is already calculated in the RPC function
					transformed.days_pending = item.days_pending || 0;
				}
			}
			
			if (dataType === 'completed') {
				// Data comes from RPC function with all fields already included
				transformed.task_title = item.task_title || 'N/A';
				transformed.completed_by_name = item.completed_by_name || 'N/A';
				transformed.completed_at = item.completed_at;
				transformed.erp_reference_number = item.erp_reference_number || 'N/A';
			}
			
			return transformed;
		});
	}

	function formatValue(value, type) {
		if (!value) return 'N/A';
		
		switch (type) {
			case 'date':
				return new Date(value).toLocaleDateString('en-GB', {
					day: '2-digit',
					month: '2-digit',
					year: 'numeric'
				});
			case 'currency':
				return new Intl.NumberFormat('en-US', { 
					minimumFractionDigits: 2,
					maximumFractionDigits: 2
				}).format(value);
			case 'number':
				return value.toString();
			default:
				return value.toString();
		}
	}

	function handleSort(columnKey) {
		if (sortBy === columnKey) {
			sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = columnKey;
			sortOrder = 'asc';
		}
		// The reactive statement will handle the actual sorting
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

				// Reload data to show updated status
				await loadData();
				
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

				// Reload data to show updated status
				await loadData();
				
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
		uploadingBillId = recordId; // Reuse the same loading state variable
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.xlsx,.xls,.csv';
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
					console.error('Error updating record with PR Excel URL:', updateError);
					alert('Error saving PR Excel file reference. Please try again.');
					return;
				}

				// Reload data to show updated results
				await loadData();
				alert('PR Excel file uploaded successfully!');
				
			} catch (error) {
				console.error('Error in PR Excel upload process:', error);
				alert('Error uploading PR Excel file. Please try again.');
			} finally {
				uploadingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	// ERP Reference functions
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
		if (!selectedRecord || !erpReferenceValue.trim()) {
			alert('Please enter a valid ERP reference number');
			return;
		}

		updatingErp = true;
		
		try {
			const { supabaseAdmin } = await import('$lib/utils/supabase');
			
			const { error } = await supabaseAdmin
				.from('receiving_records')
				.update({ 
					erp_purchase_invoice_reference: erpReferenceValue.trim(),
					updated_at: new Date().toISOString()
				})
				.eq('id', selectedRecord.id);

			if (error) {
				console.error('Error updating ERP reference:', error);
				alert('Error updating ERP reference. Please try again.');
				return;
			}

			// Update the local data
			const updatedData = data.map(item => 
				item.id === selectedRecord.id 
					? { ...item, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: item
			);
			data = updatedData;

			console.log('✅ ERP reference updated successfully');
			closeErpPopup();
			
		} catch (error) {
			console.error('Error updating ERP reference:', error);
			alert('Error updating ERP reference. Please try again.');
		} finally {
			updatingErp = false;
		}
	}

	function closeWindow() {
		windowManager.closeWindow(windowId);
	}

	onMount(() => {
		loadBranches();
		loadData();
		
		// Call bind callback if provided
		if (bind) {
			bind({ onRefresh });
		}
	});
	
	// Function to handle filter changes
	function handleFilterChange() {
		loadData();
	}
</script>

<div class="receiving-data-window">
	<div class="window-header">
		<h2>{title}</h2>
		<button class="close-btn" on:click={closeWindow}>✕</button>
	</div>

	<div class="window-controls">
		<!-- Branch Filter -->
		<div class="filter-section">
			<label class="filter-label">
				<input
					type="radio"
					bind:group={branchFilterMode}
					value="all"
					class="filter-radio"
					on:change={handleFilterChange}
				/>
				All Branches
			</label>
			<label class="filter-label">
				<input
					type="radio"
					bind:group={branchFilterMode}
					value="branch"
					class="filter-radio"
					on:change={handleFilterChange}
				/>
				By Branch
			</label>
			{#if branchFilterMode === 'branch'}
				<select bind:value={selectedBranch} class="branch-select" disabled={loadingBranches} on:change={handleFilterChange}>
					<option value="">Select Branch...</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.name_en}</option>
					{/each}
				</select>
			{/if}
		</div>
		
		<!-- Date Filter -->
		<div class="date-filter">
			<label class="filter-label">
				<input
					type="radio"
					bind:group={dateFilterMode}
					value="all"
					class="filter-radio"
					on:change={handleFilterChange}
				/>
				All Dates
			</label>
			<label class="filter-label">
				<input
					type="radio"
					bind:group={dateFilterMode}
					value="today"
					class="filter-radio"
					on:change={handleFilterChange}
				/>
				Today
			</label>
			<label class="filter-label">
				<input
					type="radio"
					bind:group={dateFilterMode}
					value="yesterday"
					class="filter-radio"
					on:change={handleFilterChange}
				/>
				Yesterday
			</label>
			<label class="filter-label">
				<input
					type="radio"
					bind:group={dateFilterMode}
					value="range"
					class="filter-radio"
					on:change={handleFilterChange}
				/>
				Date Range
			</label>
			{#if dateFilterMode === 'range'}
				<div class="date-range-selector">
					<div class="date-input-group">
						<span class="date-label">From:</span>
						<input
							type="date"
							bind:value={dateFrom}
							class="date-input"
							on:change={handleFilterChange}
						/>
					</div>
					<div class="date-input-group">
						<span class="date-label">To:</span>
						<input
							type="date"
							bind:value={dateTo}
							class="date-input"
							on:change={handleFilterChange}
						/>
					</div>
				</div>
			{/if}
		</div>
		
		<div class="search-container">
			<input
				type="text"
				placeholder="Search..."
				bind:value={searchQuery}
				class="search-input"
			/>
			<span class="search-icon">🔍</span>
		</div>
		<button 
			class="refresh-btn"
			on:click={loadData}
			disabled={loading}
			title="Refresh data from database"
		>
			{#if loading}
				<span class="refresh-icon spinning">🔄</span>
			{:else}
				<span class="refresh-icon">🔄</span>
			{/if}
			Refresh
		</button>
		<div class="record-count">
			{filteredData.length} of {data.length} records
		</div>
	</div>

	<div class="table-container">
		{#if loading}
			<div class="loading">Loading...</div>
		{:else if error}
			<div class="error">Error: {error}</div>
		{:else if filteredData.length === 0}
			<div class="no-data">No data found</div>
		{:else}
			<table class="data-table">
				<thead>
					<tr>
						{#each columns as column}
							<th class="sortable px-4 py-2 text-left font-semibold text-gray-700 border-b">
								{column.label}
								{#if column.sortable}
									<button on:click={() => handleSort(column.key)} class="ml-1 text-gray-500 hover:text-gray-700">
										{sortBy === column.key ? (sortOrder === 'asc' ? '↑' : '↓') : '↕'}
									</button>
								{/if}
							</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each filteredData as row}
						<tr>
							{#each columns as column}
								<td class="px-4 py-2 text-center">
									{#if column.key === 'upload_action'}
										<!-- Check if this record already has the file -->
										{#if (dataType === 'no-original' && row.original_bill_url) || (dataType === 'no-pr-excel' && row.pr_excel_file_url)}
											<!-- Show update button for existing files -->
											<div class="flex gap-1">
												<button
													class="bg-green-500 hover:bg-green-700 text-white font-bold py-1 px-2 rounded text-xs"
													disabled={true}
													title="File already uploaded"
												>
													✓ Uploaded
												</button>
												<button
													class="bg-orange-500 hover:bg-orange-700 text-white font-bold py-1 px-2 rounded text-xs disabled:opacity-50 disabled:cursor-not-allowed"
													disabled={updatingBillId === row.id}
													on:click={() => {
														if (dataType === 'no-pr-excel') {
															uploadPRExcel(row.id);
														} else {
															updateOriginalBill(row.id);
														}
													}}
													title="Upload updated version"
												>
													{#if updatingBillId === row.id}
														<span class="inline-flex items-center">
															<svg class="animate-spin -ml-1 mr-1 h-3 w-3 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
																<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
																<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
															</svg>
															Updating...
														</span>
													{:else}
														🔄 Update
													{/if}
												</button>
											</div>
										{:else}
											<!-- Show upload button for missing files -->
											<button
												class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-3 rounded text-sm disabled:opacity-50 disabled:cursor-not-allowed"
												disabled={uploadingBillId === row.id}
												on:click={() => {
													if (dataType === 'no-pr-excel') {
														uploadPRExcel(row.id);
													} else {
														uploadOriginalBill(row.id);
													}
												}}
											>
												{#if uploadingBillId === row.id}
													<span class="inline-flex items-center">
														<svg class="animate-spin -ml-1 mr-2 h-3 w-3 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
															<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
															<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
														</svg>
														Uploading...
													</span>
												{:else}
													{dataType === 'no-pr-excel' ? 'Upload PR Excel' : 'Upload Original Bill'}
												{/if}
											</button>
										{/if}
									{:else if column.key === 'erp_action'}
										{#if row.erp_purchase_invoice_reference}
											<div class="erp-reference-display">
												<span class="erp-ref-value">{row.erp_purchase_invoice_reference}</span>
												<button 
													class="erp-edit-btn"
													on:click={() => openErpPopup(row)}
													title="Edit ERP Reference"
												>
													✏️
												</button>
											</div>
										{:else}
											<button 
												class="erp-ref-empty"
												on:click={() => openErpPopup(row)}
												title="Click to enter ERP invoice reference"
											>
												Enter ERP Ref
											</button>
										{/if}
									{:else}
										{formatValue(row[column.key], column.type)}
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<!-- ERP Invoice Reference Popup -->
{#if showErpPopup}
	<div class="erp-popup-overlay" on:click={closeErpPopup}>
		<div class="erp-popup-modal" on:click|stopPropagation>
			<div class="erp-popup-header">
				<h3>Update ERP Invoice Reference</h3>
				<button class="erp-popup-close" on:click={closeErpPopup}>&times;</button>
			</div>
			<div class="erp-popup-content">
				<p><strong>Bill Number:</strong> {selectedRecord?.bill_number || 'Unknown Bill'}</p>
				<p><strong>Vendor:</strong> {selectedRecord?.vendor_name || 'Unknown Vendor'}</p>
				<p><strong>Amount:</strong> {selectedRecord?.bill_amount ? parseFloat(selectedRecord.bill_amount).toFixed(2) : '0.00'} SAR</p>
				<div class="erp-input-group">
					<label for="erpRef">ERP Invoice Reference:</label>
					<input 
						id="erpRef"
						type="text" 
						bind:value={erpReferenceValue}
						placeholder="Enter ERP invoice reference"
						class="erp-input"
						disabled={updatingErp}
					/>
				</div>
				<div class="erp-popup-actions">
					<button 
						class="erp-cancel-btn"
						on:click={closeErpPopup}
						disabled={updatingErp}
					>
						Cancel
					</button>
					<button 
						class="erp-save-btn"
						on:click={updateErpReference}
						disabled={updatingErp || !erpReferenceValue.trim()}
					>
						{#if updatingErp}
							<span class="flex items-center">
								<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
									<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
									<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
								</svg>
								Updating...
							</span>
						{:else}
							Update
						{/if}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.receiving-data-window {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: white;
		border-radius: 8px;
	}

	.window-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 20px;
		border-bottom: 1px solid #e2e8f0;
		background: #f8fafc;
		border-radius: 8px 8px 0 0;
	}

	.window-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
		color: #1e293b;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 18px;
		cursor: pointer;
		padding: 4px 8px;
		border-radius: 4px;
		color: #64748b;
	}

	.close-btn:hover {
		background: #e2e8f0;
		color: #1e293b;
	}

	.window-controls {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 16px;
		padding: 16px 20px;
		border-bottom: 1px solid #e2e8f0;
		background: white;
		flex-wrap: wrap;
	}
	
	.filter-section {
		display: flex;
		align-items: center;
		gap: 12px;
		flex-wrap: wrap;
	}
	
	.filter-label {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 14px;
		color: #475569;
		cursor: pointer;
		user-select: none;
	}
	
	.filter-radio {
		cursor: pointer;
	}
	
	.branch-select {
		padding: 6px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		cursor: pointer;
		min-width: 200px;
	}
	
	.branch-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.branch-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}
	
	.date-filter {
		display: flex;
		align-items: center;
		gap: 12px;
		flex-wrap: wrap;
	}
	
	.date-range-selector {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
	}
	
	.date-input-group {
		display: flex;
		align-items: center;
		gap: 6px;
	}
	
	.date-label {
		font-size: 14px;
		color: #475569;
		font-weight: 500;
	}
	
	.date-input {
		padding: 6px 10px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		cursor: pointer;
	}
	
	.date-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-container {
		position: relative;
		flex: 1;
		max-width: 400px;
		min-width: 200px;
	}

	.search-input {
		width: 100%;
		padding: 8px 12px 8px 40px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-icon {
		position: absolute;
		left: 12px;
		top: 50%;
		transform: translateY(-50%);
		color: #9ca3af;
	}

	.record-count {
		font-size: 14px;
		color: #64748b;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.refresh-icon {
		display: inline-block;
		font-size: 16px;
		transition: transform 0.3s ease;
	}

	.refresh-icon.spinning {
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

	.table-container {
		flex: 1;
		overflow: auto;
		padding: 0;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
	}

	.data-table th,
	.data-table td {
		padding: 12px 16px;
		text-align: left;
		border-bottom: 1px solid #e2e8f0;
	}

	.data-table th {
		background: #f8fafc;
		font-weight: 600;
		color: #374151;
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.data-table th.sortable {
		cursor: pointer;
		user-select: none;
	}

	.data-table th.sortable:hover {
		background: #e2e8f0;
	}

	.data-table tbody tr:hover {
		background: #f9fafb;
	}

	.loading,
	.error,
	.no-data {
		display: flex;
		justify-content: center;
		align-items: center;
		height: 200px;
		font-size: 16px;
		color: #64748b;
	}

	.error {
		color: #dc2626;
	}

	/* ERP Reference Styles */
	.erp-reference-display {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.erp-ref-value {
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.erp-edit-btn {
		background: #f59e0b;
		color: white;
		border: none;
		padding: 4px 6px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 12px;
		transition: background-color 0.2s;
	}

	.erp-edit-btn:hover {
		background: #d97706;
	}

	.erp-ref-empty {
		background: #fee2e2;
		color: #dc2626;
		border: 1px solid #fecaca;
		padding: 6px 10px;
		border-radius: 6px;
		cursor: pointer;
		font-size: 12px;
		font-weight: 500;
		transition: all 0.2s ease;
	}

	.erp-ref-empty:hover {
		background: #fca5a5;
		color: #991b1b;
	}

	/* ERP Popup Styles */
	.erp-popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
		backdrop-filter: blur(2px);
	}

	.erp-popup-modal {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
		overflow-y: auto;
		animation: popupSlideIn 0.3s ease;
	}

	@keyframes popupSlideIn {
		from {
			opacity: 0;
			transform: scale(0.9) translateY(-20px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	.erp-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.erp-popup-header h3 {
		margin: 0;
		color: #1f2937;
		font-size: 18px;
		font-weight: 600;
	}

	.erp-popup-close {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		transition: all 0.2s ease;
		line-height: 1;
	}

	.erp-popup-close:hover {
		color: #ef4444;
		background: rgba(239, 68, 68, 0.1);
	}

	.erp-popup-content {
		padding: 20px 24px;
	}

	.erp-popup-content p {
		margin: 0 0 12px 0;
		color: #4b5563;
		font-size: 14px;
	}

	.erp-input-group {
		margin: 16px 0;
	}

	.erp-input-group label {
		display: block;
		margin-bottom: 6px;
		font-weight: 500;
		color: #374151;
	}

	.erp-input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s ease;
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
		gap: 12px;
		justify-content: flex-end;
		margin-top: 20px;
	}

	.erp-cancel-btn,
	.erp-save-btn {
		padding: 10px 20px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		border: none;
	}

	.erp-cancel-btn {
		background: #f3f4f6;
		color: #374151;
	}

	.erp-cancel-btn:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.erp-save-btn {
		background: #3b82f6;
		color: white;
	}

	.erp-save-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.erp-save-btn:disabled,
	.erp-cancel-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
</style>