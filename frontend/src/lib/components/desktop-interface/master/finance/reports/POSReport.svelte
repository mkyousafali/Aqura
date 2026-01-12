<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import * as XLSX from 'xlsx';

	let isLoading = false;
	let reportData = [];
	let reportType = null;
	let error = null;
	let branchFilter = '';
	let cashierFilter = '';
	let fromDate = '';
	let toDate = '';
	let amountFilterType = ''; // 'less', 'more', 'exact'
	let amountFilterValue = '';

	$: filteredData = filterData(reportData, branchFilter, cashierFilter, fromDate, toDate, amountFilterType, amountFilterValue);
	$: totalDifference = filteredData.reduce((sum, item) => sum + item.difference, 0);
	$: recordCount = filteredData.length;
	$: groupedByCashier = groupDataByCashier(filteredData);

	function groupDataByCashier(data) {
		const grouped = {};
		
		// Sort by cashier name first
		const sorted = [...data].sort((a, b) => a.cashierName.localeCompare(b.cashierName));
		
		sorted.forEach(item => {
			if (!grouped[item.cashierName]) {
				grouped[item.cashierName] = [];
			}
			grouped[item.cashierName].push(item);
		});

		return Object.entries(grouped).map(([cashierName, items]) => ({
			cashierName,
			items: items.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)),
			total: items.reduce((sum, item) => sum + item.difference, 0)
		}));
	}

	function filterData(data, branch, cashier, from, to, amountType, amountValue) {
		return data.filter((item) => {
			const branchMatch = !branch || item.branchName.toLowerCase().includes(branch.toLowerCase());
			const cashierMatch = !cashier || item.cashierName.toLowerCase().includes(cashier.toLowerCase());
			
			let dateMatch = true;
			if (from || to) {
				const itemDate = new Date(item.createdAt).getTime();
				const fromDateTime = from ? new Date(from).getTime() : 0;
				const toDateTime = to ? new Date(to).getTime() + 86400000 : Infinity; // Add 24h to include end date
				
				dateMatch = itemDate >= fromDateTime && itemDate <= toDateTime;
			}
			
			let amountMatch = true;
			if (amountType && amountValue) {
				const amount = Math.abs(parseFloat(amountValue)); // Always use absolute value
				if (!isNaN(amount)) {
					const absDifference = Math.abs(item.difference);
					if (amountType === 'less') {
						amountMatch = absDifference < amount;
					} else if (amountType === 'more') {
						amountMatch = absDifference > amount;
					} else if (amountType === 'exact') {
						amountMatch = Math.abs(absDifference - amount) < 0.01; // Allow for floating point precision
					}
				}
			}
			
			return branchMatch && cashierMatch && dateMatch && amountMatch;
		});
	}

	// Get unique branches for filter dropdown
	$: uniqueBranches = [...new Set(reportData.map(r => r.branchName))].sort();

	async function fetchReportData(type) {
		isLoading = true;
		error = null;
		reportType = type;
		reportData = [];
		branchFilter = '';
		cashierFilter = '';
		fromDate = '';
		toDate = '';
		amountFilterType = '';
		amountFilterValue = '';

		try {
			const { data, error: fetchError } = await supabase
				.from('box_operations')
				.select('id, box_number, complete_details, notes, status, total_difference, branch_id, user_id, created_at')
				.eq('status', 'completed')
				.order('created_at', { ascending: false });

			if (fetchError) throw fetchError;

			if (!data || data.length === 0) {
				reportData = [];
				return;
			}

			// Get unique branch IDs and user IDs
			const branchIds = [...new Set(data.map(r => r.branch_id))];
			const userIds = [...new Set(data.map(r => r.user_id))];

			// Fetch branch data
			const { data: branches, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.in('id', branchIds);

			if (branchError) throw branchError;

			// Fetch employee data
			const { data: employees, error: employeeError } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar')
				.in('user_id', userIds);

			if (employeeError) throw employeeError;

			// Create branch map with name and location
			const branchMap = {};
			if (branches) {
				branches.forEach(b => {
					branchMap[b.id] = {
						name: b.name_en || b.name_ar || 'N/A',
						location: b.location_en || b.location_ar || 'N/A'
					};
				});
			}

			// Create employee map for user_id to name (both EN and AR)
			const employeeMap = {};
			if (employees) {
				employees.forEach(e => {
					employeeMap[e.user_id] = {
						nameEn: e.name_en || 'N/A',
						nameAr: e.name_ar || 'N/A'
					};
				});
			}

			// Filter and process data
			const processed = data
				.map((record) => {
					let details = {};
					let notes = {};

					// Parse complete_details safely
					if (record.complete_details) {
						try {
							details = typeof record.complete_details === 'string' 
								? JSON.parse(record.complete_details) 
								: record.complete_details;
						} catch (e) {
							console.warn('Failed to parse complete_details:', e);
						}
					}

					// Parse notes safely
					if (record.notes) {
						try {
							notes = typeof record.notes === 'string'
								? JSON.parse(record.notes)
								: record.notes;
						} catch (e) {
							console.warn('Failed to parse notes:', e);
						}
					}

					const diff = details?.total_difference ?? record.total_difference ?? 0;

					// Get cashier name from employee map using user_id (both EN and AR)
					const cashierNameEn = employeeMap[record.user_id]?.nameEn || 'N/A';
					const cashierNameAr = employeeMap[record.user_id]?.nameAr || 'N/A';
					const cashierName = `${cashierNameEn} / ${cashierNameAr}`;

					// Get branch name and location from branch map using branch_id
					const branchName = branchMap[record.branch_id]?.name || 'N/A';
					const branchLocation = branchMap[record.branch_id]?.location || 'N/A';

					return {
						id: record.id,
						boxNumber: record.box_number,
						cashierName: cashierName,
						cashierNameEn: cashierNameEn,
						cashierNameAr: cashierNameAr,
						difference: parseFloat(diff),
						branchName: branchName,
						branchLocation: branchLocation,
						createdAt: record.created_at
					};
				})
				.filter((item) => {
					if (type === 'short') {
						return item.difference < 0;
					} else if (type === 'excess') {
						return item.difference > 0;
					}
					return true;
				});

			reportData = processed;
		} catch (err) {
			console.error('Error fetching report data:', err);
			error = err.message || 'Failed to load report data';
		} finally {
			isLoading = false;
		}
	}

	function formatCurrency(value) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2
		}).format(value);
	}

	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		const date = new Date(dateString);
		return date.toLocaleDateString('en-GB', { 
			year: 'numeric', 
			month: '2-digit', 
			day: '2-digit'
		});
	}

	function exportToExcel() {
		try {
			// Prepare data with cashier summaries for Excel
			const excelData = [];

			groupedByCashier.forEach((group) => {
				// Add all items for this cashier
				group.items.forEach((row) => {
					excelData.push({
						'Date': formatDate(row.createdAt),
						'Box Number': row.boxNumber,
						'Cashier Name (EN)': row.cashierNameEn,
						'Cashier Name (AR)': row.cashierNameAr,
						'Difference': row.difference,
						'Branch Name': row.branchName,
						'Branch Location': row.branchLocation
					});
				});

				// Add summary row for this cashier
				excelData.push({
					'Date': '',
					'Box Number': '',
					'Cashier Name (EN)': `Total for ${group.cashierNameEn || group.cashierName}`,
					'Cashier Name (AR)': '',
					'Difference': group.total,
					'Branch Name': '',
					'Branch Location': ''
				});

				// Add blank row for spacing
				excelData.push({
					'Date': '',
					'Box Number': '',
					'Cashier Name (EN)': '',
					'Cashier Name (AR)': '',
					'Difference': '',
					'Branch Name': '',
					'Branch Location': ''
				});
			});

			// Create workbook and worksheet
			const worksheet = XLSX.utils.json_to_sheet(excelData);
			const workbook = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(workbook, worksheet, reportType === 'short' ? 'Short Report' : 'Excess Report');

			// Style the columns
			const colWidths = [
				{ wch: 15 }, // Date
				{ wch: 12 }, // Box Number
				{ wch: 20 }, // Cashier Name EN
				{ wch: 20 }, // Cashier Name AR
				{ wch: 15 }, // Difference
				{ wch: 25 }, // Branch Name
				{ wch: 30 }  // Branch Location
			];
			worksheet['!cols'] = colWidths;

			// Generate filename with date
			const now = new Date();
			const dateStr = now.toISOString().split('T')[0];
			const filename = `POS_${reportType === 'short' ? 'Short' : 'Excess'}_Report_${dateStr}.xlsx`;

			// Download the file
			XLSX.writeFile(workbook, filename);
		} catch (err) {
			console.error('Error exporting to Excel:', err);
			error = 'Failed to export to Excel';
		}
	}

	onMount(() => {
		// Component ready
	});
</script>

<div class="pos-report-container">
	<div class="report-wrapper">
		<!-- Button Section -->
		<div class="button-section">
			<button
				class="report-btn short-btn"
				on:click={() => fetchReportData('short')}
				disabled={isLoading}
			>
				📉 Short Report
			</button>
			<button
				class="report-btn excess-btn"
				on:click={() => fetchReportData('excess')}
				disabled={isLoading}
			>
				📈 Excess Report
			</button>
		</div>

		<!-- Report Table Section -->
		{#if reportType}
			<div class="table-section">
				{#if isLoading}
					<div class="loading-message">Loading report data...</div>
				{:else if error}
					<div class="error-message">Error: {error}</div>
				{:else if reportData.length === 0}
					<div class="empty-message">
						No {reportType === 'short' ? 'shortage' : 'excess'} records found
					</div>
				{:else}
					<!-- Filter Section -->
					<div class="filter-section">
						<div class="filter-group">
							<label for="fromDate">From Date:</label>
							<input 
								id="fromDate"
								type="date" 
								bind:value={fromDate} 
								class="filter-input"
							/>
						</div>

						<div class="filter-group">
							<label for="toDate">To Date:</label>
							<input 
								id="toDate"
								type="date" 
								bind:value={toDate} 
								class="filter-input"
							/>
						</div>

						<div class="filter-group">
							<label for="branchFilter">Filter by Branch:</label>
							<select id="branchFilter" bind:value={branchFilter} class="filter-select">
								<option value="">All Branches</option>
								{#each uniqueBranches as branch}
									<option value={branch}>{branch}</option>
								{/each}
							</select>
						</div>

						<div class="filter-group">
							<label for="cashierFilter">Search Cashier Name:</label>
							<input 
								id="cashierFilter"
								type="text" 
								bind:value={cashierFilter} 
								placeholder="Enter cashier name..."
								class="filter-input"
							/>
						</div>
					<div class="filter-group amount-filter-group">
						<label for="amountFilterType">Filter by Amount:</label>
						<div class="amount-filter-container">
							<select id="amountFilterType" bind:value={amountFilterType} class="filter-select amount-select">
								<option value="">No Filter</option>
								<option value="less">Less Than</option>
								<option value="more">More Than</option>
								<option value="exact">Exact Amount</option>
							</select>
							{#if amountFilterType}
								<input 
									type="number" 
									bind:value={amountFilterValue}
									placeholder="Enter amount..."
									class="filter-input amount-input"
									step="0.01"
								/>
							{/if}
						</div>
					</div>

					<div class="filter-group export-group">
							<button 
								class="export-btn"
								on:click={exportToExcel}
								disabled={filteredData.length === 0}
								title="Export filtered data to Excel (sorted by cashier name)"
							>
								📥 Export to Excel
							</button>
						</div>
					</div>

					<div class="table-container">
						<table class="report-table">
							<thead>
								<tr>
									<th>Date</th>
									<th>Box Number</th>
									<th>Cashier Name (EN / AR)</th>
									<th>Difference</th>
									<th>Branch Name</th>
									<th>Branch Location</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredData as row (row.id)}
									<tr>
										<td>{formatDate(row.createdAt)}</td>
										<td>{row.boxNumber}</td>
										<td>
											<div class="cashier-names">
												<div class="name-en">{row.cashierNameEn}</div>
												<div class="name-ar">{row.cashierNameAr}</div>
											</div>
										</td>
										<td class={row.difference < 0 ? 'negative' : 'positive'}>
											{formatCurrency(row.difference)}
										</td>
										<td>{row.branchName}</td>
										<td>{row.branchLocation}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<div class="summary">
						<div class="summary-item">
							<span>Filtered Records:</span>
							<strong>{recordCount}</strong>
						</div>
						<div class="summary-item">
							<span>Total Difference:</span>
							<strong class={totalDifference < 0 ? 'negative' : 'positive'}>
								{formatCurrency(totalDifference)}
							</strong>
						</div>
					</div>
				{/if}
			</div>
		{:else}
			<div class="initial-message">
				<p>Select a report type to view data</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.pos-report-container {
		padding: 1.5rem;
		width: 100%;
		height: 100%;
		background-color: var(--background, #f8fafc);
		overflow-y: auto;
		display: flex;
		flex-direction: column;
	}

	.report-wrapper {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.button-section {
		display: flex;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.report-btn {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.short-btn {
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
	}

	.short-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 16px rgba(239, 68, 68, 0.3);
	}

	.excess-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
	}

	.excess-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 16px rgba(16, 185, 129, 0.3);
	}

	.report-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.table-section {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		min-height: 0;
	}

	.filter-section {
		background: white;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
		padding: 1rem;
		display: flex;
		gap: 1.5rem;
		flex-wrap: wrap;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex: 1;
		min-width: 200px;
	}

	.filter-group label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #333;
	}

	.filter-select,
	.filter-input {
		padding: 0.625rem 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		font-family: inherit;
		background: white;
	}

	.filter-select:focus,
	.filter-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.amount-filter-group {
		grid-column: 1 / -1;
	}

	.amount-filter-container {
		display: flex;
		gap: 0.75rem;
		align-items: center;
	}

	.amount-select {
		flex: 0 0 140px;
	}

	.amount-input {
		flex: 1;
		max-width: 150px;
	}

	.export-group {
		display: flex;
		align-items: flex-end;
	}

	.export-btn {
		padding: 0.625rem 1rem;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.export-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.export-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.loading-message,
	.error-message,
	.empty-message,
	.initial-message {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		background: white;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
		color: #666;
		font-size: 1rem;
		text-align: center;
	}

	.error-message {
		background: #fee;
		color: #c33;
		border-color: #fcc;
	}

	.table-container {
		flex: 1;
		background: white;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
		overflow: auto;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.report-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.9rem;
	}

	.report-table thead {
		background: #f3f4f6;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.report-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 2px solid #e5e7eb;
		white-space: nowrap;
	}

	.report-table td {
		padding: 0.875rem 1rem;
		border-bottom: 1px solid #e5e7eb;
		color: #333;
	}

	.report-table tbody tr:hover {
		background: #f9fafb;
	}

	.report-table tbody tr:last-child td {
		border-bottom: none;
	}

	.report-table td.negative {
		color: #dc2626;
		font-weight: 600;
	}

	.report-table td.positive {
		color: #059669;
		font-weight: 600;
	}

	.cashier-names {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.cashier-names .name-en {
		font-weight: 600;
		color: #333;
		font-size: 0.9rem;
	}

	.cashier-names .name-ar {
		font-size: 0.85rem;
		color: #666;
		direction: rtl;
	}

	.cashier-summary-row {
		background: #f0f9ff;
		border-top: 2px solid #0ea5e9;
		border-bottom: 2px solid #0ea5e9;
		font-weight: 600;
	}

	.cashier-summary-row:hover {
		background: #e0f2fe;
	}

	.cashier-summary-row .summary-label {
		padding: 0.875rem 1rem;
		color: #0369a1;
	}

	.cashier-summary-row strong {
		font-weight: 700;
		color: #0369a1;
	}

	.cashier-summary-row td.negative {
		color: #dc2626;
		font-weight: 700;
	}

	.cashier-summary-row td.positive {
		color: #059669;
		font-weight: 700;
	}

	.summary {
		padding: 1rem;
		background: #f3f4f6;
		border-radius: 8px;
		display: flex;
		gap: 2rem;
		flex-wrap: wrap;
		font-size: 0.9rem;
		color: #666;
	}

	.summary-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.summary-item span {
		color: #666;
	}

	.summary-item strong {
		color: #333;
		font-weight: 600;
	}

	.summary-item strong.negative {
		color: #dc2626;
	}

	.summary-item strong.positive {
		color: #059669;
	}
</style>
