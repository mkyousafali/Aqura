<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { realtimeService } from '$lib/utils/realtimeService';
	import StartReceiving from '$lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte';
	import ReceivingRecords from '$lib/components/desktop-interface/master/operations/receiving/ReceivingRecords.svelte';
	import ReceivingDataWindow from '$lib/components/desktop-interface/master/operations/receiving/ReceivingDataWindow.svelte';

	let totalReceivedBills = 0;
	let billsWithoutOriginal = 0;
	let billsWithoutErpReference = 0;
	let billsWithoutPrExcel = 0;
	let loading = true;

	// Branch filtering variables
	let branches = [];
	let selectedBranch = '';
	let branchFilterMode = 'all'; // 'all', 'branch'
	let loadingBranches = false;
	
	// Date filtering variables
	let dateFilterMode = 'all'; // 'all', 'today', 'yesterday', 'range'
	let dateFrom = '';
	let dateTo = '';
	
	// Real-time subscription unsubscribe function
	let unsubscribeReceivingRecords = null;
	
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

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Load branches for filtering
	async function loadBranches() {
		loadingBranches = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		} finally {
			loadingBranches = false;
		}
	}

	async function loadDashboardData() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			// Get total count of received bills (filtered by branch and date if selected)
			let billsQuery = supabase
				.from('receiving_records')
				.select('*', { count: 'exact', head: true });
			
			if (branchFilterMode === 'branch' && selectedBranch) {
				billsQuery = billsQuery.eq('branch_id', selectedBranch);
			}
			
			// Apply date filtering
			if (dateFilterMode === 'today') {
				const today = getToday();
				billsQuery = billsQuery.gte('created_at', `${today}T00:00:00`).lt('created_at', `${today}T23:59:59`);
			} else if (dateFilterMode === 'yesterday') {
				const yesterday = getYesterday();
				billsQuery = billsQuery.gte('created_at', `${yesterday}T00:00:00`).lt('created_at', `${yesterday}T23:59:59`);
			} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
				billsQuery = billsQuery.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
			}
			
			const { count: billsCount, error: billsError } = await billsQuery;

			if (billsError) {
				console.error('Error loading bills count:', billsError);
				totalReceivedBills = 0;
			} else {
				totalReceivedBills = billsCount || 0;
			}

			// Get count of bills without original bill uploaded (with branch and date filter)
			let noOriginalQuery = supabase
				.from('receiving_records')
				.select('*', { count: 'exact', head: true })
				.or('original_bill_url.is.null,original_bill_url.eq.');
			
			if (branchFilterMode === 'branch' && selectedBranch) {
				noOriginalQuery = noOriginalQuery.eq('branch_id', selectedBranch);
			}
			
			// Apply date filtering
			if (dateFilterMode === 'today') {
				const today = getToday();
				noOriginalQuery = noOriginalQuery.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
			} else if (dateFilterMode === 'yesterday') {
				const yesterday = getYesterday();
				noOriginalQuery = noOriginalQuery.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
			} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
				noOriginalQuery = noOriginalQuery.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
			}
			
			const { count: noOriginalCount, error: noOriginalError } = await noOriginalQuery;
			
			if (noOriginalError) {
				console.error('Error loading bills without original count:', noOriginalError);
				billsWithoutOriginal = 0;
			} else {
				billsWithoutOriginal = noOriginalCount || 0;
			}

			// Get count of bills without ERP purchase invoice reference (with branch and date filter)
			let noErpQuery = supabase
				.from('receiving_records')
				.select('*', { count: 'exact', head: true })
				.or('erp_purchase_invoice_reference.is.null,erp_purchase_invoice_reference.eq.');
			
			if (branchFilterMode === 'branch' && selectedBranch) {
				noErpQuery = noErpQuery.eq('branch_id', selectedBranch);
			}
			
			// Apply date filtering
			if (dateFilterMode === 'today') {
				const today = getToday();
				noErpQuery = noErpQuery.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
			} else if (dateFilterMode === 'yesterday') {
				const yesterday = getYesterday();
				noErpQuery = noErpQuery.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
			} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
				noErpQuery = noErpQuery.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
			}
			
			const { count: noErpCount, error: noErpError } = await noErpQuery;
			
			if (noErpError) {
				console.error('Error loading bills without ERP reference count:', noErpError);
				billsWithoutErpReference = 0;
			} else {
				billsWithoutErpReference = noErpCount || 0;
			}

			// Get count of bills without PR Excel uploaded (with branch and date filter)
			let noPrExcelQuery = supabase
				.from('receiving_records')
				.select('*', { count: 'exact', head: true })
				.or('pr_excel_file_url.is.null,pr_excel_file_url.eq.');
			
			if (branchFilterMode === 'branch' && selectedBranch) {
				noPrExcelQuery = noPrExcelQuery.eq('branch_id', selectedBranch);
			}
			
			// Apply date filtering
			if (dateFilterMode === 'today') {
				const today = getToday();
				noPrExcelQuery = noPrExcelQuery.gte('created_at', `${today}T00:00:00`).lte('created_at', `${today}T23:59:59`);
			} else if (dateFilterMode === 'yesterday') {
				const yesterday = getYesterday();
				noPrExcelQuery = noPrExcelQuery.gte('created_at', `${yesterday}T00:00:00`).lte('created_at', `${yesterday}T23:59:59`);
			} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
				noPrExcelQuery = noPrExcelQuery.gte('created_at', `${dateFrom}T00:00:00`).lte('created_at', `${dateTo}T23:59:59`);
			}
			
			const { count: noPrExcelCount, error: noPrExcelError } = await noPrExcelQuery;
			
			if (noPrExcelError) {
				console.error('Error loading bills without PR Excel count:', noPrExcelError);
				billsWithoutPrExcel = 0;
			} else {
				billsWithoutPrExcel = noPrExcelCount || 0;
			}
		} catch (err) {
			console.error('Error in loadDashboardData:', err);
			totalReceivedBills = 0;
			billsWithoutOriginal = 0;
			billsWithoutErpReference = 0;
			billsWithoutPrExcel = 0;
		} finally {
			loading = false;
		}
	}

	onMount(async () => {
		await loadBranches();
		await loadDashboardData();
		setupRealtimeSubscriptions();

		return () => {
			if (unsubscribeReceivingRecords) {
				unsubscribeReceivingRecords();
			}
		};
	});

	async function setupRealtimeSubscriptions() {
		try {
			console.log('📡 Setting up real-time subscriptions for Receiving dashboard...');

			// Subscribe to receiving_records changes
			unsubscribeReceivingRecords = realtimeService.subscribeToReceivingRecordsChanges(
				async (payload) => {
					console.log('🔔 Real-time receiving record update:', {
						event: payload.eventType,
						recordId: payload.new?.id || payload.old?.id
					});

					// Reload dashboard data on any change
					await loadDashboardData();
				}
			);

			console.log('✅ Real-time subscriptions setup complete');
		} catch (error) {
			console.error('Error setting up real-time subscriptions:', error);
		}
	}

	// Reactive statements for branch filter changes
	$: if (branchFilterMode === 'all') {
		selectedBranch = '';
		loadDashboardData();
	} else if (branchFilterMode === 'branch' && selectedBranch) {
		loadDashboardData();
	} else if (branchFilterMode === 'branch' && !selectedBranch) {
		// Reset data when branch mode is selected but no branch is chosen
		totalReceivedBills = 0;
		billsWithoutOriginal = 0;
		billsWithoutErpReference = 0;
		billsWithoutPrExcel = 0;
	}
	
	// Reactive statements for date filter changes
	$: if (dateFilterMode === 'all') {
		dateFrom = '';
		dateTo = '';
		loadDashboardData();
	} else if (dateFilterMode === 'today') {
		dateFrom = '';
		dateTo = '';
		loadDashboardData();
	} else if (dateFilterMode === 'yesterday') {
		dateFrom = '';
		dateTo = '';
		loadDashboardData();
	} else if (dateFilterMode === 'range' && dateFrom && dateTo) {
		loadDashboardData();
	} else if (dateFilterMode === 'range' && (!dateFrom || !dateTo)) {
		// Reset data when range mode is selected but dates are not chosen
		totalReceivedBills = 0;
		billsWithoutOriginal = 0;
		billsWithoutErpReference = 0;
		billsWithoutPrExcel = 0;
	}

	// Refresh function to reload dashboard data
	async function refreshDashboard() {
		loading = true;
		await loadDashboardData();
	}

	// Dashboard cards with dynamic data
	$: dashboardCards = [
		{
			id: 'card1',
			title: 'Total Received Bills',
			description: loading ? 'Loading...' : `${totalReceivedBills} bills received`,
			icon: '📊',
			color: 'blue',
			count: totalReceivedBills,
			dataType: 'bills',
			clickable: true
		},
		{
			id: 'card5',
			title: 'Original Bills Upload Pending',
			description: loading ? 'Loading...' : `${billsWithoutOriginal} bills pending upload`,
			icon: '📄',
			color: 'orange',
			count: billsWithoutOriginal,
			dataType: 'no-original',
			clickable: true
		},
		{
			id: 'card7',
			title: 'PR Excel Upload Pending',
			description: loading ? 'Loading...' : `${billsWithoutPrExcel} bills pending PR Excel upload`,
			icon: '📊',
			color: 'cyan',
			count: billsWithoutPrExcel,
			dataType: 'no-pr-excel',
			clickable: true
		},
		{
			id: 'card6',
			title: 'Bills Not Entered to ERP',
			description: loading ? 'Loading...' : `${billsWithoutErpReference} bills not entered to ERP`,
			icon: '🔗',
			color: 'teal',
			count: billsWithoutErpReference,
			dataType: 'no-erp',
			clickable: true
		}
	];

	function openStartReceiving() {
		const windowId = generateWindowId('start-receiving');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		openWindow({
			id: windowId,
			title: `Start Receiving #${instanceNumber}`,
			component: StartReceiving,
			icon: '📦',
			size: { width: 1200, height: 800 },
			position: { 
				x: 100 + (Math.random() * 100),
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function openReceivingRecords() {
		const windowId = generateWindowId('receiving-records');
		
		openWindow({
			id: windowId,
			title: 'Receiving Records',
			component: ReceivingRecords,
			icon: '📋',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100),
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openCardData(card) {
		if (!card.clickable || card.count === 0) return;
		
		const windowId = generateWindowId('receiving-data');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		// Create a component ref to call its refresh method
		let componentInstance;
		
		openWindow({
			id: windowId,
			title: `${card.title} - Details #${instanceNumber}`,
			component: ReceivingDataWindow,
			props: {
				dataType: card.dataType,
				title: card.title,
				// Pass current filter settings to the detail window
				initialBranchFilter: branchFilterMode,
				initialSelectedBranch: selectedBranch,
				initialDateFilter: dateFilterMode,
				initialDateFrom: dateFrom,
				initialDateTo: dateTo,
				// Bind component instance
				bind: (instance) => {
					componentInstance = instance;
				},
				// Refresh handler that calls component's onRefresh
				onRefresh: () => {
					console.log('🔄 Refresh button clicked in window manager');
					if (componentInstance && componentInstance.onRefresh) {
						return componentInstance.onRefresh();
					}
				}
			},
			icon: card.icon,
			size: { width: 1200, height: 800 },
			position: { 
				x: Math.floor(Math.random() * 200) + 100, 
				y: Math.floor(Math.random() * 100) + 50 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			refreshable: true
		});
	}
</script>

<!-- Receiving Dashboard -->
<div class="receiving-window">
	<!-- Branch Filter Section -->
	<div class="filter-section">
		<div class="filter-controls">
			<div class="filter-options">
				<label class="filter-option">
					<input 
						type="radio" 
						bind:group={branchFilterMode}
						value="all"
					/>
					<span class="option-text">All Branches</span>
				</label>
				
				<label class="filter-option">
					<input 
						type="radio" 
						bind:group={branchFilterMode}
						value="branch"
					/>
					<span class="option-text">Filter by Branch</span>
				</label>
			</div>

			{#if branchFilterMode === 'branch'}
				<div class="branch-selector">
					<select bind:value={selectedBranch} class="branch-select">
						<option value="">-- Select a branch --</option>
						{#each branches as branch}
							<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
						{/each}
					</select>
				</div>
			{/if}
		</div>
	</div>

	<!-- Top Dashboard Section with 5 Placeholders -->
	<div class="dashboard-section">
		<h2 class="section-title">Dashboard Overview</h2>
		<div class="dashboard-grid">
			{#each dashboardCards as card}
				<div 
					class="dashboard-card {card.color} {card.clickable ? 'clickable' : ''}"
					on:click={() => openCardData(card)}
					role="button"
					tabindex="0"
					on:keydown={(e) => e.key === 'Enter' && openCardData(card)}
				>
					<div class="card-icon">
						<span class="icon">{card.icon}</span>
					</div>
					<div class="card-content">
						<h3 class="card-title">{card.title}</h3>
						{#if card.count !== undefined}
							<div class="card-count">{loading ? '...' : card.count}</div>
						{/if}
						<p class="card-description">{card.description}</p>
					</div>
					{#if card.clickable}
						<div class="click-indicator">Click to view details</div>
					{/if}
				</div>
			{/each}
		</div>
	</div>

	<!-- Start Receiving Button Section -->
	<div class="action-section">
		<button class="start-receiving-btn" on:click={openStartReceiving}>
			<span class="btn-icon">🚀</span>
			<span class="btn-text">Start Receiving</span>
		</button>
		
		<button class="receiving-records-btn" on:click={openReceivingRecords}>
			<span class="btn-icon">📋</span>
			<span class="btn-text">Receiving Records</span>
		</button>
	</div>
</div>

<style>
	.receiving-window {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	/* Filter Section Styles */
	.filter-section {
		margin-bottom: 2rem;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
	}

	.branch-filter h4 {
		margin: 0 0 1rem 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.filter-controls {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.filter-options {
		display: flex;
		gap: 2rem;
		flex-wrap: wrap;
	}

	.filter-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: 500;
		color: #475569;
	}

	.filter-option input[type="radio"] {
		margin: 0;
		transform: scale(1.2);
	}

	.option-text {
		font-size: 0.95rem;
	}

	.branch-selector {
		margin-top: 0.5rem;
	}

	.branch-select {
		padding: 0.75rem 1rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 1rem;
		background: white;
		color: #1e293b;
		min-width: 300px;
		cursor: pointer;
	}

	.branch-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}
	
	.date-filter {
		margin-top: 1rem;
	}
	
	.date-range-selector {
		margin-top: 0.5rem;
		display: flex;
		gap: 1rem;
		flex-wrap: wrap;
	}
	
	.date-input-group {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}
	
	.date-label {
		font-size: 0.875rem;
		color: #475569;
		font-weight: 500;
	}
	
	.date-input {
		padding: 0.5rem 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		color: #1e293b;
		cursor: pointer;
	}
	
	.date-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.loading-state {
		padding: 0.75rem 1rem;
		color: #64748b;
		font-style: italic;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
	}

	.header {
		margin-bottom: 32px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.title-section {
		text-align: left;
	}

	.header-actions {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.refresh-btn {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 12px;
		padding: 12px 20px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		gap: 8px;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
		min-height: 44px;
	}

	.refresh-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
	}

	.refresh-btn:active:not(:disabled) {
		transform: translateY(0);
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.refresh-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
		transform: none;
	}

	.refresh-icon {
		font-size: 16px;
		transition: transform 0.3s ease;
		display: inline-block;
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

	.refresh-text {
		font-size: 14px;
		white-space: nowrap;
	}

	.title-section .title {
		font-size: 32px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.title-section .subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.dashboard-section {
		margin-bottom: 40px;
	}

	.section-title {
		font-size: 24px;
		font-weight: 600;
		color: #1f2937;
		margin: 0 0 24px 0;
		text-align: center;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 20px;
		margin-bottom: 32px;
	}

	.dashboard-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 16px;
		padding: 24px 20px;
		text-align: center;
		transition: all 0.3s ease;
		position: relative;
		overflow: visible;
	}

	.dashboard-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.dashboard-card.clickable {
		cursor: pointer;
		user-select: none;
		padding-bottom: 40px;
	}

	.dashboard-card.clickable:hover {
		transform: translateY(-6px);
		box-shadow: 0 25px 30px -5px rgba(0, 0, 0, 0.15), 0 15px 15px -5px rgba(0, 0, 0, 0.06);
	}

	.dashboard-card.clickable:active {
		transform: translateY(-2px);
		box-shadow: 0 15px 20px -5px rgba(0, 0, 0, 0.1), 0 8px 8px -5px rgba(0, 0, 0, 0.04);
	}

	.dashboard-card.blue:hover {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
	}

	.dashboard-card.green:hover {
		border-color: #10b981;
		background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
	}

	.dashboard-card.purple:hover {
		border-color: #8b5cf6;
		background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%);
	}

	.dashboard-card.orange:hover {
		border-color: #f59e0b;
		background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%);
	}

	.dashboard-card.teal:hover {
		border-color: #14b8a6;
		background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
	}

	.dashboard-card.red:hover {
		border-color: #ef4444;
		background: linear-gradient(135deg, #fef2f2 0%, #fecaca 100%);
	}

	.card-icon {
		width: 64px;
		height: 64px;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 16px auto;
		flex-shrink: 0;
	}

	.dashboard-card.blue .card-icon {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
	}

	.dashboard-card.green .card-icon {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.dashboard-card.purple .card-icon {
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
	}

	.dashboard-card.orange .card-icon {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
	}

	.dashboard-card.teal .card-icon {
		background: linear-gradient(135deg, #14b8a6 0%, #0d9488 100%);
	}

	.dashboard-card.red .card-icon {
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
	}

	.card-icon .icon {
		font-size: 28px;
		color: white;
	}

	.card-title {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.card-count {
		font-size: 32px;
		font-weight: 700;
		color: #1f2937;
		margin: 8px 0 12px 0;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	.dashboard-card.blue .card-count {
		color: #2563eb;
	}

	.dashboard-card.green .card-count {
		color: #059669;
	}

	.dashboard-card.purple .card-count {
		color: #7c3aed;
	}

	.dashboard-card.orange .card-count {
		color: #d97706;
	}

	.dashboard-card.teal .card-count {
		color: #0f766e;
	}

	.dashboard-card.red .card-count {
		color: #dc2626;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.4;
	}

	.click-indicator {
		position: absolute;
		bottom: 12px;
		left: 50%;
		transform: translateX(-50%);
		font-size: 9px;
		font-weight: 600;
		color: #6366f1;
		background: rgba(99, 102, 241, 0.1);
		padding: 3px 8px;
		border-radius: 12px;
		opacity: 0.8;
		transition: all 0.2s ease;
		border: 1px solid rgba(99, 102, 241, 0.2);
		z-index: 10;
		white-space: nowrap;
		text-align: center;
	}

	.dashboard-card.clickable:hover .click-indicator {
		opacity: 1;
		color: #4f46e5;
		background: rgba(99, 102, 241, 0.15);
		border-color: rgba(99, 102, 241, 0.3);
		transform: translateX(-50%) scale(1.05);
	}

	.action-section {
		text-align: center;
		padding: 40px 0;
		display: flex;
		justify-content: center;
		gap: 20px;
		flex-wrap: wrap;
	}

	.start-receiving-btn, .receiving-records-btn {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		color: white;
		border: none;
		border-radius: 16px;
		padding: 20px 40px;
		font-size: 18px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: inline-flex;
		align-items: center;
		gap: 12px;
		box-shadow: 0 10px 25px rgba(5, 150, 105, 0.3);
		min-width: 200px;
	}

	.receiving-records-btn {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		box-shadow: 0 10px 25px rgba(59, 130, 246, 0.3);
	}

	.start-receiving-btn:hover, .receiving-records-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 15px 35px rgba(5, 150, 105, 0.4);
	}

	.start-receiving-btn:hover {
		background: linear-gradient(135deg, #047857 0%, #065f46 100%);
	}

	.receiving-records-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		box-shadow: 0 15px 35px rgba(59, 130, 246, 0.4);
	}

	.start-receiving-btn:active, .receiving-records-btn:active {
		transform: translateY(0);
	}

	.btn-icon {
		font-size: 20px;
	}

	.btn-text {
		font-size: 18px;
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.header {
			flex-direction: column;
			gap: 16px;
			text-align: center;
		}

		.title-section {
			text-align: center;
		}

		.header-actions {
			justify-content: center;
		}

		.refresh-btn {
			padding: 10px 16px;
			font-size: 13px;
		}

		.dashboard-grid {
			grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
			gap: 16px;
		}
		
		.dashboard-card {
			padding: 20px 16px;
		}

		.card-icon {
			width: 48px;
			height: 48px;
		}

		.card-icon .icon {
			font-size: 24px;
		}

		.start-receiving-btn, .receiving-records-btn {
			padding: 16px 32px;
			font-size: 16px;
		}
	}
</style>