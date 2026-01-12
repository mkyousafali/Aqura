<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { createClient } from '@supabase/supabase-js';
	import { currentLocale } from '$lib/i18n';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import PendingToCloseDetails from './PendingToCloseDetails.svelte';
	import type { RealtimeChannel } from '@supabase/supabase-js';

	export let windowId: string;

	// Initialize Supabase client
	const supabase = createClient(
		import.meta.env.VITE_SUPABASE_URL,
		import.meta.env.VITE_SUPABASE_ANON_KEY
	);

	let branches: any[] = [];
	let selectedBranch = '';
	let pendingBoxes: any[] = [];
	let isLoading = true;
	let realtimeChannel: RealtimeChannel | null = null;

	onMount(async () => {
		await loadBranches();
		await loadPendingBoxes();
		setupRealtimeSubscription();
		isLoading = false;
	});

	onDestroy(() => {
		if (realtimeChannel) {
			realtimeChannel.unsubscribe();
		}
	});

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

	async function loadPendingBoxes() {
		isLoading = true;
		try {
			let query = supabase
				.from('box_operations')
				.select('*')
				.eq('status', 'pending_close');

			// Only filter by branch if not "all"
			if (selectedBranch && selectedBranch !== 'all') {
				query = query.eq('branch_id', selectedBranch);
			}

			const { data, error } = await query.order('updated_at', { ascending: false });

			if (error) throw error;
			pendingBoxes = data || [];
			console.log('📦 Loaded pending boxes:', pendingBoxes.length);
		} catch (error) {
			console.error('Error loading pending boxes:', error);
			pendingBoxes = [];
		} finally {
			isLoading = false;
		}
	}

	function setupRealtimeSubscription() {
		if (realtimeChannel) {
			realtimeChannel.unsubscribe();
		}

		if (!selectedBranch) return;

		const channelName = selectedBranch === 'all' 
			? `pending-boxes-all-${Date.now()}`
			: `pending-boxes-${selectedBranch}-${Date.now()}`;

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
					// Only reload if status is pending_close
					if (payload.new?.status === 'pending_close' || payload.old?.status === 'pending_close') {
						await loadPendingBoxes();
					}
				}
			)
			.subscribe();

		realtimeChannel = subscription;
	}

	// Watch for branch changes
	$: if (selectedBranch) {
		loadPendingBoxes();
		setupRealtimeSubscription();
	}

	function viewBoxDetails(box: any) {
		const windowIdUnique = `pending-box-details-${box.id}-${Date.now()}`;
		
		openWindow({
			id: windowIdUnique,
			title: `Pending Box ${box.box_number} - Closing Details`,
			component: PendingToCloseDetails,
			props: {
				windowId: windowIdUnique,
				operation: box,
				branch: { id: selectedBranch }
			},
			icon: '⏳',
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

	function getBranchName(branchId: number) {
		const branch = branches.find(b => b.id === branchId);
		if (!branch) return `Branch ${branchId}`;
		const name = $currentLocale === 'ar' ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar);
		const location = $currentLocale === 'ar' ? (branch.location_ar || branch.location_en) : (branch.location_en || branch.location_ar);
		return `${name} - ${location}`;
	}

	function getClosingDifference(closingDetails: any) {
		try {
			const parsed = typeof closingDetails === 'string' ? JSON.parse(closingDetails) : closingDetails;
			return parsed?.total_difference || 0;
		} catch {
			return 0;
		}
	}

	function getTotalSales(closingDetails: any) {
		try {
			const parsed = typeof closingDetails === 'string' ? JSON.parse(closingDetails) : closingDetails;
			return parsed?.total_sales || 0;
		} catch {
			return 0;
		}
	}
</script>

<div class="pending-boxes-container">
	<div class="header">
		<h1>⏳ {$currentLocale === 'ar' ? 'الصناديق قيد الإغلاق' : 'Pending to Close Boxes'}</h1>
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
	</div>

	<div class="table-container">
		{#if isLoading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else if pendingBoxes.length === 0}
			<div class="no-data">
				<p>⏳ {$currentLocale === 'ar' ? 'لا توجد صناديق قيد الإغلاق' : 'No pending boxes found'}</p>
			</div>
		{:else}
			<table class="boxes-table">
				<thead>
					<tr>
						<th>{$currentLocale === 'ar' ? 'رقم الصندوق' : 'Box #'}</th>
						<th>{$currentLocale === 'ar' ? 'الفرع' : 'Branch'}</th>
						<th>{$currentLocale === 'ar' ? 'الكاشير' : 'Cashier'}</th>
						<th>{$currentLocale === 'ar' ? 'المشرف' : 'Supervisor'}</th>
						<th>{$currentLocale === 'ar' ? 'إجمالي المبيعات' : 'Total Sales'}</th>
						<th>{$currentLocale === 'ar' ? 'الإجمالي قبل' : 'Total Before'}</th>
						<th>{$currentLocale === 'ar' ? 'الإجمالي بعد' : 'Total After'}</th>
						<th>{$currentLocale === 'ar' ? 'الفرق' : 'Difference'}</th>
						<th>{$currentLocale === 'ar' ? 'تاريخ التحديث' : 'Updated At'}</th>
						<th>{$currentLocale === 'ar' ? 'الإجراءات' : 'Actions'}</th>
					</tr>
				</thead>
				<tbody>
					{#each pendingBoxes as box}
						<tr>
							<td class="box-number">
								<span class="box-badge">Box {box.box_number}</span>
							</td>
							<td>{getBranchName(box.branch_id)}</td>
							<td>{parseCashierName(box.notes)}</td>
							<td>{parseSupervisorName(box.notes)}</td>
							<td class="amount">{parseFloat(getTotalSales(box.closing_details) || 0).toFixed(2)}</td>
							<td class="amount">{parseFloat(box.total_before || 0).toFixed(2)}</td>
							<td class="amount">{parseFloat(box.total_after || 0).toFixed(2)}</td>
							<td class="amount {getClosingDifference(box.closing_details) >= 0 ? 'positive' : 'negative'}">
								{parseFloat(getClosingDifference(box.closing_details) || 0).toFixed(2)}
							</td>
							<td class="datetime">{formatDateTime(box.updated_at)}</td>
							<td class="actions">
								<button class="view-btn" on:click={() => viewBoxDetails(box)}>
									👁️ {$currentLocale === 'ar' ? 'عرض التفاصيل' : 'View Details'}
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<style>
	.pending-boxes-container {
		width: 100%;
		height: 100%;
		padding: 1.5rem;
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
		background: white;
		padding: 1.5rem;
		border-radius: 0.75rem;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15),
		            inset 0 1px 0 rgba(255, 255, 255, 0.6);
	}

	.header h1 {
		font-size: 1.5rem;
		color: #d97706;
		margin: 0;
		font-weight: 700;
		letter-spacing: 0.3px;
	}

	.filter-section {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.filter-section label {
		font-weight: 700;
		color: #b45309;
		font-size: 0.95rem;
	}

	.branch-select {
		padding: 0.75rem 1rem;
		border: 2px solid #f59e0b;
		border-radius: 0.5rem;
		font-size: 0.95rem;
		color: #333;
		background: white;
		cursor: pointer;
		transition: all 0.3s ease;
		min-width: 350px;
		font-weight: 500;
		box-shadow: 0 4px 8px rgba(245, 158, 11, 0.1);
	}

	.branch-select:hover {
		border-color: #d97706;
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.2);
		transform: translateY(-2px);
	}

	.branch-select:focus {
		outline: none;
		border-color: #f59e0b;
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.25),
		            0 0 0 3px rgba(245, 158, 11, 0.1);
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
		border-top: 4px solid #f59e0b;
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
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		z-index: 1;
		box-shadow: 0 4px 8px rgba(245, 158, 11, 0.2);
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
		border-bottom: 1px solid #fef3c7;
		transition: all 0.3s ease;
	}

	.boxes-table tbody tr:hover {
		background: linear-gradient(90deg, rgba(245, 158, 11, 0.03) 0%, rgba(245, 158, 11, 0.06) 100%);
		box-shadow: inset 0 0 8px rgba(245, 158, 11, 0.08);
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
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
		padding: 0.35rem 0.85rem;
		border-radius: 1.5rem;
		font-size: 0.8rem;
		font-weight: 700;
		display: inline-block;
		box-shadow: 0 4px 8px rgba(245, 158, 11, 0.25);
		letter-spacing: 0.3px;
	}

	.amount {
		font-family: 'Courier New', monospace;
		font-weight: 700;
		text-align: right;
		color: #d97706;
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
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
		border: none;
		padding: 0.65rem 1.25rem;
		border-radius: 0.5rem;
		font-size: 0.85rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
		letter-spacing: 0.3px;
	}

	.view-btn:hover {
		transform: translateY(-3px);
		box-shadow: 0 8px 20px rgba(245, 158, 11, 0.4);
	}

	.view-btn:active {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.3);
	}
</style>
