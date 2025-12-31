<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { _, currentLocale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { sanitizeText } from '$lib/utils/sanitize';
	import { onMount } from 'svelte';

	let state = $state({
		offers: [] as any[],
		branches: [] as any[],
		selectedBranchId: '',
		isLoading: true,
		dataLoaded: false,
		downloadingOfferId: null as string | null,
		downloadProgress: 0,
		fileCache: new Map<string, Blob>()
	});

	onMount(async () => {
		await fetchData();
	});

	async function fetchData() {
		try {
			state.isLoading = true;
			
			// Fetch all active offers
			const now = new Date();
			const currentDate = now.toISOString().split('T')[0];
			const currentTime = now.toTimeString().split(' ')[0].substring(0, 5);

			const { data: offerData, error: offerError } = await supabase
				.from('view_offer')
				.select('*')
				.gte('end_date', currentDate)
				.order('created_at', { ascending: false });

			if (offerError) throw offerError;
			
			// Filter out expired offers - only show active/future offers
			state.offers = (offerData || []).filter(offer => {
				// If end date is in the future, it's active
				if (offer.end_date > currentDate) return true;
				
				// If end date is today, check if end time hasn't passed
				if (offer.end_date === currentDate) {
					// Compare times: if current time is before or equal to end time, show it
					return offer.end_time > currentTime;
				}
				
				// Any other case (past dates), don't show
				return false;
			});

			// Get unique branch IDs from offers
			const branchIdsWithOffers = new Set(state.offers.map(o => o.branch_id));
			const branchIdsArray = Array.from(branchIdsWithOffers);

			// Fetch only branches that have active offers
			let branchQuery = supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true);

			// Only apply filter if there are branches with offers
			if (branchIdsArray.length > 0) {
				branchQuery = branchQuery.in('id', branchIdsArray);
			}

			const { data: branchData, error: branchError } = await branchQuery.order('name_en');

			if (branchError) throw branchError;
			
			// Assign branches with sanitized names
			state.branches = (branchData || []).map(branch => ({
				...branch,
				name_en: sanitizeText(branch.name_en),
				name_ar: sanitizeText(branch.name_ar),
				location_en: sanitizeText(branch.location_en),
				location_ar: sanitizeText(branch.location_ar)
			}));
			
			// Enrich offers with branch information
			state.offers = state.offers.map(offer => {
				const branch = state.branches.find(b => b.id === offer.branch_id);
				return {
					...offer,
					branch_name_en: sanitizeText(branch?.name_en || ''),
					branch_name_ar: sanitizeText(branch?.name_ar || ''),
					branch_location_en: sanitizeText(branch?.location_en || ''),
					branch_location_ar: sanitizeText(branch?.location_ar || '')
				};
			});

		} catch (error) {
			console.error('Error fetching offers:', error);
		} finally {
			state.dataLoaded = true;
			state.isLoading = false;
			// Increment page visit count for all offers once data is loaded
			await incrementAllOfferPageVisits();
		}
	}

	function getBranchName(branchId: number) {
		const branch = state.branches.find(b => b.id === branchId);
		if (!branch) return '';
		return $currentLocale === 'ar' ? branch.name_ar : branch.name_en;
	}

	function handleBranchChange(event: Event) {
		const target = event.target as HTMLSelectElement;
		const value = target.value;
		state.selectedBranchId = value;
	}

	function getFilteredOffers() {
		// If no branch selected, return all offers
		if (!state.selectedBranchId) {
			return state.offers;
		}
		// If branch selected, filter offers by that branch
		const branchId = parseInt(state.selectedBranchId);
		const filtered = state.offers.filter(offer => offer.branch_id === branchId);
		return filtered;
	}

	function openOfferFile(fileUrl: string, offerId: string) {
		if (fileUrl) {
			// Increment view button count
			incrementViewButtonCount(offerId);
			
			state.downloadingOfferId = offerId;
			state.downloadProgress = 0;
			
			// Check if file is already cached
			if (state.fileCache.has(offerId)) {
				// Open from cache instantly
				const cachedBlob = state.fileCache.get(offerId);
				const blobUrl = URL.createObjectURL(cachedBlob!);
				window.open(blobUrl, `offer_${offerId}`);
				state.downloadingOfferId = null;
				state.downloadProgress = 0;
				return;
			}
			
			// Fetch and cache the file with progress tracking
			fetch(fileUrl)
				.then(response => {
					// Get total file size
					const contentLength = response.headers.get('content-length');
					const total = parseInt(contentLength || '0', 10);
					
					if (!response.body) throw new Error('No response body');
					
					const reader = response.body.getReader();
					const chunks: Uint8Array[] = [];
					let loaded = 0;
					
					return reader.read().then(function processChunk(result): Promise<Blob> {
						if (result.done) {
							const blob = new Blob(chunks, { type: 'application/pdf' });
							return Promise.resolve(blob);
						}
						
						const chunk = result.value;
						chunks.push(chunk);
						loaded += chunk.length;
						
						// Update progress percentage
						if (total > 0) {
							state.downloadProgress = Math.round((loaded / total) * 100);
						}
						
						return reader.read().then(processChunk);
					});
				})
				.then(blob => {
					// Cache the blob
					state.fileCache.set(offerId, blob);
					
					// Open the cached file
					const blobUrl = URL.createObjectURL(blob);
					window.open(blobUrl, `offer_${offerId}`);
				})
				.catch(error => {
					console.error('Error loading file:', error);
					// Fallback: open directly
					window.open(fileUrl, `offer_${offerId}`);
				})
				.finally(() => {
					state.downloadingOfferId = null;
					state.downloadProgress = 0;
				});
		}
	}

	function formatDate(dateStr: string): string {
		const [year, month, day] = dateStr.split('-');
		return `${day}/${month}/${year}`;
	}

	function convertTo12Hour(time24: string): string {
		const [hours, minutes] = time24.split(':');
		const hour = parseInt(hours);
		const period = hour >= 12 ? 'PM' : 'AM';
		const hour12 = hour % 12 || 12;
		return `${hour12.toString().padStart(2, '0')}:${minutes} ${period}`;
	}

	function getRemainingDays(endDate: string, endTime: string): string {
		const now = new Date();
		const currentDate = now.toISOString().split('T')[0];
		const currentTime = now.toTimeString().split(' ')[0].substring(0, 5);

		const end = new Date(`${endDate}T${endTime}`);
		const current = new Date(`${currentDate}T${currentTime}`);
		const diffMs = end.getTime() - current.getTime();
		
		const isArabic = $currentLocale === 'ar';
		
		if (diffMs < 0) {
			return isArabic ? '⏰ منتهي' : '⏰ Expired';
		}
		
		const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
		const diffHours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
		const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

		if (isArabic) {
			if (diffDays === 0 && diffHours === 0) {
				return `⏰ ينتهي في ${diffMinutes} دقيقة`;
			}
			if (diffDays === 0) {
				const hourLabel = diffHours === 1 ? 'ساعة' : 'ساعات';
				const minLabel = diffMinutes === 1 ? 'دقيقة' : 'دقائق';
				return `⏰ ينتهي في ${diffHours} ${hourLabel} و${diffMinutes} ${minLabel}`;
			}
			const dayLabel = diffDays === 1 ? 'يوم' : 'أيام';
			const hourLabel = diffHours === 1 ? 'ساعة' : 'ساعات';
			return `⏰ ينتهي في ${diffDays} ${dayLabel} و${diffHours} ${hourLabel}`;
		} else {
			if (diffDays === 0 && diffHours === 0) {
				return `⏰ Expires in ${diffMinutes} minutes`;
			}
			if (diffDays === 0) {
				return `⏰ Expires in ${diffHours}h ${diffMinutes}m`;
			}
			return `⏰ Expires in ${diffDays}d ${diffHours}h`;
		}
	}

	function goBack() {
		// If referrer is login, go back there, otherwise go to home
		const referrer = $page.url.searchParams.get('referrer');
		if (referrer === 'login') {
			goto('/login/customer');
		} else {
			goto('/');
		}
	}

	function toggleLanguage() {
		currentLocale.set($currentLocale === 'en' ? 'ar' : 'en');
	}

	async function incrementViewButtonCount(offerId: string) {
		try {
			const { error } = await supabase
				.rpc('increment_view_button_count', { offer_id: offerId });
			if (error) console.error('Error incrementing view button count:', error);
		} catch (error) {
			console.error('Error:', error);
		}
	}

	async function incrementPageVisitCount(offerId: string) {
		try {
			const { error } = await supabase
				.rpc('increment_page_visit_count', { offer_id: offerId });
			if (error) console.error('Error incrementing page visit count:', error);
		} catch (error) {
			console.error('Error:', error);
		}
	}

	async function incrementAllOfferPageVisits() {
		try {
			// Increment page visit count for all visible offers
			for (const offer of state.offers) {
				await incrementPageVisitCount(String(offer.id));
			}
		} catch (error) {
			console.error('Error incrementing page visits:', error);
		}
	}
</script>

<svelte:head>
	<title>Latest Offers - Aqura</title>
	<meta name="description" content="View the latest offers from Aqura" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<div class="offers-page">
	<header class="offers-header">
		<button class="back-btn" onclick={goBack} title="Back">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
		</button>
		<button 
			class="lang-btn" 
			onclick={toggleLanguage}
			title="Toggle Language"
		>
			{$currentLocale === 'en' ? 'العربية' : 'English'}
		</button>
	</header>

	<main class="offers-content">
		{#if state.isLoading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
				<p class="thank-you-message">{$currentLocale === 'ar' ? 'شكراً على صبرك' : 'Thank you for patience'}</p>
			</div>
		{:else if state.dataLoaded}
			<div class="logo-wrapper">
				<div class="logo-container">
					<img src="/icons/logo.png" alt="Aqura Logo" class="app-logo" />
				</div>
			</div>

			<div class="offers-grid">
				{#if getFilteredOffers().length === 0}
					<div class="no-offers">
						<p>{$currentLocale === 'ar' ? 'لا توجد عروض متاحة' : 'No offers available'}</p>
					</div>
				{:else}
					{#each getFilteredOffers() as offer (offer.id)}
							<div class="offer-card">
								<div class="offer-header">
									<h3 class="offer-name">{offer.offer_name}</h3>
									<div class="branch-info">
										<span class="branch-name">{$currentLocale === 'ar' ? offer.branch_name_ar : offer.branch_name_en}</span>
										<span class="branch-location">{$currentLocale === 'ar' ? offer.branch_location_ar : offer.branch_location_en}</span>
									</div>
									<div class="offer-details">
										<div class="detail-item">
											<span class="label">{getRemainingDays(offer.end_date, offer.end_time)}</span>
										</div>
									</div>
								</div>
								{#if offer.thumbnail_url}
									<div class="thumbnail-container">
										<img 
											src={offer.thumbnail_url} 
											alt={offer.offer_name}
											class="offer-thumbnail"
										/>
									</div>
								{/if}
								{#if offer.file_url}
									<div class="file-container">
										<button 
											class="view-offer-btn"
											onclick={() => openOfferFile(offer.file_url, offer.id)}
											disabled={state.downloadingOfferId === offer.id}
										>
											{#if state.downloadingOfferId === offer.id}
												<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="spinner-icon">
													<circle cx="12" cy="12" r="10"></circle>
													<path d="M12 6v6l4 2"></path>
												</svg>
											<span>{state.downloadProgress}%</span>
											{:else}
												<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
													<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
													<circle cx="12" cy="12" r="3"></circle>
												</svg>
												<span>{$currentLocale === 'ar' ? 'اعرض المجلة' : 'View Magazine'}</span>
											{/if}
										</button>
										{#if state.downloadingOfferId === offer.id}
											<p class="loading-message">{$currentLocale === 'ar' ? 'شكراً على صبرك' : 'Thank you for patience'}</p>
										{/if}
									</div>
								{:else}
									<div class="no-file-container">
										<p>{$currentLocale === 'ar' ? 'بدون ملف' : 'No file available'}</p>
									</div>
								{/if}
							</div>
						{/each}
					{/if}
				</div>
		{/if}
	</main>
</div>

<style>
	.offers-page {
		width: 100%;
		min-height: 100vh;
		background: #FFFFFF;
		display: flex;
		flex-direction: column;
	}

	.offers-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		background: linear-gradient(135deg, #F97316 0%, #FB923C 100%);
		color: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		gap: 1rem;
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 20;
	}

	.back-btn,
	.lang-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: 40px;
		height: 40px;
		padding: 0 0.75rem;
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		-webkit-tap-highlight-color: transparent;
		pointer-events: auto;
		z-index: 21;
	}

	.back-btn:hover,
	.lang-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		border-color: rgba(255, 255, 255, 0.5);
	}

	.back-btn:active,
	.lang-btn:active {
		background: rgba(255, 255, 255, 0.25);
		transform: scale(0.95);
	}

	.offers-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
		max-width: 100%;
	}

	@media (max-width: 768px) {
		.offers-content {
			padding: 1rem;
		}
	}

	@media (max-width: 480px) {
		.offers-content {
			padding: 0.75rem;
		}
	}

	.logo-wrapper {
		display: flex;
		justify-content: center;
		margin-bottom: 2rem;
		margin-top: 90px;
		padding: 1.5rem 0;
		background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, rgba(249, 115, 22, 0.05) 100%);
		border-radius: 16px;
		border: 2px solid rgba(16, 185, 129, 0.15);
		animation: fadeInUp 0.8s ease-out;
		position: relative;
		overflow: hidden;
	}

	.logo-wrapper::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 2px;
		background: linear-gradient(90deg, transparent, #10B981, #F97316, transparent);
		animation: shimmer 3s ease-in-out infinite;
	}

	@keyframes fadeInUp {
		from {
			opacity: 0;
			transform: translateY(-30px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@keyframes shimmer {
		0%, 100% {
			opacity: 0.3;
		}
		50% {
			opacity: 1;
		}
	}

	.logo-container {
		display: flex;
		justify-content: center;
		position: relative;
		z-index: 1;
	}

	.app-logo {
		max-width: 120px;
		height: auto;
		filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.1));
		animation: slideDown 0.6s ease-out, pulse 3s ease-in-out infinite;
		transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
	}

	.app-logo:hover {
		transform: scale(1.1);
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			transform: translateY(-20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@keyframes pulse {
		0%, 100% {
			filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.1));
		}
		50% {
			filter: drop-shadow(0 8px 16px rgba(16, 185, 129, 0.3));
		}
	}

	.branch-selector-container {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 2rem;
		position: relative;
		z-index: 5;
	}

	.branch-selector-container label {
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.branch-select {
		padding: 0.75rem;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		font-size: 1rem;
		background: white;
		color: #111827;
		cursor: pointer;
		transition: all 0.3s ease;
		width: 100%;
		pointer-events: auto;
		appearance: auto;
		-webkit-appearance: auto;
		-moz-appearance: auto;
		position: relative;
		z-index: 6;
	}

	.branch-select:hover {
		border-color: #8B5CF6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.branch-select:focus {
		outline: none;
		border-color: #8B5CF6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 300px;
		gap: 1rem;
	}

	.thank-you-message {
		font-size: 1rem;
		color: #374151;
		font-weight: 600;
		margin-top: 1rem;
		animation: fadeIn 1s ease-in 0.5s both;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid rgba(139, 92, 246, 0.1);
		border-top-color: #8B5CF6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.offers-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.offers-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
		gap: 1.5rem;
		position: relative;
		z-index: 1;
	}

	@media (max-width: 768px) {
		.offers-grid {
			grid-template-columns: 1fr;
			gap: 1rem;
		}
	}

	@media (max-width: 480px) {
		.offers-grid {
			grid-template-columns: 1fr;
			gap: 0.75rem;
		}
	}

	.offer-card {
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, #FFFFFF 0%, #F0FDF4 100%);
		border: 2px solid #10B981;
		border-radius: 16px;
		overflow: hidden;
		transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
		box-shadow: 0 8px 16px rgba(16, 185, 129, 0.15), 0 2px 4px rgba(0, 0, 0, 0.05);
		position: relative;
		z-index: 1;
		animation: slideUp 0.6s ease-out;
	}

	.thumbnail-container {
		width: 100%;
		height: auto;
		max-height: none;
		overflow: hidden;
		background: #f0f0f0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.offer-thumbnail {
		width: 100%;
		height: auto;
		display: block;
		max-width: 100%;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.offer-card::before {
		content: '';
		position: absolute;
		top: -2px;
		left: 50%;
		transform: translateX(-50%);
		width: 60px;
		height: 20px;
		background: linear-gradient(135deg, #F97316 0%, #FB923C 100%);
		border-radius: 0 0 10px 10px;
		z-index: 10;
		box-shadow: 0 4px 6px rgba(249, 115, 22, 0.2);
	}

	.offer-card:hover {
		border-color: #F97316;
		box-shadow: 0 16px 32px rgba(249, 115, 22, 0.25), 0 4px 8px rgba(0, 0, 0, 0.1);
		transform: translateY(-8px);
	}

	.offer-card:hover::before {
		animation: ribbon 0.8s ease-in-out infinite;
	}

	@keyframes ribbon {
		0%, 100% {
			transform: translateX(-50%) scaleY(1);
		}
		50% {
			transform: translateX(-50%) scaleY(1.1);
		}
	}

	.offer-header {
		padding: 1.5rem 1.25rem 1.25rem 1.25rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border-bottom: none;
		position: relative;
	}

	@media (max-width: 480px) {
		.offer-header {
			padding: 1.25rem 1rem 1rem 1rem;
		}
	}

	.offer-header::after {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 3px;
		background: linear-gradient(90deg, #F97316 0%, #FB923C 50%, #F97316 100%);
	}

	.offer-name {
		margin: 0 0 0.5rem 0;
		font-size: 1.2rem;
		font-weight: 700;
		word-break: break-word;
		color: #FFFFFF !important;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	@media (max-width: 480px) {
		.offer-name {
			font-size: 1.05rem;
		}
	}

	.branch-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		margin-bottom: 0.75rem;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid rgba(255, 255, 255, 0.3);
		animation: fadeIn 0.8s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.branch-name {
		font-size: 0.95rem;
		font-weight: 600;
		color: #FFFFFF;
		letter-spacing: 0.3px;
	}

	.branch-location {
		font-size: 0.8rem;
		color: rgba(255, 255, 255, 0.85);
		opacity: 0.95;
	}

	.offer-details {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		font-size: 0.9rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.detail-item .label {
		font-weight: 500;
		opacity: 0.95;
		color: #E5E7EB;
	}

	.detail-item .value {
		opacity: 0.9;
		font-size: 0.85rem;
		color: #F3F4F6;
	}

	.file-container {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		min-height: 200px;
		background: linear-gradient(135deg, #ECFDF5 0%, #F0FDF4 100%);
		gap: 1rem;
	}

	@media (max-width: 480px) {
		.file-container {
			padding: 1.5rem 1rem;
			min-height: 150px;
		}
	}

	.view-offer-btn {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.875rem 1.75rem;
		background: linear-gradient(135deg, #F97316 0%, #FB923C 100%);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
		box-shadow: 0 6px 20px rgba(249, 115, 22, 0.4), 0 2px 4px rgba(0, 0, 0, 0.1);
		position: relative;
		z-index: 2;
		pointer-events: auto;
		letter-spacing: 0.5px;
	}

	@media (max-width: 480px) {
		.view-offer-btn {
			padding: 0.75rem 1.25rem;
			font-size: 0.9rem;
			gap: 0.5rem;
		}
	}

	.view-offer-btn:hover {
		transform: translateY(-4px) scale(1.05);
		box-shadow: 0 10px 28px rgba(249, 115, 22, 0.5), 0 4px 8px rgba(0, 0, 0, 0.15);
	}

	.view-offer-btn:active {
		transform: translateY(-2px) scale(0.98);
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.3);
	}

	.loading-message {
		font-size: 0.95rem;
		color: #374151;
		font-weight: 600;
		margin: 0;
		animation: fadeIn 0.6s ease-in 0.3s both;
	}

	.view-offer-btn:disabled {
		opacity: 0.8;
		cursor: not-allowed;
	}

	.view-offer-btn svg {
		width: 20px;
		height: 20px;
	}

	.view-offer-btn .spinner-icon {
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

	.no-file-container {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		background: #F9FAFB;
		color: #9CA3AF;
		text-align: center;
		padding: 2rem;
	}

	.offer-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		transition: all 0.3s ease;
	}

	.offer-item:hover {
		border-color: #8B5CF6;
		box-shadow: 0 2px 8px rgba(139, 92, 246, 0.1);
	}

	.offer-name {
		font-size: 1rem;
		font-weight: 600;
		color: #111827;
		flex: 1;
	}

	.view-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.view-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);
	}

	.view-btn:active {
		transform: translateY(0);
	}

	.no-file {
		font-size: 0.875rem;
		color: #9CA3AF;
		font-weight: 500;
	}

	.no-offers {
		text-align: center;
		padding: 2rem;
		color: #6B7280;
	}

	/* Mobile Responsive */
	@media (max-width: 768px) {
		.offers-header {
			padding: 0.875rem;
			gap: 0.75rem;
		}

		.offers-header h1 {
			font-size: 1.25rem;
		}

		.back-btn {
			width: 36px;
			height: 36px;
			font-size: 0.75rem;
		}

		.lang-btn {
			width: auto;
			min-width: 70px;
			height: 36px;
			font-size: 0.75rem;
			padding: 0 0.75rem;
		}

		.offers-content {
			padding: 1rem;
		}

		.offer-item {
			flex-direction: column;
			align-items: flex-start;
			gap: 0.75rem;
		}

		.view-btn {
			width: 100%;
			justify-content: center;
		}
	}

	@media (max-width: 480px) {
		.offers-header {
			padding: 0.75rem;
		}

		.offers-header h1 {
			font-size: 1.125rem;
		}

		.lang-btn {
			width: auto;
			min-width: 65px;
		}

		.offers-content {
			padding: 0.75rem;
		}
	}

	/* Dark mode support - DISABLED to match desktop light theme on all devices */
	/* @media (prefers-color-scheme: dark) {
		.offers-page {
			background: #1F2937;
			color: #F3F4F6;
		}

		.branch-select {
			background: #374151;
			color: #F3F4F6;
			border-color: #4B5563;
		}

		.offer-item {
			background: #374151;
			border-color: #4B5563;
		}

		.offer-name {
			color: #F3F4F6;
		}
	} */

	/* RTL Support */
	:global([dir="rtl"]) .offers-header {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"]) .offers-header h1 {
		text-align: center;
	}

	:global([dir="rtl"]) .offer-item {
		flex-direction: row-reverse;
	}
</style>
