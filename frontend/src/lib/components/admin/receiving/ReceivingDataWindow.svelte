<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';

	export let windowId;
	export let dataType; // 'bills', 'tasks', 'completed', 'incomplete', 'no-original', 'no-erp'
	export let title;

	let data = [];
	let filteredData = [];
	let searchQuery = '';
	let loading = true;
	let error = null;
	let uploadingBillId = null;
	let sortBy = '';
	let sortOrder = 'asc';

	// Column configurations for different data types
	const columnConfigs = {
		bills: [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
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
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Received At', sortable: true, type: 'date' },
			{ key: 'upload_action', label: 'Upload', sortable: false, type: 'action' }
		],
		'no-pr-excel': [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Received At', sortable: true, type: 'date' },
			{ key: 'upload_action', label: 'Upload PR Excel', sortable: false, type: 'action' }
		],
		'no-erp': [
			{ key: 'bill_number', label: 'Bill Number', sortable: true },
			{ key: 'vendor_name', label: 'Vendor', sortable: true },
			{ key: 'vendor_id', label: 'ERP Vendor ID', sortable: true },
			{ key: 'bill_date', label: 'Bill Date', sortable: true, type: 'date' },
			{ key: 'bill_amount', label: 'Amount', sortable: true, type: 'currency' },
			{ key: 'created_at', label: 'Received At', sortable: true, type: 'date' }
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
						`)
						.order('created_at', { ascending: false });
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
						.or('original_bill_url.is.null,original_bill_url.eq.')
						.order('created_at', { ascending: false });
					break;
					
				case 'no-erp':
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
						.or('erp_purchase_invoice_reference.is.null,erp_purchase_invoice_reference.eq.')
						.order('created_at', { ascending: false });
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
						.or('pr_excel_file_url.is.null,pr_excel_file_url.eq.')
						.order('created_at', { ascending: false });
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

	function closeWindow() {
		windowManager.closeWindow(windowId);
	}

	onMount(() => {
		loadData();
	});
</script>

<div class="receiving-data-window">
	<div class="window-header">
		<h2>{title}</h2>
		<button class="close-btn" on:click={closeWindow}>✕</button>
	</div>

	<div class="window-controls">
		<div class="search-container">
			<input
				type="text"
				placeholder="Search..."
				bind:value={searchQuery}
				class="search-input"
			/>
			<span class="search-icon">🔍</span>
		</div>
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
		padding: 16px 20px;
		border-bottom: 1px solid #e2e8f0;
		background: white;
	}

	.search-container {
		position: relative;
		flex: 1;
		max-width: 400px;
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
</style>