<script lang="ts">
	import { supabase } from '\$lib/utils/supabase';
	import { onMount } from 'svelte';
	
	let offers: any[] = [];
	let isLoading: boolean = true;
	let showEditModal: boolean = false;
	let editingOffer: any = null;
	let isSaving: boolean = false;
	
	// Helper function to check if an offer is expired
	function isOfferExpired(endDate: string): boolean {
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		const offerEndDate = new Date(endDate);
		offerEndDate.setHours(0, 0, 0, 0);
		return offerEndDate < today;
	}
	
	// Helper function to format date as DD-MM-YYYY
	function formatDateDDMMYYYY(dateString: string): string {
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}-${month}-${year}`;
	}
	
	// Automatically deactivate offers that have passed their end date
	async function deactivateExpiredOffers() {
		try {
			const today = new Date();
			today.setHours(0, 0, 0, 0); // Set to start of day for accurate comparison
			
			// Get all active offers that have passed their end date
			const { data: expiredOffers, error: fetchError } = await supabase
				.from('flyer_offers')
				.select('id, template_name, end_date')
				.eq('is_active', true)
				.lt('end_date', today.toISOString());
			
			if (fetchError) {
				console.error('Error fetching expired offers:', fetchError);
				return;
			}
			
			if (expiredOffers && expiredOffers.length > 0) {
				console.log(`Found ${expiredOffers.length} expired offer(s), deactivating...`);
				
				// Deactivate all expired offers
				const { error: updateError } = await supabase
					.from('flyer_offers')
					.update({ is_active: false })
					.eq('is_active', true)
					.lt('end_date', today.toISOString());
				
				if (updateError) {
					console.error('Error deactivating expired offers:', updateError);
				} else {
					console.log(`Successfully deactivated ${expiredOffers.length} expired offer(s)`);
					expiredOffers.forEach(offer => {
						console.log(`- Deactivated: ${offer.template_name} (ended: ${new Date(offer.end_date).toLocaleDateString()})`);
					});
				}
			}
		} catch (error) {
			console.error('Error in deactivateExpiredOffers:', error);
		}
	}
	
	// Load all offers/templates from database
	async function loadOffers() {
		isLoading = true;
		
		// First, deactivate any expired offers
		await deactivateExpiredOffers();
		
		try {
			const { data, error } = await supabase
				.from('flyer_offers')
				.select(`
					*,
					offer_name:offer_names(id, name_en, name_ar)
				`)
				.order('created_at', { ascending: false });
			
			if (error) {
				console.error('Error loading offers:', error);
				alert('Error loading offers. Please try again.');
			} else {
				offers = data || [];
			}
		} catch (error) {
			console.error('Error loading offers:', error);
			alert('Error loading offers. Please try again.');
		}
		
		isLoading = false;
	}
	
	// Toggle offer active status
	async function toggleOfferStatus(offerId: string, currentStatus: boolean) {
		try {
			const { error } = await supabase
				.from('flyer_offers')
				.update({ is_active: !currentStatus })
				.eq('id', offerId);
			
			if (error) {
				console.error('Error updating offer status:', error);
				alert('Error updating offer status. Please try again.');
			} else {
				// Reload offers to reflect changes
				await loadOffers();
			}
		} catch (error) {
			console.error('Error updating offer status:', error);
			alert('Error updating offer status. Please try again.');
		}
	}
	
	// Delete offer
	async function deleteOffer(offerId: string, templateName: string) {
		if (!confirm(`Are you sure you want to delete "${templateName}"? This will also remove all associated products.`)) {
			return;
		}
		
		try {
			const { error } = await supabase
				.from('flyer_offers')
				.delete()
				.eq('id', offerId);
			
			if (error) {
				console.error('Error deleting offer:', error);
				alert('Error deleting offer. Please try again.');
			} else {
				alert('Offer deleted successfully!');
				await loadOffers();
			}
		} catch (error) {
			console.error('Error deleting offer:', error);
			alert('Error deleting offer. Please try again.');
		}
	}
	
	// Open edit modal
	function openEditModal(offer: any) {
		editingOffer = {
			id: offer.id,
			template_name: offer.template_name,
			start_date: offer.start_date.split('T')[0], // Get date part only
			end_date: offer.end_date.split('T')[0],
			offer_name_id: offer.offer_name_id
		};
		showEditModal = true;
	}
	
	// Close edit modal
	function closeEditModal() {
		showEditModal = false;
		editingOffer = null;
	}
	
	// Save edited offer
	async function saveEditedOffer() {
		if (!editingOffer || !editingOffer.id) return;
		
		isSaving = true;
		try {
			// Convert dates from YYYY-MM-DD format to ISO format with time
			const startDate = new Date(editingOffer.start_date);
			const endDate = new Date(editingOffer.end_date);
			
			const updateData: any = {
				start_date: startDate.toISOString(),
				end_date: endDate.toISOString()
			};
			
			// Add template_name if it was changed
			if (editingOffer.template_name) {
				updateData.template_name = editingOffer.template_name;
			}
			
			const { error } = await supabase
				.from('flyer_offers')
				.update(updateData)
				.eq('id', editingOffer.id);
			
			if (error) {
				console.error('Error saving offer:', error);
				alert('Error saving offer. Please try again.');
			} else {
				alert('Offer updated successfully!');
				closeEditModal();
				await loadOffers();
			}
		} catch (error) {
			console.error('Error saving offer:', error);
			alert('Error saving offer. Please try again.');
		} finally {
			isSaving = false;
		}
	}
	
	onMount(() => {
		loadOffers();
	});
</script>

<div class="space-y-6">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-3xl font-bold text-gray-800">Offer Manager</h1>
			<p class="text-gray-600 mt-1">Manage and activate/deactivate offer templates</p>
		</div>
		
		<button 
			on:click={loadOffers}
			disabled={isLoading}
			class="px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
		>
			<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
			</svg>
			Refresh
		</button>
	</div>

	<!-- Offers Table -->
	{#if isLoading}
		<div class="bg-white rounded-lg shadow-lg p-12 text-center">
			<svg class="animate-spin w-12 h-12 mx-auto text-blue-600 mb-4" fill="none" viewBox="0 0 24 24">
				<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
				<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
			</svg>
			<p class="text-gray-600">Loading offers...</p>
		</div>
	{:else if offers.length === 0}
		<div class="bg-white rounded-lg shadow-lg p-12 text-center">
			<svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
			</svg>
			<h3 class="text-xl font-semibold text-gray-800 mb-2">No Offers Found</h3>
			<p class="text-gray-600">Create offers from the Offer Product Selector page.</p>
		</div>
	{:else}
		<div class="bg-white rounded-lg shadow-lg overflow-hidden">
			<div class="overflow-x-auto">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-100">
						<tr>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Status
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Template ID
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Offer Name
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Template Name
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Start Date
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								End Date
							</th>
							<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Created At
							</th>
							<th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
								Actions
							</th>
						</tr>
					</thead>
					<tbody class="bg-white divide-y divide-gray-200">
						{#each offers as offer (offer.id)}
							<tr class="hover:bg-gray-50 transition-colors">
								<td class="px-6 py-4 whitespace-nowrap">
									{#if isOfferExpired(offer.end_date)}
										<span class="px-3 py-1 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
											Expired
										</span>
									{:else if offer.is_active}
										<span class="px-3 py-1 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
											Active
										</span>
									{:else}
										<span class="px-3 py-1 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">
											Inactive
										</span>
									{/if}
								</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-600">
									{offer.template_id}
								</td>
								<td class="px-6 py-4 text-sm text-gray-900">
									{#if offer.offer_name}
										<div class="font-semibold">{offer.offer_name.name_en}</div>
									{:else if offer.offer_name}
										<div class="font-semibold">{offer.offer_name}</div>
									{:else}
										<span class="text-gray-400 italic">—</span>
									{/if}
								</td>
								<td class="px-6 py-4 text-sm font-medium text-gray-900">
									{offer.template_name}
								</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
							{formatDateDDMMYYYY(offer.start_date)}
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm {isOfferExpired(offer.end_date) ? 'text-red-600 font-semibold' : 'text-gray-900'}">
							{formatDateDDMMYYYY(offer.end_date)}
								{#if isOfferExpired(offer.end_date)}
									<span class="ml-1 text-xs">(Expired)</span>
								{/if}
							</td>
								<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								{formatDateDDMMYYYY(offer.created_at)}
								</td>
							<td class="px-6 py-4 whitespace-nowrap text-center text-sm font-medium">
								<div class="flex items-center justify-center gap-2">
									<button
										on:click={() => toggleOfferStatus(offer.id, offer.is_active)}
										disabled={isOfferExpired(offer.end_date) && !offer.is_active}
										class="px-3 py-1 rounded-lg transition-colors {isOfferExpired(offer.end_date) && !offer.is_active ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : (offer.is_active ? 'bg-red-100 text-red-700 hover:bg-red-200' : 'bg-green-100 text-green-700 hover:bg-green-200')}"
										title={isOfferExpired(offer.end_date) && !offer.is_active ? 'Cannot activate expired offer' : (offer.is_active ? 'Deactivate' : 'Activate')}
									>
											{#if offer.is_active}
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
												</svg>
											{:else}
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
												</svg>
											{/if}
										</button>
										
										<button
											on:click={() => openEditModal(offer)}
											class="px-3 py-1 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors"
											title="Edit"
										>
											<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
											</svg>
										</button>
										
										<button
											on:click={() => deleteOffer(offer.id, offer.template_name)}
											class="px-3 py-1 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
											title="Delete"
										>
											<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
											</svg>
										</button>
									</div>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
		
		<!-- Summary Stats -->
		<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm text-gray-600">Total Templates</p>
						<p class="text-3xl font-bold text-gray-800">{offers.length}</p>
					</div>
					<div class="bg-blue-100 rounded-full p-3">
						<svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
						</svg>
					</div>
				</div>
			</div>
			
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm text-gray-600">Active Templates</p>
						<p class="text-3xl font-bold text-green-600">{offers.filter(o => o.is_active).length}</p>
					</div>
					<div class="bg-green-100 rounded-full p-3">
						<svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
					</div>
				</div>
			</div>
			
			<div class="bg-white rounded-lg shadow-md p-6">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm text-gray-600">Inactive Templates</p>
						<p class="text-3xl font-bold text-red-600">{offers.filter(o => !o.is_active).length}</p>
					</div>
					<div class="bg-red-100 rounded-full p-3">
						<svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- Edit Modal -->
{#if showEditModal && editingOffer}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
		<div class="bg-white rounded-lg shadow-2xl max-w-md w-full mx-4">
			<div class="flex items-center justify-between p-6 border-b border-gray-200">
				<h2 class="text-xl font-bold text-gray-800">Edit Offer</h2>
				<button
					on:click={closeEditModal}
					class="text-gray-400 hover:text-gray-600 transition-colors"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>
			
			<div class="p-6 space-y-4">
				<!-- Template Name -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Template Name
					</label>
					<input
						type="text"
						bind:value={editingOffer.template_name}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						placeholder="Enter template name"
					/>
				</div>
				
				<!-- Start Date -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Start Date
					</label>
					<input
						type="date"
						bind:value={editingOffer.start_date}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
				
				<!-- End Date -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						End Date
					</label>
					<input
						type="date"
						bind:value={editingOffer.end_date}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
			</div>
			
			<div class="flex gap-3 p-6 border-t border-gray-200">
				<button
					on:click={closeEditModal}
					class="flex-1 px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium"
				>
					Cancel
				</button>
				<button
					on:click={saveEditedOffer}
					disabled={isSaving}
					class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
				>
					{#if isSaving}
						<svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Saving...
					{:else}
						Save Changes
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}
