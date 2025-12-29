<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import OpenOfferDetail from './OpenOfferDetail.svelte';
	import AddOfferDialog from './AddOfferDialog.svelte';

	interface Props {
		windowId?: string;
	}

	let { windowId = '' }: Props = $props();

	let branches: any[] = [];
	let offers: any[] = $state([]);
	let isFetchingOffers = false;

	onMount(async () => {
		await fetchBranches();
		await fetchOffers();
	});

	async function fetchBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error fetching branches:', error);
		}
	}

	async function fetchOffers() {
		isFetchingOffers = true;
		try {
			const { data, error } = await supabase
				.from('view_offer')
				.select('*')
				.order('created_at', { ascending: false });

			if (error) throw error;
			// Use spread operator to ensure reactivity in Svelte 5
			offers = [...(data || [])];
		} catch (error) {
			console.error('Error fetching offers:', error);
		} finally {
			isFetchingOffers = false;
		}
	}

	function getBranchName(branch: any) {
		return $currentLocale === 'ar' ? branch.name_ar : branch.name_en;
	}

	function openAddOfferWindow() {
		const instanceNumber = Math.max(
			0,
			...Array.from(document.querySelectorAll('[data-window-type="AddOfferDialog"]')).map(el =>
				parseInt(el.getAttribute('data-instance') || '0')
			)
		) + 1;

		windowManager.openWindow({
			id: `add-offer-${instanceNumber}`,
			title: 'Add New Offer',
			component: AddOfferDialog,
			props: {
				onOfferAdded: fetchOffers
			},
			width: 700,
			height: 700,
			x: 150 + instanceNumber * 20,
			y: 150 + instanceNumber * 20,
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openOfferInWindow(offerId: string, offerName: string) {
		console.log('🪟 Opening offer window with ID:', offerId, 'Name:', offerName);
		const instanceNumber = Math.max(
			0,
			...Array.from(document.querySelectorAll('[data-window-type="OpenOfferDetail"]')).map(el =>
				parseInt(el.getAttribute('data-instance') || '0')
			)
		) + 1;

		windowManager.openWindow({
			id: `offer-detail-${offerId}-${instanceNumber}`,
			title: `View Offer: ${offerName}`,
			component: OpenOfferDetail,
			props: {
				offerId: offerId,
				offerName: offerName
			},
			width: 800,
			height: 600,
			x: 200 + instanceNumber * 20,
			y: 200 + instanceNumber * 20,
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}



	function formatDate(dateString: string) {
		const date = new Date(dateString);
		return date.toLocaleDateString($currentLocale === 'ar' ? 'ar-SA' : 'en-US');
	}

	function convertTo12Hour(time24: string): string {
		if (!time24) return '';
		const [hours, minutes] = time24.split(':');
		let hour = parseInt(hours);
		const min = minutes;
		const period = hour >= 12 ? 'PM' : 'AM';
		if (hour > 12) hour -= 12;
		if (hour === 0) hour = 12;
		return `${String(hour).padStart(2, '0')}:${min} ${period}`;
	}

	function convertTo24Hour(time12: string): string {
		if (!time12) return '';
		const [time, period] = time12.split(' ');
		let [hours, minutes] = time.split(':');
		let hour = parseInt(hours);
		
		if (period === 'PM' && hour !== 12) hour += 12;
		if (period === 'AM' && hour === 12) hour = 0;
		
		return `${String(hour).padStart(2, '0')}:${minutes}`;
	}

	function convert12HourTo24Hour(hour: string, period: string): string {
		let h = parseInt(hour);
		if (period === 'PM' && h !== 12) h += 12;
		if (period === 'AM' && h === 12) h = 0;
		return String(h).padStart(2, '0');
	}
</script>

<div class="view-offer-manager">
	<div class="toolbar">
		<button class="add-offer-btn" on:click={openAddOfferWindow}>
			<span class="btn-icon">➕</span>
			Add Offer
		</button>
	</div>
	<main class="manager-content">
		{#if isFetchingOffers}
			<div class="loading-state">
				<div class="spinner"></div>
				<p>Loading offers...</p>
			</div>
		{:else if offers.length === 0}
			<div class="empty-state">
				<div class="empty-icon">📋</div>
				<p>No offers yet</p>
				<p class="text-muted">Click "Add Offer" to create your first offer</p>
			</div>
		{:else}
			<div class="offers-list">
				{#each offers as offer (offer.id)}
					<div class="offer-card" on:click={() => openOfferInWindow(offer.id, offer.offer_name)}>
						<div class="offer-header-card">
							<h3>{offer.offer_name}</h3>
							<span class="offer-date">
								{formatDate(offer.start_date)}
								{#if offer.start_date !== offer.end_date}
									- {formatDate(offer.end_date)}
								{/if}
							</span>
						</div>
						<div class="offer-body-card">
							<p class="branch-info">
								<span class="label">Branch:</span>
								<span class="value">
									{#each branches as branch}
										{#if branch.id === offer.branch_id}
											{getBranchName(branch)}
										{/if}
									{/each}
								</span>
							</p>
							<p class="time-info">
								<span class="label">Time:</span>
								<span class="value">{convertTo12Hour(offer.start_time)} - {convertTo12Hour(offer.end_time)}</span>
							</p>
						</div>
						<div class="offer-footer-card">
							<span class="click-hint">Click to view details</span>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</main>
</div>

<style>
	.view-offer-manager {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: white;
		overflow: hidden;
	}

	.toolbar {
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		gap: 0.75rem;
	}

	.add-offer-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.add-offer-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.add-offer-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-icon {
		font-size: 1.2rem;
	}

	.manager-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
	}

	.loading-state,
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 1rem;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top-color: #10b981;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.empty-icon {
		font-size: 3rem;
	}

	.empty-state p {
		margin: 0;
		font-size: 1rem;
		color: #6b7280;
	}

	.text-muted {
		color: #9ca3af;
		font-size: 0.875rem;
	}

	.offers-list {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 1.25rem;
	}

	.offer-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1.25rem;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		flex-direction: column;
		height: 100%;
	}

	.offer-card:hover {
		border-color: #10b981;
		box-shadow: 0 8px 16px rgba(16, 185, 129, 0.15);
		transform: translateY(-4px);
	}

	.offer-header-card {
		margin-bottom: 1rem;
		border-bottom: 1px solid #e5e7eb;
		padding-bottom: 1rem;
	}

	.offer-header-card h3 {
		margin: 0 0 0.5rem 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: #1f2937;
		line-height: 1.4;
	}

	.offer-date {
		display: inline-block;
		font-size: 0.875rem;
		color: #6b7280;
	}

	.offer-body-card {
		flex: 1;
		margin-bottom: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.branch-info,
	.time-info {
		margin: 0;
		display: flex;
		gap: 0.5rem;
		font-size: 0.9rem;
	}

	.branch-info .label,
	.time-info .label {
		font-weight: 600;
		color: #6b7280;
		min-width: 60px;
	}

	.branch-info .value,
	.time-info .value {
		color: #1f2937;
	}

	.offer-footer-card {
		padding-top: 0.75rem;
		border-top: 1px solid #e5e7eb;
	}

	.click-hint {
		font-size: 0.8rem;
		color: #10b981;
		font-weight: 600;
		font-style: italic;
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.manager-content {
			padding: 1rem;
		}

		.offers-list {
			grid-template-columns: 1fr;
		}
	}
</style>
