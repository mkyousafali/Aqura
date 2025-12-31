<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
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
				.select('id, name_en, name_ar, location_en, location_ar')
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
			if (offers.length > 0) {
				console.log('📋 First offer:', $state.snapshot(offers[0]));
				console.log('📋 File URL:', offers[0].file_url);
			}
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

	function openEditOfferWindow(offerId: string, offerName: string) {
		console.log('📝 Opening edit dialog for offer:', { offerId, offerName });
		const instanceNumber = Math.max(
			0,
			...Array.from(document.querySelectorAll('[data-window-type="EditOfferDialog"]')).map(el =>
				parseInt(el.getAttribute('data-instance') || '0')
			)
		) + 1;

		windowManager.openWindow({
			id: `edit-offer-${offerId}-${instanceNumber}`,
			title: `Edit Offer: ${offerName}`,
			component: AddOfferDialog,
			props: {
				offerId: String(offerId),
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



	function formatDate(dateString: string) {
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}/${month}/${year}`;
	}

	function isOfferExpired(endDate: string, endTime: string): boolean {
		const offerEnd = new Date(`${endDate}T${endTime}`);
		return new Date() > offerEnd;
	}

	function getRemainingTime(endDate: string, endTime: string): string {
		const offerEnd = new Date(`${endDate}T${endTime}`);
		const now = new Date();
		
		if (now > offerEnd) {
			return 'Expired';
		}

		const diffMs = offerEnd.getTime() - now.getTime();
		const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
		const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
		const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

		if (days > 0) {
			return `${days}d ${hours}h ${minutes}m`;
		} else if (hours > 0) {
			return `${hours}h ${minutes}m`;
		} else {
			return `${minutes}m`;
		}
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
			<div class="table-wrapper">
				<table class="offers-table">
					<thead>
						<tr>
							<th>Thumbnail</th>
							<th>Offer Name</th>
							<th>Branch</th>
							<th>Location</th>
							<th>Start Date</th>
							<th>End Date</th>
							<th>Time Range</th>
							<th>Status</th>
							<th>👁️ Views</th>
							<th>📄 Button Clicks</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each offers as offer (offer.id)}
							<tr>
								<td class="thumbnail-cell">
									{#if offer.thumbnail_url}
										<img src={offer.thumbnail_url} alt={offer.offer_name} class="offer-thumbnail" />
									{:else}
										<div class="no-thumbnail">No image</div>
									{/if}
								</td>
								<td class="offer-name">{offer.offer_name}</td>
								<td>
									{#each branches as branch}
										{#if branch.id === offer.branch_id}
											{getBranchName(branch)}
										{/if}
									{/each}
								</td>
								<td>
									{#each branches as branch}
										{#if branch.id === offer.branch_id}
											{$currentLocale === 'ar' ? branch.location_ar : branch.location_en || '—'}
										{/if}
									{/each}
								</td>
								<td>{formatDate(offer.start_date)}</td>
								<td>{formatDate(offer.end_date)}</td>
								<td>{convertTo12Hour(offer.start_time)} - {convertTo12Hour(offer.end_time)}</td>
								<td class="status-cell">
									{#if isOfferExpired(offer.end_date, offer.end_time)}
										<span class="status-badge expired">🔴 Expired</span>
									{:else}
										<span class="status-badge active">{getRemainingTime(offer.end_date, offer.end_time)}</span>
									{/if}
								</td>
								<td class="count-cell">
									<span class="count-badge">{offer.page_visit_count || 0}</span>
								</td>
								<td class="count-cell">
									<span class="count-badge">{offer.view_button_count || 0}</span>
								</td>
								<td class="action-cell">
									<div class="action-buttons">
										<button 
											class="edit-btn"
											on:click={() => openEditOfferWindow(offer.id, offer.offer_name)}
											title="Edit Offer"
										>
											✏️ Edit
										</button>
										{#if offer.file_url}
											<a 
												href={offer.file_url}
												target="_blank"
												rel="noopener noreferrer"
												class="view-btn"
												title="Open PDF"
											>
												📄 View
											</a>
										{/if}
									</div>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
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

	.table-wrapper {
		overflow-x: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.offers-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.offers-table thead {
		background: #f9fafb;
		border-bottom: 2px solid #e5e7eb;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.offers-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.offers-table tbody tr {
		border-bottom: 1px solid #e5e7eb;
		transition: all 0.2s ease;
	}

	.offers-table td {
		padding: 1rem;
		color: #1f2937;
		font-size: 0.95rem;
	}

	.thumbnail-cell {
		padding: 0.5rem;
		text-align: center;
	}

	.offer-thumbnail {
		width: 80px;
		height: 80px;
		object-fit: cover;
		border-radius: 6px;
		border: 1px solid #d1d5db;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.no-thumbnail {
		width: 80px;
		height: 80px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
		border-radius: 6px;
		border: 1px dashed #d1d5db;
		color: #9ca3af;
		font-size: 0.75rem;
	}

	.offer-name {
		font-weight: 600;
		color: #1f2937;
	}

	.status-cell {
		text-align: center;
	}

	.status-badge {
		display: inline-block;
		padding: 0.5rem 0.75rem;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.status-badge.expired {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-badge.active {
		background: #dcfce7;
		color: #166534;
	}

	.count-cell {
		text-align: center;
	}

	.count-badge {
		display: inline-block;
		padding: 0.5rem 1rem;
		background: #f0f9ff;
		border: 1px solid #bfdbfe;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		color: #0369a1;
	}

	.action-cell {
		text-align: center;
	}

	.action-buttons {
		display: flex;
		gap: 0.5rem;
		justify-content: center;
		flex-wrap: wrap;
	}

	.edit-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.5rem 0.9rem;
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fcd34d;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		text-decoration: none;
	}

	.edit-btn:hover {
		background: #fbbf24;
		color: #78350f;
		border-color: #f59e0b;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(251, 146, 60, 0.2);
	}

	.edit-btn:active {
		transform: translateY(0);
	}

	.view-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: #dbeafe;
		color: #0369a1;
		border: 1px solid #0ea5e9;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		text-decoration: none;
	}

	.view-btn:hover {
		background: #0369a1;
		color: white;
		border-color: #0369a1;
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(3, 105, 161, 0.2);
	}

	.view-btn:active {
		transform: translateY(0);
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.manager-content {
			padding: 1rem;
		}

		.offers-table th,
		.offers-table td {
			padding: 0.75rem 0.5rem;
			font-size: 0.85rem;
		}

		.table-wrapper {
			overflow-x: auto;
		}
	}
</style>
