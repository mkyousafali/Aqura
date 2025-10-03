<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	let loading = true;
	let error = null;
	
	// Statistics data
	let stats = {
		byStatus: [],
		byType: [],
		byBranch: [],
		fineStats: {},
		trends: []
	};

	// Filter options
	let selectedDateRange = '30'; // days
	let selectedBranch = 'all';
	let branches = [];

	onMount(() => {
		loadBranches();
		loadStatistics();
	});

	async function loadBranches() {
		try {
			const { data, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en');

			if (branchError) throw branchError;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadStatistics() {
		try {
			loading = true;
			error = null;

			// Calculate date range
			const endDate = new Date();
			const startDate = new Date();
			startDate.setDate(startDate.getDate() - parseInt(selectedDateRange));

			let query = supabase
				.from('employee_warnings')
				.select(`
					*,
					branches!branch_id(name_en)
				`)
				.eq('is_deleted', false)
				.gte('issued_at', startDate.toISOString())
				.lte('issued_at', endDate.toISOString());

			if (selectedBranch !== 'all') {
				query = query.eq('branch_id', selectedBranch);
			}

			const { data: warnings, error: queryError } = await query;

			if (queryError) throw queryError;

			// Process statistics
			processStatistics(warnings || []);
		} catch (err) {
			console.error('Error loading statistics:', err);
			error = err.message;
		} finally {
			loading = false;
		}
	}

	function processStatistics(warnings) {
		// Status statistics
		const statusCounts = {};
		warnings.forEach(w => {
			statusCounts[w.warning_status] = (statusCounts[w.warning_status] || 0) + 1;
		});

		stats.byStatus = Object.entries(statusCounts).map(([status, count]) => ({
			status,
			count,
			percentage: ((count / warnings.length) * 100).toFixed(1)
		}));

		// Type statistics
		const typeCounts = {};
		warnings.forEach(w => {
			typeCounts[w.warning_type] = (typeCounts[w.warning_type] || 0) + 1;
		});

		stats.byType = Object.entries(typeCounts).map(([type, count]) => ({
			type: formatWarningType(type),
			count,
			percentage: ((count / warnings.length) * 100).toFixed(1)
		}));

		// Branch statistics
		const branchCounts = {};
		warnings.forEach(w => {
			const branchName = w.branches?.name_en || 'Unknown';
			branchCounts[branchName] = (branchCounts[branchName] || 0) + 1;
		});

		stats.byBranch = Object.entries(branchCounts).map(([branch, count]) => ({
			branch,
			count,
			percentage: ((count / warnings.length) * 100).toFixed(1)
		}));

		// Fine statistics
		const fineWarnings = warnings.filter(w => w.has_fine);
		const totalFineAmount = fineWarnings.reduce((sum, w) => sum + (parseFloat(w.fine_amount) || 0), 0);
		const paidFines = fineWarnings.filter(w => w.fine_status === 'paid');
		const paidAmount = paidFines.reduce((sum, w) => sum + (parseFloat(w.fine_amount) || 0), 0);

		stats.fineStats = {
			totalFines: fineWarnings.length,
			totalAmount: totalFineAmount,
			paidFines: paidFines.length,
			paidAmount: paidAmount,
			pendingFines: fineWarnings.filter(w => w.fine_status === 'pending').length,
			pendingAmount: totalFineAmount - paidAmount,
			collectionRate: fineWarnings.length > 0 ? ((paidFines.length / fineWarnings.length) * 100).toFixed(1) : 0
		};

		// Trends (simplified - just count by day for the last 7 days)
		const last7Days = [];
		for (let i = 6; i >= 0; i--) {
			const date = new Date();
			date.setDate(date.getDate() - i);
			const dateStr = date.toISOString().split('T')[0];
			
			const dayWarnings = warnings.filter(w => 
				w.issued_at.split('T')[0] === dateStr
			);

			last7Days.push({
				date: dateStr,
				count: dayWarnings.length,
				fines: dayWarnings.filter(w => w.has_fine).length
			});
		}

		stats.trends = last7Days;
	}

	function formatWarningType(type) {
		const typeMap = {
			'overall_performance_no_fine': 'Performance Warning',
			'overall_performance_fine_threat': 'Performance + Fine Threat',
			'overall_performance_with_fine': 'Performance + Fine'
		};
		return typeMap[type] || type;
	}

	function getStatusColor(status) {
		const colorMap = {
			'active': 'text-yellow-600 bg-yellow-100',
			'acknowledged': 'text-blue-600 bg-blue-100',
			'resolved': 'text-green-600 bg-green-100',
			'escalated': 'text-red-600 bg-red-100',
			'cancelled': 'text-gray-600 bg-gray-100'
		};
		return colorMap[status] || colorMap.active;
	}

	function handleFilterChange() {
		loadStatistics();
	}

	function exportReport() {
		// Simple CSV export functionality
		const csvData = [
			['Status', 'Count', 'Percentage'],
			...stats.byStatus.map(item => [item.status, item.count, item.percentage + '%'])
		];

		const csvString = csvData.map(row => row.join(',')).join('\n');
		const blob = new Blob([csvString], { type: 'text/csv' });
		const url = window.URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `warning-statistics-${new Date().toISOString().split('T')[0]}.csv`;
		a.click();
		window.URL.revokeObjectURL(url);
	}
</script>

<div class="warning-statistics">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">Warning Statistics & Reports</h1>
			<p class="subtitle">Analyze warning trends and generate reports</p>
		</div>
		<div class="header-actions">
			<button on:click={exportReport} class="export-btn">
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
				</svg>
				Export Report
			</button>
			<button on:click={loadStatistics} class="refresh-btn" disabled={loading}>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
				</svg>
				Refresh
			</button>
		</div>
	</div>

	<!-- Filters -->
	<div class="filters">
		<select bind:value={selectedDateRange} on:change={handleFilterChange} class="filter-select">
			<option value="7">Last 7 days</option>
			<option value="30">Last 30 days</option>
			<option value="90">Last 3 months</option>
			<option value="365">Last year</option>
		</select>

		<select bind:value={selectedBranch} on:change={handleFilterChange} class="filter-select">
			<option value="all">All Branches</option>
			{#each branches as branch}
				<option value={branch.id}>{branch.name_en}</option>
			{/each}
		</select>
	</div>

	{#if error}
		<div class="error-message">
			Error: {error}
		</div>
	{/if}

	{#if loading}
		<div class="loading-section">
			<div class="loading-spinner"></div>
			<p>Loading statistics...</p>
		</div>
	{:else}
		<!-- Statistics Grid -->
		<div class="stats-grid">
			<!-- Status Statistics -->
			<div class="stat-card">
				<h3 class="card-title">
					<span class="icon">📊</span>
					Warnings by Status
				</h3>
				<div class="stat-list">
					{#each stats.byStatus as item}
						<div class="stat-item">
							<span class="badge {getStatusColor(item.status)}">
								{item.status}
							</span>
							<div class="stat-values">
								<span class="count">{item.count}</span>
								<span class="percentage">({item.percentage}%)</span>
							</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- Type Statistics -->
			<div class="stat-card">
				<h3 class="card-title">
					<span class="icon">📋</span>
					Warnings by Type
				</h3>
				<div class="stat-list">
					{#each stats.byType as item}
						<div class="stat-item">
							<span class="type-label">{item.type}</span>
							<div class="stat-values">
								<span class="count">{item.count}</span>
								<span class="percentage">({item.percentage}%)</span>
							</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- Branch Statistics -->
			<div class="stat-card">
				<h3 class="card-title">
					<span class="icon">🏢</span>
					Warnings by Branch
				</h3>
				<div class="stat-list">
					{#each stats.byBranch as item}
						<div class="stat-item">
							<span class="branch-label">{item.branch}</span>
							<div class="stat-values">
								<span class="count">{item.count}</span>
								<span class="percentage">({item.percentage}%)</span>
							</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- Fine Statistics -->
			<div class="stat-card">
				<h3 class="card-title">
					<span class="icon">💰</span>
					Fine Statistics
				</h3>
				<div class="fine-stats">
					<div class="fine-row">
						<span class="label">Total Fines:</span>
						<span class="value">{stats.fineStats.totalFines}</span>
					</div>
					<div class="fine-row">
						<span class="label">Total Amount:</span>
						<span class="value">{stats.fineStats.totalAmount?.toFixed(2) || '0.00'}</span>
					</div>
					<div class="fine-row">
						<span class="label">Paid:</span>
						<span class="value text-green-600">{stats.fineStats.paidFines} ({stats.fineStats.paidAmount?.toFixed(2) || '0.00'})</span>
					</div>
					<div class="fine-row">
						<span class="label">Pending:</span>
						<span class="value text-red-600">{stats.fineStats.pendingFines} ({stats.fineStats.pendingAmount?.toFixed(2) || '0.00'})</span>
					</div>
					<div class="fine-row">
						<span class="label">Collection Rate:</span>
						<span class="value font-bold">{stats.fineStats.collectionRate}%</span>
					</div>
				</div>
			</div>
		</div>

		<!-- Trends Chart -->
		<div class="trends-section">
			<h3 class="section-title">
				<span class="icon">📈</span>
				7-Day Trend
			</h3>
			<div class="trend-chart">
				{#each stats.trends as day, index}
					<div class="trend-bar">
						<div class="bar-container">
							<div 
								class="bar warnings-bar" 
								style="height: {day.count > 0 ? Math.max(day.count * 20, 10) : 0}px"
								title="{day.count} warnings"
							></div>
							<div 
								class="bar fines-bar" 
								style="height: {day.fines > 0 ? Math.max(day.fines * 20, 5) : 0}px"
								title="{day.fines} fines"
							></div>
						</div>
						<div class="day-label">
							{new Date(day.date).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric' })}
						</div>
						<div class="day-values">
							<span class="warnings-count">{day.count}</span>
							<span class="fines-count">{day.fines}</span>
						</div>
					</div>
				{/each}
			</div>
			<div class="chart-legend">
				<div class="legend-item">
					<div class="legend-color warnings-color"></div>
					<span>Warnings</span>
				</div>
				<div class="legend-item">
					<div class="legend-color fines-color"></div>
					<span>Fines</span>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.warning-statistics {
		padding: 24px;
		background: white;
		height: 100%;
		overflow-y: auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.subtitle {
		font-size: 14px;
		color: #6b7280;
		margin: 4px 0 0 0;
	}

	.header-actions {
		display: flex;
		gap: 8px;
	}

	.export-btn, .refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.export-btn {
		background: #10b981;
		color: white;
	}

	.export-btn:hover {
		background: #059669;
	}

	.refresh-btn {
		background: #3b82f6;
		color: white;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.filters {
		display: flex;
		gap: 16px;
		margin-bottom: 24px;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 16px;
		border-radius: 8px;
		margin-bottom: 24px;
	}

	.loading-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		color: #6b7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 24px;
		margin-bottom: 32px;
	}

	.stat-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
	}

	.card-title {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}

	.icon {
		font-size: 20px;
	}

	.stat-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.stat-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.stat-item:last-child {
		border-bottom: none;
	}

	.badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
		text-transform: capitalize;
	}

	.type-label, .branch-label {
		font-weight: 500;
		color: #374151;
	}

	.stat-values {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.count {
		font-weight: 600;
		color: #111827;
	}

	.percentage {
		font-size: 12px;
		color: #6b7280;
	}

	.fine-stats {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.fine-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.fine-row:last-child {
		border-bottom: none;
		font-weight: 600;
	}

	.label {
		color: #374151;
	}

	.value {
		font-weight: 500;
		color: #111827;
	}

	.trends-section {
		background: #f8fafc;
		border-radius: 12px;
		padding: 24px;
	}

	.section-title {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
	}

	.trend-chart {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		height: 200px;
		margin-bottom: 16px;
		padding: 0 8px;
	}

	.trend-bar {
		display: flex;
		flex-direction: column;
		align-items: center;
		flex: 1;
		max-width: 60px;
	}

	.bar-container {
		display: flex;
		align-items: flex-end;
		justify-content: center;
		gap: 2px;
		height: 150px;
		margin-bottom: 8px;
	}

	.bar {
		width: 12px;
		border-radius: 2px 2px 0 0;
		transition: all 0.3s ease;
	}

	.warnings-bar {
		background: #3b82f6;
	}

	.fines-bar {
		background: #ef4444;
	}

	.day-label {
		font-size: 12px;
		color: #6b7280;
		margin-bottom: 4px;
		text-align: center;
	}

	.day-values {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
	}

	.warnings-count, .fines-count {
		font-size: 10px;
		font-weight: 500;
		padding: 1px 4px;
		border-radius: 2px;
	}

	.warnings-count {
		background: #dbeafe;
		color: #1d4ed8;
	}

	.fines-count {
		background: #fecaca;
		color: #dc2626;
	}

	.chart-legend {
		display: flex;
		justify-content: center;
		gap: 24px;
	}

	.legend-item {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
		color: #374151;
	}

	.legend-color {
		width: 12px;
		height: 12px;
		border-radius: 2px;
	}

	.warnings-color {
		background: #3b82f6;
	}

	.fines-color {
		background: #ef4444;
	}

	@media (max-width: 768px) {
		.stats-grid {
			grid-template-columns: 1fr;
		}
		
		.header {
			flex-direction: column;
			gap: 16px;
			align-items: flex-start;
		}
		
		.header-actions {
			align-self: flex-end;
		}
		
		.filters {
			flex-direction: column;
		}
	}
</style>