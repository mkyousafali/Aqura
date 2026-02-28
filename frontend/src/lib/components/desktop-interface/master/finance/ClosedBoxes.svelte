<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import CompletedBoxDetails from './CompletedBoxDetails.svelte';
	import type { RealtimeChannel } from '@supabase/supabase-js';

	export let windowId: string;

	let supabase: any = null;

	let branches: any[] = [];
	let selectedBranch = '';
	let allLoadedBoxes: any[] = []; // raw data from server
	let completedBoxes: any[] = []; // filtered for display
	let isLoading = true;
	let realtimeChannel: RealtimeChannel | null = null;
	
	// Date-based loading: initial load = last 2 months, "Load Older" = everything before that
	let totalCount = 0;
	let loadingMore = false;

	// Date boundaries
	function getTwoMonthsAgo(): string {
		const d = new Date();
		d.setMonth(d.getMonth() - 2);
		return d.toISOString();
	}
	let dateFrom: string | null = getTwoMonthsAgo();
	let dateTo: string | null = null; // null = no upper bound (now)
	let showingOlderData = false;
	
	// Filters
	let selectedStatus = 'all'; // all, not-transferred, forgiven, proposed
	let selectedDifference = 'all'; // all, short, excess
	let searchCashierName = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadBranches();
		await loadCompletedBoxes();
		setupRealtimeSubscription();
		isLoading = false;
	});

	onDestroy(() => {
		if (realtimeChannel) {
			realtimeChannel.unsubscribe();
		}
	});

	async function handleStatusToggle(box: any) {
		try {
			const completeDetails = typeof box.complete_details === 'string' 
				? JSON.parse(box.complete_details) 
				: box.complete_details;

			if (!box.user_id) {
				alert('Cashier user ID not found in box operation');
				return;
			}

			// Get the employee TEXT id from hr_employee_master using user_id (UUID)
			const { data: employeeData, error: employeeError } = await supabase
				.from('hr_employee_master')
				.select('id')
				.eq('user_id', box.user_id)
				.single();

			if (employeeError || !employeeData) {
				console.error('Error finding employee:', employeeError);
				alert('Employee record not found in HR system');
				return;
			}

			const transferKey = `${box.box_number}-${box.branch_id}-${box.updated_at}`;
			const currentStatus = box.transfer_status || null;
			const shortAmount = Math.abs(completeDetails?.total_difference || 0);

			if (!currentStatus) {
				// State 1: Not Transferred -> Save as Forgiven
				const { error } = await supabase
					.from('pos_deduction_transfers')
					.insert({
						id: employeeData.id,
						box_operation_id: box.id,
						box_number: box.box_number,
						branch_id: box.branch_id,
						cashier_user_id: employeeData.id,
						closed_by: box.completed_by_user_id,
						completed_by_name: completeDetails?.completed_by_name || box.completed_by_name || 'N/A',
						short_amount: shortAmount,
						status: 'Forgiven',
						date_created_box: box.created_at,
						date_closed_box: box.updated_at
					});

				if (error) throw error;
				box.transfer_status = 'Forgiven';
				updateBoxInList(box);
			} else if (currentStatus === 'Forgiven') {
				// State 2: Forgiven -> Update to Proposed
				const { error } = await supabase
					.from('pos_deduction_transfers')
					.update({ status: 'Proposed' })
					.eq('box_operation_id', box.id);

				if (error) throw error;
				box.transfer_status = 'Proposed';
				updateBoxInList(box);
			} else if (currentStatus === 'Proposed') {
				// State 3: Proposed -> Delete (Not Transferred)
				const { error } = await supabase
					.from('pos_deduction_transfers')
					.delete()
					.eq('box_operation_id', box.id);

				if (error) throw error;
				box.transfer_status = null;
				updateBoxInList(box);
			}
		} catch (error) {
			console.error('Error toggling POS deduction status:', error);
			alert($currentLocale === 'ar' ? 'خطأ في تغيير الحالة' : 'Error changing status');
		}
	}

	async function handleBoxStatusToggle(box: any) {
		try {
			// Toggle between "completed" and "pending_close"
			const newStatus = box.status === 'completed' ? 'pending_close' : 'completed';
			
			const { error } = await supabase
				.from('box_operations')
				.update({ status: newStatus })
				.eq('id', box.id);

			if (error) throw error;

			// Update local state
			box.status = newStatus;
			updateBoxInList(box);
		} catch (error) {
			console.error('Error toggling box status:', error);
			alert($currentLocale === 'ar' ? 'خطأ في تغيير حالة الصندوق' : 'Error changing box status');
		}
	}

	// Update a box in both allLoadedBoxes and re-apply filters
	function updateBoxInList(box: any) {
		const idx = allLoadedBoxes.findIndex(b => b.id === box.id);
		if (idx >= 0) {
			allLoadedBoxes[idx] = { ...box };
			allLoadedBoxes = [...allLoadedBoxes];
		}
		applyFilters();
	}

async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.eq('is_active', true);

			if (error) throw error;
			branches = data || [];
			
			console.log('📍 Loaded branches:', branches);

			// Auto-select all branches if available
			if (!selectedBranch) {
				selectedBranch = 'all';
			}
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}
	async function loadCompletedBoxes(append = false) {
		if (append) {
			loadingMore = true;
		} else {
			isLoading = true;
		}
		try {

			// Always fetch ALL records in the date range (no pagination limit)
			const { data: rpcResult, error: rpcError } = await supabase.rpc('get_closed_boxes', {
				p_branch_id: selectedBranch || 'all',
				p_date_from: dateFrom || null,
				p_date_to: dateTo || null,
				p_limit: 100000,
				p_offset: 0
			});

			if (rpcError) throw rpcError;

			const result = rpcResult || { boxes: [], total_count: 0 };
			let boxes = result.boxes || [];

			// Build transfer map from RPC results (transfer_status is already on each box)
			// No separate map needed - status is directly on the box object

			totalCount = result.total_count || 0;
			
			if (append) {
				allLoadedBoxes = [...allLoadedBoxes, ...boxes];
			} else {
				allLoadedBoxes = boxes;
			}
			
			// Apply filters
			applyFilters();
			
			console.log(`📦 Loaded ${allLoadedBoxes.length} boxes total (this batch: ${boxes.length}), total in range: ${totalCount}`);
		} catch (error) {
			console.error('Error loading completed boxes:', error);
			completedBoxes = [];
		} finally {
			isLoading = false;
			loadingMore = false;
		}
	}

	function loadOlderData() {
		if (loadingMore || isLoading) return;
		// Load ALL older data (before the 2-month window) and append
		showingOlderData = true;
		dateTo = dateFrom; // upper bound = old dateFrom
		dateFrom = null;   // no lower bound
		loadCompletedBoxes(true); // append to existing
	}

	function setupRealtimeSubscription() {
		if (realtimeChannel) {
			realtimeChannel.unsubscribe();
		}

		if (!selectedBranch) return;

		const channelName = selectedBranch === 'all' 
			? `closed-boxes-all-${Date.now()}`
			: `closed-boxes-${selectedBranch}-${Date.now()}`;

		let subscription = supabase
			.channel(channelName)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'box_operations'
				},
				async (payload) => {
					console.log('📡 Box operations update:', payload);
					// Only reload if status is completed
					if (payload.new?.status === 'completed' || payload.old?.status === 'completed') {
						await loadCompletedBoxes();
					}
				}
			)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'pos_deduction_transfers'
				},
				async (payload) => {
					console.log('📡 POS Deduction transfer update:', payload);
					const boxOpId = payload.new?.box_operation_id || payload.old?.box_operation_id;
					
					if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
						// Update transfer_status directly on the box
						const box = allLoadedBoxes.find(b => b.id === boxOpId);
						if (box) {
							box.transfer_status = payload.new.status;
							allLoadedBoxes = [...allLoadedBoxes];
							applyFilters();
						}
					} else if (payload.eventType === 'DELETE') {
						const box = allLoadedBoxes.find(b => b.id === boxOpId);
						if (box) {
							box.transfer_status = null;
							allLoadedBoxes = [...allLoadedBoxes];
							applyFilters();
						}
					}
				}
			)
			.subscribe();

		realtimeChannel = subscription;
	}

	// Apply client-side filters on already-loaded data
	function applyFilters() {
		let filtered = [...allLoadedBoxes];

		// Filter by difference (short / excess)
		if (selectedDifference === 'short') {
			filtered = filtered.filter(box => getClosingDifference(box.complete_details) < 0);
		} else if (selectedDifference === 'excess') {
			filtered = filtered.filter(box => getClosingDifference(box.complete_details) > 0);
		}

		if (selectedStatus !== 'all') {
			filtered = filtered.filter(box => {
				const difference = getClosingDifference(box.complete_details);
				const hasAnyShortage = difference < 0;
				
				if (!hasAnyShortage) return false;
				
				const status = box.transfer_status || null;
				
				if (selectedStatus === 'not-transferred') return !status;
				if (selectedStatus === 'forgiven') return status === 'Forgiven';
				if (selectedStatus === 'proposed') return status === 'Proposed';
				return true;
			});
		}
		
		if (searchCashierName.trim()) {
			const searchLower = searchCashierName.toLowerCase();
			filtered = filtered.filter(box => {
				const cashierName = parseCashierName(box.notes).toLowerCase();
				return cashierName.includes(searchLower);
			});
		}
		
		completedBoxes = filtered;
	}

	// Watch for branch changes
	$: if (selectedBranch && supabase) {
		// Reset date range
		dateFrom = getTwoMonthsAgo();
		dateTo = null;
		showingOlderData = false;
		loadCompletedBoxes();
		setupRealtimeSubscription();
	}

	// Watch for filter changes (client-side only, no re-fetch)
	$: if (selectedStatus || selectedDifference || searchCashierName !== undefined) {
		if (allLoadedBoxes.length > 0) {
			applyFilters();
		}
	}

	function viewBoxDetails(box: any) {
		const windowIdUnique = `completed-box-details-${box.id}-${Date.now()}`;
		
		openWindow({
			id: windowIdUnique,
			title: `Completed Box ${box.box_number} - Final Details`,
			component: CompletedBoxDetails,
			props: {
				windowId: windowIdUnique,
				operation: box,
				branch: { id: selectedBranch }
			},
			icon: '📋',
			size: { width: 900, height: 700 },
			position: { x: 200, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function formatDateTime(dateString: string) {
		if (!dateString) return 'N/A';
		const date = new Date(dateString);
		return date.toLocaleString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function parseCashierName(notes: any) {
		try {
			const parsed = typeof notes === 'string' ? JSON.parse(notes) : notes;
			return parsed?.cashier_name || 'N/A';
		} catch {
			return 'N/A';
		}
	}

	function parseSupervisorName(notes: any) {
		try {
			const parsed = typeof notes === 'string' ? JSON.parse(notes) : notes;
			return parsed?.supervisor_name || 'N/A';
		} catch {
			return 'N/A';
		}
	}

	function hasExistingTransfer(box: any): boolean {
		return !!box.transfer_status;
	}

	function getTransferStatus(box: any): string {
		return box.transfer_status || '';
	}

	function getBranchName(branchId: number) {
		const branch = branches.find(b => b.id === branchId);
		if (!branch) return `Branch ${branchId}`;
		const name = $currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar);
		const location = $currentLocale === 'ar' ? (branch.location_ar || branch.location_en) : (branch.location_en || branch.location_ar);
		return `${name} - ${location}`;
	}

	function getClosingDifference(completeDetails: any) {
		try {
			const parsed = typeof completeDetails === 'string' ? JSON.parse(completeDetails) : completeDetails;
			return parsed?.total_difference || 0;
		} catch {
			return 0;
		}
	}

	function getTotalSales(completeDetails: any) {
		try {
			const parsed = typeof completeDetails === 'string' ? JSON.parse(completeDetails) : completeDetails;
			return parsed?.total_sales || 0;
		} catch {
			return 0;
		}
	}
</script>

<div class="closed-boxes-container">
	<div class="header">
		<h1>📋 {$currentLocale === 'ar' ? 'الصناديق المغلقة' : 'Closed Boxes'}</h1>
		<div class="filters-container">
			<div class="filter-section">
				<label for="branch-select">
					{$currentLocale === 'ar' ? 'الفرع:' : 'Branch:'}
				</label>
				<select id="branch-select" bind:value={selectedBranch} class="branch-select">
					<option value="all">
						{$currentLocale === 'ar' ? '🌍 جميع الفروع' : '🌍 All Branches'}
					</option>
					{#each branches as branch}
						<option value={String(branch.id)}>
							{$currentLocale === 'ar'
								? `${branch.name_ar || branch.name_en} - ${branch.location_ar || branch.location_en}`
								: `${branch.name_en || branch.name_ar} - ${branch.location_en || branch.location_ar}`}
						</option>
					{/each}
				</select>
			</div>
			
			<div class="filter-section">
				<label for="status-select">
					{$currentLocale === 'ar' ? 'حالة الخصم:' : 'Deduction Status:'}
				</label>
				<select id="status-select" bind:value={selectedStatus} class="status-select">
					<option value="all">
						{$currentLocale === 'ar' ? '🔍 الكل' : '🔍 All'}
					</option>
					<option value="not-transferred">
						{$currentLocale === 'ar' ? '🔴 غير محول' : '🔴 Not Transferred'}
					</option>
					<option value="forgiven">
						{$currentLocale === 'ar' ? '🟠 مسامح' : '🟠 Forgiven'}
					</option>
					<option value="proposed">
						{$currentLocale === 'ar' ? '🟢 مقترح' : '🟢 Proposed'}
					</option>
				</select>
			</div>

			<div class="filter-section">
				<label for="difference-select">
					{$currentLocale === 'ar' ? 'الفرق:' : 'Difference:'}
				</label>
				<select id="difference-select" bind:value={selectedDifference} class="status-select">
					<option value="all">
						{$currentLocale === 'ar' ? '🔍 الكل' : '🔍 All'}
					</option>
					<option value="short">
						{$currentLocale === 'ar' ? '🔴 نقص فقط' : '🔴 Short Only'}
					</option>
					<option value="excess">
						{$currentLocale === 'ar' ? '🟢 زيادة فقط' : '🟢 Excess Only'}
					</option>
				</select>
			</div>
			
			<div class="filter-section">
				<label for="search-cashier">
					{$currentLocale === 'ar' ? 'بحث بالكاشير:' : 'Search Cashier:'}
				</label>
				<input 
					id="search-cashier"
					type="text" 
					bind:value={searchCashierName} 
					placeholder={$currentLocale === 'ar' ? 'اسم الكاشير...' : 'Cashier name...'}
					class="search-input"
				/>
			</div>
			
			{#if completedBoxes.length > 0}
				<div class="filter-section">
					<span class="load-more-info">
						{$currentLocale === 'ar' 
							? `عرض ${completedBoxes.length} (${showingOlderData ? 'الكل' : 'آخر شهرين'})` 
							: `Showing ${completedBoxes.length} (${showingOlderData ? 'All time' : 'Last 2 months'})`}
					</span>
				</div>
			{/if}
		</div>
	</div>

	<div class="table-container">
		{#if isLoading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else if completedBoxes.length === 0}
			<div class="no-data">
				<p>📦 {$currentLocale === 'ar' ? 'لا توجد صناديق مغلقة' : 'No closed boxes found'}</p>
			</div>
		{:else}
			<table class="boxes-table">
				<thead>
					<tr>
						<th>{$currentLocale === 'ar' ? 'رقم الصندوق' : 'Box #'}</th>
						<th>{$currentLocale === 'ar' ? 'الحالة' : 'Status'}</th>
						<th>{$currentLocale === 'ar' ? 'الفرع' : 'Branch'}</th>
						<th>{$currentLocale === 'ar' ? 'الكاشير' : 'Cashier'}</th>
						<th>{$currentLocale === 'ar' ? 'المشرف' : 'Supervisor'}</th>
						<th>{$currentLocale === 'ar' ? 'مغلق بواسطة' : 'Closed By'}</th>
						<th>{$currentLocale === 'ar' ? 'إجمالي المبيعات' : 'Total Sales'}</th>
						<th>{$currentLocale === 'ar' ? 'الإجمالي قبل' : 'Total Before'}</th>
						<th>{$currentLocale === 'ar' ? 'الإجمالي بعد' : 'Total After'}</th>
						<th>{$currentLocale === 'ar' ? 'الفرق' : 'Difference'}</th>					<th>{$currentLocale === 'ar' ? 'خصم نقطة البيع' : 'POS Deduction Transfer'}</th>						<th>{$currentLocale === 'ar' ? 'تاريخ الإغلاق' : 'Closed At'}</th>
						<th>{$currentLocale === 'ar' ? 'الإجراءات' : 'Actions'}</th>
					</tr>
				</thead>
				<tbody>
					{#each completedBoxes as box}
						<tr>
							<td class="box-number">
								<span class="box-badge">Box {box.box_number}</span>
							</td>
							<td class="status-cell">
								<button 
									class="status-toggle-btn status-{box.status}"
									on:click={() => handleBoxStatusToggle(box)}
								>
								{box.status === 'completed' ? '✓ Completed' : box.status === 'pending_close' ? '⏳ Pending Close' : box.status || 'N/A'}
								</button>
							</td>
							<td>{getBranchName(box.branch_id)}</td>
							<td>{parseCashierName(box.notes)}</td>
							<td>{parseSupervisorName(box.notes)}</td>
							<td class="closed-by-user">{box.completed_by_name || 'N/A'}</td>
					<td class="amount">{parseFloat(getTotalSales(box.complete_details) || 0).toFixed(2)}</td>
							<td class="amount">{parseFloat(box.total_before || 0).toFixed(2)}</td>
							<td class="amount">{parseFloat(box.total_after || 0).toFixed(2)}</td>
						<td class="amount {getClosingDifference(box.complete_details) >= 0 ? 'positive' : 'negative'}">
							{parseFloat(getClosingDifference(box.complete_details) || 0).toFixed(2)}
							</td>					<td class="pos-deduction-cell">
						{#if getClosingDifference(box.complete_details) < 0}
							<button 
								class="status-toggle-btn status-{hasExistingTransfer(box) ? getTransferStatus(box).toLowerCase() : 'not-transferred'}" 
								on:click={() => handleStatusToggle(box)}
							>
								{hasExistingTransfer(box) ? getTransferStatus(box) : 'Not Transferred'}
							</button>
						{:else}
							<span class="na-text">N/A</span>
						{/if}
					</td>							<td class="datetime">{formatDateTime(box.updated_at)}</td>
							<td class="actions">
								<button class="view-btn" on:click={() => viewBoxDetails(box)}>
									👁️ {$currentLocale === 'ar' ? 'عرض النهائي' : 'View Final'}
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>

			<!-- Load Older Data button -->
			<div class="load-more-container">
				{#if loadingMore}
					<div class="loading-more-indicator">
						<div class="spinner-small"></div>
						<span>{$currentLocale === 'ar' ? 'جاري تحميل البيانات الأقدم...' : 'Loading older data...'}</span>
					</div>
				{:else if !showingOlderData}
					<button class="load-older-btn" on:click={loadOlderData}>
						📜 {$currentLocale === 'ar' ? 'تحميل بيانات أقدم (قبل شهرين)' : 'Load Older Data (before 2 months)'}
					</button>
				{/if}
			</div>
		{/if}
	</div>
</div>

<style>
	.closed-boxes-container {
		width: 100%;
		height: 100%;
		padding: 1.5rem;
		background: linear-gradient(135deg, #1f7a3a 0%, #2d5f4f 100%);
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.header {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1.5rem;
		background: white;
		padding: 1.5rem;
		border-radius: 0.75rem;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15),
		            inset 0 1px 0 rgba(255, 255, 255, 0.6);
	}

	.header h1 {
		font-size: 1.5rem;
		color: #1f7a3a;
		margin: 0;
		font-weight: 700;
		letter-spacing: 0.3px;
	}

	.filters-container {
		display: flex;
		gap: 1rem;
		flex-wrap: wrap;
		align-items: flex-end;
	}

	.filter-section {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.filter-section label {
		font-weight: 700;
		color: #2d5f4f;
		font-size: 0.85rem;
	}

	.branch-select, .status-select {
		padding: 0.75rem 1rem;
		border: 2px solid #1f7a3a;
		border-radius: 0.5rem;
		font-size: 0.9rem;
		color: #333;
		background: white;
		cursor: pointer;
		transition: all 0.3s ease;
		min-width: 250px;
		font-weight: 500;
		box-shadow: 0 4px 8px rgba(31, 122, 58, 0.1);
	}

	.search-input {
		padding: 0.75rem 1rem;
		border: 2px solid #1f7a3a;
		border-radius: 0.5rem;
		font-size: 0.9rem;
		color: #333;
		background: white;
		transition: all 0.3s ease;
		min-width: 250px;
		font-weight: 500;
		box-shadow: 0 4px 8px rgba(31, 122, 58, 0.1);
	}

	.branch-select:hover, .status-select:hover, .search-input:hover {
		border-color: #2d5f4f;
		box-shadow: 0 6px 16px rgba(31, 122, 58, 0.2);
		transform: translateY(-2px);
	}

	.branch-select:focus, .status-select:focus, .search-input:focus {
		outline: none;
		border-color: #1f7a3a;
		box-shadow: 0 6px 16px rgba(31, 122, 58, 0.25),
		            0 0 0 3px rgba(31, 122, 58, 0.1);
	}

	.table-container {
		flex: 1;
		background: white;
		border-radius: 0.75rem;
		padding: 1.5rem;
		overflow: auto;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15),
		            inset 0 1px 0 rgba(255, 255, 255, 0.6);
	}

	.loading, .no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: #666;
		gap: 1rem;
	}

	.spinner {
		border: 4px solid #f3f3f3;
		border-top: 4px solid #1f7a3a;
		border-radius: 50%;
		width: 40px;
		height: 40px;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.boxes-table {
		width: 100%;
		border-collapse: collapse;
	}

	.boxes-table thead {
		position: sticky;
		top: 0;
		background: linear-gradient(135deg, #1f7a3a 0%, #2d5f4f 100%);
		z-index: 1;
		box-shadow: 0 4px 8px rgba(31, 122, 58, 0.2);
	}

	.boxes-table th {
		padding: 1rem 1.5rem;
		text-align: left;
		color: white;
		font-weight: 700;
		font-size: 0.85rem;
		text-transform: uppercase;
		letter-spacing: 1px;
	}

	.boxes-table tbody tr {
		border-bottom: 1px solid #e8f0ed;
		transition: all 0.3s ease;
	}

	.boxes-table tbody tr:hover {
		background: linear-gradient(90deg, rgba(31, 122, 58, 0.03) 0%, rgba(31, 122, 58, 0.06) 100%);
		box-shadow: inset 0 0 8px rgba(31, 122, 58, 0.08);
	}

	.boxes-table td {
		padding: 1rem 1.5rem;
		font-size: 0.9rem;
		color: #333;
	}

	.box-number {
		font-weight: 700;
	}

	.box-badge {
		background: linear-gradient(135deg, #1f7a3a 0%, #2d5f4f 100%);
		color: white;
		padding: 0.35rem 0.85rem;
		border-radius: 1.5rem;
		font-size: 0.8rem;
		font-weight: 700;
		display: inline-block;
		box-shadow: 0 4px 8px rgba(31, 122, 58, 0.25);
		letter-spacing: 0.3px;
	}

	.closed-by-user {
		font-weight: 600;
		color: #1f7a3a;
		padding: 0.5rem;
		background: rgba(31, 122, 58, 0.05);
		border-radius: 0.4rem;
	}

	.amount {
		font-family: 'Courier New', monospace;
		font-weight: 700;
		text-align: right;
		color: #1f7a3a;
	}

	.amount.positive {
		color: #15a34a;
	}

	.amount.negative {
		color: #dc2626;
	}

	.datetime {
		color: #666;
		font-size: 0.85rem;
	}

	.actions {
		text-align: center;
	}

	.view-btn {
		background: linear-gradient(135deg, #1f7a3a 0%, #2d5f4f 100%);
		color: white;
		border: none;
		padding: 0.65rem 1.25rem;
		border-radius: 0.5rem;
		font-size: 0.85rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(31, 122, 58, 0.3);
		letter-spacing: 0.3px;
	}

	.view-btn:hover {
		transform: translateY(-3px);
		box-shadow: 0 8px 20px rgba(31, 122, 58, 0.4);
	}

	.view-btn:active {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(31, 122, 58, 0.3);
	}

	.pos-deduction-cell {
		text-align: center;
	}

	.status-toggle-btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 1rem;
		font-size: 0.8rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s ease;
		color: white;
		box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
		letter-spacing: 0.3px;
	}

	.status-toggle-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
	}

	.status-toggle-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
	}

	.status-toggle-btn.status-not-transferred {
		background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
		box-shadow: 0 2px 6px rgba(220, 38, 38, 0.3);
	}

	.status-toggle-btn.status-not-transferred:hover {
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.4);
	}

	.na-text {
		color: #999;
		font-size: 0.85rem;
		font-style: italic;
	}

	.status-toggle-btn.status-proposed {
		background: linear-gradient(135deg, #15a34a 0%, #16803d 100%);
		box-shadow: 0 2px 6px rgba(21, 163, 74, 0.3);
	}

	.status-toggle-btn.status-proposed:hover {
		box-shadow: 0 4px 12px rgba(21, 163, 74, 0.4);
	}

	.status-toggle-btn.status-forgiven {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		box-shadow: 0 2px 6px rgba(245, 158, 11, 0.3);
	}

	.status-toggle-btn.status-forgiven:hover {
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.status-toggle-btn.status-deducted {
		background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
		box-shadow: 0 2px 6px rgba(220, 38, 38, 0.3);
	}

	.status-toggle-btn.status-deducted:hover {
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.4);
	}

	.status-toggle-btn.status-cancelled {
		background: linear-gradient(135deg, #6b7280 0%, #4b5563 100%);
		box-shadow: 0 2px 6px rgba(107, 114, 128, 0.3);
	}

	.status-toggle-btn.status-cancelled:hover {
		box-shadow: 0 4px 12px rgba(107, 114, 128, 0.4);
	}

	.load-more-btn {
		background: linear-gradient(135deg, #1f7a3a 0%, #2d5f4f 100%);
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(31, 122, 58, 0.3);
		letter-spacing: 0.3px;
		width: 100%;
	}

	.load-more-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(31, 122, 58, 0.4);
	}

	.load-more-btn:active {
		transform: translateY(0);
		box-shadow: 0 4px 12px rgba(31, 122, 58, 0.3);
	}

	.load-more-info {
		font-size: 0.8rem;
		color: #2d5f4f;
		font-weight: 600;
		text-align: center;
		margin-top: 0.5rem;
	}

	.status-cell {
		text-align: center;
	}

	.status-toggle-btn.status-completed {
		background: linear-gradient(135deg, #15a34a 0%, #16803d 100%);
		box-shadow: 0 2px 6px rgba(21, 163, 74, 0.3);
	}

	.status-toggle-btn.status-completed:hover {
		box-shadow: 0 4px 12px rgba(21, 163, 74, 0.4);
	}

	.status-toggle-btn.status-pending_close {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		box-shadow: 0 2px 6px rgba(245, 158, 11, 0.3);
	}

	.status-toggle-btn.status-pending_close:hover {
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.status-toggle-btn.status-open {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		box-shadow: 0 2px 6px rgba(59, 130, 246, 0.3);
	}

	.status-toggle-btn.status-open:hover {
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.status-toggle-btn.status-cancelled {
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		box-shadow: 0 2px 6px rgba(239, 68, 68, 0.3);
	}

	.status-toggle-btn.status-cancelled:hover {
		box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
	}

	.load-more-container {
		display: flex;
		gap: 1rem;
		justify-content: center;
		align-items: center;
		padding: 1.5rem 0 0.5rem;
		flex-wrap: wrap;
	}

	.load-more-container .load-more-btn {
		width: auto;
		min-width: 180px;
	}

	.load-older-btn {
		background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
		letter-spacing: 0.3px;
		min-width: 280px;
	}

	.load-older-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(99, 102, 241, 0.4);
	}

	.load-older-btn:active {
		transform: translateY(0);
		box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
	}

	.loading-more-indicator {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		color: #1f7a3a;
		font-weight: 600;
		padding: 0.75rem;
	}

	.spinner-small {
		border: 3px solid #e8f0ed;
		border-top: 3px solid #1f7a3a;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		animation: spin 1s linear infinite;
	}
</style>
