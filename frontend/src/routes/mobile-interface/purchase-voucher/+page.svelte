<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';

	let isLoading = true;
	let branches = [];
	let showCard1Breakdown = false;
	let showCard2Breakdown = false;
	let showCard3Breakdown = false;
	let showCard4Breakdown = false;

	// Status card 1 data - Not Issued (Available)
	let notIssuedStats = {
		totalVouchers: 0,
		byBranch: {},
		byValue: {}
	};

	// Status card 2 data - Issued
	let issuedStats = {
		totalVouchers: 0,
		byBranch: {},
		byValue: {}
	};

	// Status card 3 data - Closed
	let closedStats = {
		totalVouchers: 0,
		byBranch: {},
		byValue: {}
	};

	// Status card 4 data - My Stock (logged user's stock)
	let myStockStats = {
		totalVouchers: 0,
		byValue: {}
	};

	// Create lookup maps for display
	$: branchMap = branches.reduce((map, b) => {
		map[b.id] = `${b.name_en}`;
		return map;
	}, {});

	let subscription;
	let isComponentMounted = true;

	function getTranslation(key: string): string {
		const data = $localeData;
		const keys = key.split('.');
		let value: any = data.translations;
		for (const k of keys) {
			if (value && typeof value === 'object' && k in value) {
				value = value[k];
			} else {
				return key;
			}
		}
		return typeof value === 'string' ? value : key;
	}

	onMount(async () => {
		await loadBranches();
		await Promise.all([
			loadNotIssuedStats(),
			loadIssuedStats(),
			loadClosedStats(),
			loadMyStockStats()
		]);
		isLoading = false;

		// Setup realtime subscription
		setupRealtimeSubscriptions();

		return () => {
			isComponentMounted = false;
			if (subscription) {
				subscription.unsubscribe();
			}
		};
	});

	onDestroy(() => {
		isComponentMounted = false;
		if (subscription) {
			subscription.unsubscribe();
		}
	});

	function setupRealtimeSubscriptions() {
		const channelName = `mobile_pv_manager_${Date.now()}`;
		
		subscription = supabase
			.channel(channelName)
			.on(
				'postgres_changes',
				{
					event: '*',
					schema: 'public',
					table: 'purchase_voucher_items'
				},
				() => {
					handleStatsUpdate();
				}
			)
			.subscribe();
	}

	async function handleStatsUpdate() {
		if (!isComponentMounted) return;
		await Promise.all([
			loadNotIssuedStats(),
			loadIssuedStats(),
			loadClosedStats(),
			loadMyStockStats()
		]);
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.limit(100);
			if (!error) {
				branches = data || [];
			}
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	async function loadNotIssuedStats() {
		if (!isComponentMounted) return;
		
		try {
			const [vouchersRes, itemsRes] = await Promise.all([
				supabase
					.from('purchase_vouchers')
					.select('id, book_number')
					.limit(1000),
				supabase
					.from('purchase_voucher_items')
					.select('purchase_voucher_id, value, stock_location')
					.eq('issue_type', 'not issued')
					.limit(10000)
			]);

			if (vouchersRes.error || itemsRes.error) {
				console.error('Error loading not issued stats:', vouchersRes.error || itemsRes.error);
				return;
			}

			const items = itemsRes.data || [];
			const allVoucherIds = new Set();
			const branchValueCounts = {};

			items.forEach(item => {
				const branchId = item.stock_location || 'unassigned';
				const voucherId = item.purchase_voucher_id;
				const value = item.value || 0;

				allVoucherIds.add(voucherId);

				if (!branchValueCounts[branchId]) {
					branchValueCounts[branchId] = {};
				}

				if (!branchValueCounts[branchId][value]) {
					branchValueCounts[branchId][value] = {
						vouchers: 0,
						books: new Set()
					};
				}
				
				branchValueCounts[branchId][value].vouchers++;
				branchValueCounts[branchId][value].books.add(voucherId);
			});

			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					branchValueCounts[branchId][value].books = branchValueCounts[branchId][value].books.size;
				});
			});

			const valueSummary = {};
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					if (!valueSummary[value]) {
						valueSummary[value] = { vouchers: 0, books: 0 };
					}
					valueSummary[value].vouchers += branchValueCounts[branchId][value].vouchers;
					valueSummary[value].books += branchValueCounts[branchId][value].books;
				});
			});

			notIssuedStats = {
				totalVouchers: items.length,
				byBranch: branchValueCounts,
				byValue: valueSummary
			};

		} catch (error) {
			console.error('Error in loadNotIssuedStats:', error);
		}
	}

	async function loadIssuedStats() {
		if (!isComponentMounted) return;
		
		try {
			const [vouchersRes, itemsRes] = await Promise.all([
				supabase
					.from('purchase_vouchers')
					.select('id, book_number')
					.limit(1000),
				supabase
					.from('purchase_voucher_items')
					.select('purchase_voucher_id, value, stock_location, issue_type')
					.neq('issue_type', 'not issued')
					.neq('status', 'closed')
					.limit(10000)
			]);

			if (vouchersRes.error || itemsRes.error) {
				console.error('Error loading issued stats:', vouchersRes.error || itemsRes.error);
				return;
			}

			const items = itemsRes.data || [];
			const allVoucherIds = new Set();
			const branchValueCounts = {};

			items.forEach(item => {
				const branchId = item.stock_location || 'unassigned';
				const voucherId = item.purchase_voucher_id;
				const value = item.value || 0;
				const issueType = item.issue_type || 'unknown';

				allVoucherIds.add(voucherId);

				if (!branchValueCounts[branchId]) {
					branchValueCounts[branchId] = {};
				}

				if (!branchValueCounts[branchId][value]) {
					branchValueCounts[branchId][value] = {};
				}

				if (!branchValueCounts[branchId][value][issueType]) {
					branchValueCounts[branchId][value][issueType] = {
						vouchers: 0,
						books: new Set()
					};
				}
				
				branchValueCounts[branchId][value][issueType].vouchers++;
				branchValueCounts[branchId][value][issueType].books.add(voucherId);
			});

			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						branchValueCounts[branchId][value][issueType].books = branchValueCounts[branchId][value][issueType].books.size;
					});
				});
			});

			const valueSummary = {};
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						if (!valueSummary[value]) {
							valueSummary[value] = { vouchers: 0, books: 0 };
						}
						valueSummary[value].vouchers += branchValueCounts[branchId][value][issueType].vouchers;
						valueSummary[value].books += branchValueCounts[branchId][value][issueType].books;
					});
				});
			});

			issuedStats = {
				totalVouchers: items.length,
				byBranch: branchValueCounts,
				byValue: valueSummary
			};

		} catch (error) {
			console.error('Error in loadIssuedStats:', error);
		}
	}

	async function loadClosedStats() {
		if (!isComponentMounted) return;
		
		try {
			const [vouchersRes, itemsRes] = await Promise.all([
				supabase
					.from('purchase_vouchers')
					.select('id, book_number')
					.limit(1000),
				supabase
					.from('purchase_voucher_items')
					.select('purchase_voucher_id, value, stock_location, issue_type')
					.eq('status', 'closed')
					.limit(10000)
			]);

			if (vouchersRes.error || itemsRes.error) {
				console.error('Error loading closed stats:', vouchersRes.error || itemsRes.error);
				return;
			}

			const items = itemsRes.data || [];
			const allVoucherIds = new Set();
			const branchValueCounts = {};

			items.forEach(item => {
				const branchId = item.stock_location || 'unassigned';
				const voucherId = item.purchase_voucher_id;
				const value = item.value || 0;
				const issueType = item.issue_type || 'unknown';

				allVoucherIds.add(voucherId);

				if (!branchValueCounts[branchId]) {
					branchValueCounts[branchId] = {};
				}

				if (!branchValueCounts[branchId][value]) {
					branchValueCounts[branchId][value] = {};
				}

				if (!branchValueCounts[branchId][value][issueType]) {
					branchValueCounts[branchId][value][issueType] = {
						vouchers: 0,
						books: new Set()
					};
				}
				
				branchValueCounts[branchId][value][issueType].vouchers++;
				branchValueCounts[branchId][value][issueType].books.add(voucherId);
			});

			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						branchValueCounts[branchId][value][issueType].books = branchValueCounts[branchId][value][issueType].books.size;
					});
				});
			});

			const valueSummary = {};
			Object.keys(branchValueCounts).forEach(branchId => {
				Object.keys(branchValueCounts[branchId]).forEach(value => {
					Object.keys(branchValueCounts[branchId][value]).forEach(issueType => {
						if (!valueSummary[value]) {
							valueSummary[value] = { vouchers: 0, books: 0 };
						}
						valueSummary[value].vouchers += branchValueCounts[branchId][value][issueType].vouchers;
						valueSummary[value].books += branchValueCounts[branchId][value][issueType].books;
					});
				});
			});

			closedStats = {
				totalVouchers: items.length,
				byBranch: branchValueCounts,
				byValue: valueSummary
			};

		} catch (error) {
			console.error('Error in loadClosedStats:', error);
		}
	}

	async function loadMyStockStats() {
		if (!isComponentMounted) return;
		
		const userId = $currentUser?.id;
		if (!userId) {
			myStockStats = { totalVouchers: 0, byValue: {} };
			return;
		}
		
		try {
			const { data: items, error } = await supabase
				.from('purchase_voucher_items')
				.select('purchase_voucher_id, value, status, issue_type')
				.eq('stock_person', userId)
				.neq('status', 'closed')
				.limit(10000);

			if (error) {
				console.error('Error loading my stock stats:', error);
				return;
			}

			const valueCounts = {};

			(items || []).forEach(item => {
				const value = item.value || 0;

				if (!valueCounts[value]) {
					valueCounts[value] = {
						vouchers: 0,
						books: new Set(),
						notIssued: 0,
						issued: 0
					};
				}
				
				valueCounts[value].vouchers++;
				valueCounts[value].books.add(item.purchase_voucher_id);
				
				if (item.issue_type === 'not issued') {
					valueCounts[value].notIssued++;
				} else {
					valueCounts[value].issued++;
				}
			});

			// Convert Sets to counts
			Object.keys(valueCounts).forEach(value => {
				valueCounts[value].books = valueCounts[value].books.size;
			});

			myStockStats = {
				totalVouchers: (items || []).length,
				byValue: valueCounts
			};

		} catch (error) {
			console.error('Error in loadMyStockStats:', error);
		}
	}
</script>

<div class="mobile-pv-manager">
	{#if isLoading}
		<div class="loading-state">
			<div class="spinner large"></div>
			<p>{getTranslation('mobile.purchaseVoucher.loading')}</p>
		</div>
	{:else}
		<div class="status-cards">
			<!-- Available Vouchers Card -->
			<div class="status-card available" on:click={() => showCard1Breakdown = !showCard1Breakdown}>
				<div class="card-header">
					<div class="card-icon">📦</div>
					<div class="card-info">
						<h3>{getTranslation('mobile.purchaseVoucher.available')}</h3>
						<span class="card-count">{notIssuedStats.totalVouchers}</span>
					</div>
					<span class="expand-icon">{showCard1Breakdown ? '▼' : '▶'}</span>
				</div>
				
				{#if !showCard1Breakdown}
					<div class="value-summary">
						{#if Object.keys(notIssuedStats.byValue || {}).length > 0}
							{#each Object.entries(notIssuedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
								<div class="value-item">
									<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
									<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
								</div>
							{/each}
						{:else}
							<p class="no-data">{getTranslation('mobile.purchaseVoucher.noAvailableVouchers')}</p>
						{/if}
					</div>
				{:else}
					<div class="branch-breakdown">
						{#if Object.keys(notIssuedStats.byBranch).length > 0}
							{#each Object.entries(notIssuedStats.byBranch) as [branchId, valueCounts]}
								<div class="branch-section">
									<h4>{branchMap[branchId] || (branchId === 'unassigned' ? getTranslation('mobile.purchaseVoucher.unassigned') : branchId)}</h4>
									{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
										<div class="value-item">
											<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
											<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
										</div>
									{/each}
								</div>
							{/each}
						{:else}
							<p class="no-data">No available vouchers</p>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Issued Vouchers Card -->
			<div class="status-card issued" on:click={() => showCard2Breakdown = !showCard2Breakdown}>
				<div class="card-header">
					<div class="card-icon">📤</div>
					<div class="card-info">
						<h3>{getTranslation('mobile.purchaseVoucher.issued')}</h3>
						<span class="card-count">{issuedStats.totalVouchers}</span>
					</div>
					<span class="expand-icon">{showCard2Breakdown ? '▼' : '▶'}</span>
				</div>
				
				{#if !showCard2Breakdown}
					<div class="value-summary">
						{#if Object.keys(issuedStats.byValue || {}).length > 0}
							{#each Object.entries(issuedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
								<div class="value-item">
									<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
									<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
								</div>
							{/each}
						{:else}
							<p class="no-data">{getTranslation('mobile.purchaseVoucher.noIssuedVouchers')}</p>
						{/if}
					</div>
				{:else}
					<div class="branch-breakdown">
						{#if Object.keys(issuedStats.byBranch).length > 0}
							{#each Object.entries(issuedStats.byBranch) as [branchId, valueCounts]}
								<div class="branch-section">
									<h4>{branchMap[branchId] || (branchId === 'unassigned' ? getTranslation('mobile.purchaseVoucher.unassigned') : branchId)}</h4>
									{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, issueTypes]}
										{#each Object.entries(issueTypes) as [issueType, counts]}
											<div class="value-item">
												<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
												<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
											</div>
										{/each}
									{/each}
								</div>
							{/each}
						{:else}
							<p class="no-data">No issued vouchers</p>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Closed Vouchers Card -->
			<div class="status-card closed" on:click={() => showCard3Breakdown = !showCard3Breakdown}>
				<div class="card-header">
					<div class="card-icon">✅</div>
					<div class="card-info">
						<h3>{getTranslation('mobile.purchaseVoucher.closed')}</h3>
						<span class="card-count">{closedStats.totalVouchers}</span>
					</div>
					<span class="expand-icon">{showCard3Breakdown ? '▼' : '▶'}</span>
				</div>
				
				{#if !showCard3Breakdown}
					<div class="value-summary">
						{#if Object.keys(closedStats.byValue || {}).length > 0}
							{#each Object.entries(closedStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
								<div class="value-item">
									<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
									<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
								</div>
							{/each}
						{:else}
							<p class="no-data">{getTranslation('mobile.purchaseVoucher.noClosedVouchers')}</p>
						{/if}
					</div>
				{:else}
					<div class="branch-breakdown">
						{#if Object.keys(closedStats.byBranch).length > 0}
							{#each Object.entries(closedStats.byBranch) as [branchId, valueCounts]}
								<div class="branch-section">
									<h4>{branchMap[branchId] || (branchId === 'unassigned' ? getTranslation('mobile.purchaseVoucher.unassigned') : branchId)}</h4>
									{#each Object.entries(valueCounts).sort(([a], [b]) => Number(b) - Number(a)) as [value, issueTypes]}
										{#each Object.entries(issueTypes) as [issueType, counts]}
											<div class="value-item">
												<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
												<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
											</div>
										{/each}
									{/each}
								</div>
							{/each}
						{:else}
							<p class="no-data">{getTranslation('mobile.purchaseVoucher.noClosedVouchers')}</p>
						{/if}
					</div>
				{/if}
			</div>

			<!-- My Stock Card -->
			<div class="status-card my-stock" on:click={() => showCard4Breakdown = !showCard4Breakdown}>
				<div class="card-header">
					<div class="card-icon">👤</div>
					<div class="card-info">
						<h3>{getTranslation('mobile.purchaseVoucher.myStock')}</h3>
						<span class="card-count">{myStockStats.totalVouchers}</span>
					</div>
					<span class="expand-icon">{showCard4Breakdown ? '▼' : '▶'}</span>
				</div>
				
				{#if myStockStats.totalVouchers === 0}
					<div class="value-summary">
						<p class="no-data">{getTranslation('mobile.purchaseVoucher.noStockAssigned')}</p>
					</div>
				{:else}
					<div class="value-summary">
						{#each Object.entries(myStockStats.byValue).sort(([a], [b]) => Number(b) - Number(a)) as [value, counts]}
							<div class="value-item">
								<span class="value-label"><img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />{Number(value).toFixed(0)}</span>
								<span class="value-count">{counts.vouchers} pcs = <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />{(Number(value) * counts.vouchers).toLocaleString()}</span>
							</div>
							{#if showCard4Breakdown}
								<div class="breakdown-details">
									<span class="detail-item available-detail">📦 {getTranslation('mobile.purchaseVoucher.availableBreakdown')}: {counts.notIssued}</span>
									<span class="detail-item issued-detail">📤 {getTranslation('mobile.purchaseVoucher.issuedBreakdown')}: {counts.issued}</span>
								</div>
							{/if}
						{/each}
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.mobile-pv-manager {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		padding-bottom: 5rem;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		color: #6B7280;
	}

	.spinner {
		width: 20px;
		height: 20px;
		border: 2px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.spinner.large {
		width: 40px;
		height: 40px;
		border-width: 3px;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.status-cards {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding: 1rem;
	}

	.status-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		cursor: pointer;
		transition: all 0.2s;
		border-left: 4px solid transparent;
	}

	.status-card:active {
		transform: scale(0.98);
	}

	.status-card.available {
		border-left-color: #10B981;
	}

	.status-card.issued {
		border-left-color: #F59E0B;
	}

	.status-card.closed {
		border-left-color: #6B7280;
	}

	.status-card.my-stock {
		border-left-color: #3B82F6;
		background: linear-gradient(135deg, #EFF6FF 0%, white 100%);
	}

	.card-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.card-icon {
		font-size: 1.5rem;
	}

	.card-info {
		flex: 1;
	}

	.card-info h3 {
		margin: 0;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.card-count {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1F2937;
	}

	.expand-icon {
		color: #9CA3AF;
		font-size: 0.75rem;
	}

	.value-summary,
	.branch-breakdown {
		border-top: 1px solid #E5E7EB;
		padding-top: 0.75rem;
	}

	.value-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
		border-bottom: 1px solid #F3F4F6;
	}

	.value-item:last-child {
		border-bottom: none;
	}

	.value-label {
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		flex-direction: row;
	}

	:global([dir="rtl"]) .value-label {
		flex-direction: row-reverse;
	}

	.currency-icon {
		width: 12px;
		height: 12px;
		object-fit: contain;
	}

	.currency-icon-small {
		width: 9px;
		height: 9px;
		object-fit: contain;
		vertical-align: middle;
		margin-right: 2px;
	}

	:global([dir="rtl"]) .currency-icon-small {
		margin-right: 0;
		margin-left: 2px;
	}

	.value-count {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		color: #6B7280;
		font-size: 0.75rem;
	}

	:global([dir="rtl"]) .value-count {
		flex-direction: row-reverse;
	}

	.branch-section {
		margin-bottom: 1rem;
	}

	.branch-section:last-child {
		margin-bottom: 0;
	}

	.branch-section h4 {
		margin: 0 0 0.5rem 0;
		font-size: 0.75rem;
		font-weight: 600;
		color: #3B82F6;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.no-data {
		color: #9CA3AF;
		font-size: 0.875rem;
		text-align: center;
		padding: 1rem 0;
		margin: 0;
	}

	.breakdown-details {
		display: flex;
		gap: 1rem;
		padding: 0.25rem 0 0.5rem 0;
		margin-left: 1rem;
	}

	.detail-item {
		font-size: 0.7rem;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
	}

	.available-detail {
		background: #D1FAE5;
		color: #065F46;
	}

	.issued-detail {
		background: #FEF3C7;
		color: #92400E;
	}
</style>
