<script>
	import { t } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import * as XLSX from 'xlsx';

	let branches = [];
	let selectedBranch = '';
	let startDate = '';
	let endDate = '';
	let loading = false;
	let exporting = false;

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		loading = true;
		const { data, error } = await dataService.branches.getAll();
		if (!error && data) {
			branches = data;
		}
		loading = false;
	}

	async function handleExport() {
		if (!startDate || !endDate) {
			alert('Please select both start and end dates');
			return;
		}

		exporting = true;
		try {
			// Fetch data based on filters
			let result;
			if (selectedBranch) {
				// Fetch all data in range, then filter by branch in memory
				result = await dataService.hrFingerprint.getByDateRange(startDate, endDate);
				if (result.data) {
					result.data = result.data.filter(t => t.branch_id === selectedBranch);
				}
			} else {
				// Fetch all data in range
				result = await dataService.hrFingerprint.getByDateRange(startDate, endDate);
			}

			if (result.error || !result.data) {
				alert('Failed to fetch data: ' + (result.error || 'No data found'));
				return;
			}

			// Fetch employees and branches for lookup
			const employeesResult = await dataService.hrEmployees.getAll();
			const branchesResult = await dataService.branches.getAll();
			const positionsResult = await dataService.hrAssignments.getAll();

			const employeeMap = new Map();
			const branchMap = new Map();
			const positionMap = new Map();

			if (employeesResult.data) {
				employeesResult.data.forEach(emp => {
					const compositeKey = `${emp.employee_id}_${emp.branch_id}`;
					employeeMap.set(compositeKey, emp);
				});
			}

			if (branchesResult.data) {
				branchesResult.data.forEach(branch => {
					branchMap.set(branch.id, branch);
				});
			}

			if (positionsResult.data) {
				positionsResult.data.forEach(assignment => {
					if (assignment.employee_id && assignment.position) {
						positionMap.set(assignment.employee_id, assignment.position.position_title_en || 'N/A');
					}
				});
			}

			// Format data for Excel
			const excelData = result.data
				.sort((a, b) => {
					// Sort by employee_id first
					const idCompare = String(a.employee_id).localeCompare(String(b.employee_id));
					if (idCompare !== 0) return idCompare;
					// Then by date
					const dateCompare = a.date.localeCompare(b.date);
					if (dateCompare !== 0) return dateCompare;
					// Then by time
					return a.time.localeCompare(b.time);
				})
				.map(transaction => {
					const compositeKey = `${transaction.employee_id}_${transaction.branch_id}`;
					const employee = employeeMap.get(compositeKey);
					const branch = branchMap.get(transaction.branch_id);
					const position = employee ? positionMap.get(employee.id) : 'N/A';

					return {
						'Employee ID': transaction.employee_id,
						'First Name': employee?.name || '—',
						'Department': position || '—',
						'Date': formatDate(transaction.date),
						'Time': formatTime(transaction.time, transaction.date),
						'Punch State': transaction.status
					};
				});

			// Create workbook and worksheet
			const ws = XLSX.utils.json_to_sheet(excelData);
			const wb = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(wb, ws, 'Biometric Data');

			// Generate filename
			const filename = `Biometric_Data_${startDate}_to_${endDate}.xlsx`;

			// Download file
			XLSX.writeFile(wb, filename);

		} catch (error) {
			console.error('Export error:', error);
			alert('Failed to export data: ' + error.message);
		} finally {
			exporting = false;
		}
	}

	function formatDate(dateString) {
		// Keep date in YYYY-MM-DD format
		return dateString;
	}

	function formatTime(timeString, dateString = null) {
		// timeString is in HH:MM:SS format - display as stored
		const [hours, minutes] = timeString.split(':');
		let hour = parseInt(hours);
		
		// Convert to 12-hour format
		const ampm = hour >= 12 ? 'PM' : 'AM';
		const displayHour = hour % 12 || 12;
		return `${String(displayHour).padStart(2, '0')}:${minutes} ${ampm}`;
	}
</script>

<div class="biometric-export">
	<div class="content">
		<div class="export-container">
			<!-- Left Section: Filters -->
			<div class="filter-section">
				<h3 class="section-title">{t('hr.filters')}</h3>
				
				<div class="filter-group">
					<label class="filter-label">{t('hr.branch')}</label>
					<select bind:value={selectedBranch} class="filter-select" disabled={loading}>
						<option value="">{t('branches.allBranches')}</option>
						{#each branches as branch}
							<option value={branch.id}>{branch.name_en}</option>
						{/each}
					</select>
				</div>

				<div class="filter-group">
					<label class="filter-label">{t('hr.startDate')}</label>
					<input type="date" bind:value={startDate} class="filter-input" />
				</div>

				<div class="filter-group">
					<label class="filter-label">{t('hr.endDate')}</label>
					<input type="date" bind:value={endDate} class="filter-input" />
				</div>
			</div>

			<!-- Right Section: Export -->
			<div class="export-section">
				<h3 class="section-title">{t('hr.exportToExcel')}</h3>
				
				<div class="export-info">
					<p class="info-text">{t('hr.exportInfo')}</p>
					<ul class="header-list">
						<li>Employee ID</li>
						<li>First Name</li>
						<li>Department</li>
						<li>Date</li>
						<li>Time</li>
						<li>Punch State</li>
					</ul>
				</div>

				<button 
					class="export-btn" 
					on:click={handleExport}
					disabled={exporting || !startDate || !endDate}
				>
					{#if exporting}
						<span class="spinner"></span>
						{t('hr.exporting')}
					{:else}
						📊 {t('hr.exportData')}
					{/if}
				</button>
			</div>
		</div>
	</div>
</div>

<style>
	.biometric-export {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: linear-gradient(135deg, #f9fafb 0%, #f3f4f6 100%);
	}

	.content {
		flex: 1;
		padding: 24px;
		overflow-y: auto;
	}

	.export-container {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 24px;
		max-width: 1200px;
		margin: 0 auto;
	}

	.filter-section,
	.export-section {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.section-title {
		font-size: 18px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 20px 0;
		padding-bottom: 12px;
		border-bottom: 2px solid #e5e7eb;
	}

	.filter-group {
		margin-bottom: 20px;
	}

	.filter-label {
		display: block;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin-bottom: 8px;
	}

	.filter-select,
	.filter-input {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		font-family: inherit;
		color: #111827;
		background: white;
		transition: all 0.2s;
	}

	.filter-select:hover,
	.filter-input:hover {
		border-color: #9ca3af;
	}

	.filter-select:focus,
	.filter-input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.filter-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.export-info {
		margin-bottom: 24px;
	}

	.info-text {
		font-size: 14px;
		color: #6b7280;
		margin: 0 0 16px 0;
		line-height: 1.6;
	}

	.header-list {
		list-style: none;
		padding: 0;
		margin: 0;
		background: #f9fafb;
		border-radius: 8px;
		padding: 16px;
	}

	.header-list li {
		padding: 8px 12px;
		font-size: 13px;
		font-weight: 500;
		color: #374151;
		border-left: 3px solid #10b981;
		margin-bottom: 8px;
		background: white;
		border-radius: 4px;
	}

	.header-list li:last-child {
		margin-bottom: 0;
	}

	.export-btn {
		width: 100%;
		padding: 14px 24px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.export-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
	}

	.export-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.export-btn:disabled {
		background: #d1d5db;
		cursor: not-allowed;
		opacity: 0.6;
		transform: none;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@media (max-width: 768px) {
		.export-container {
			grid-template-columns: 1fr;
		}
	}
</style>
