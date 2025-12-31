<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { localeData, isRTL } from '$lib/i18n';
	import OfferBadge from './OfferBadge.svelte';

	export let offers: any[] = [];
	export let autoRotate: boolean = true;
	export let rotationInterval: number = 3000; // 3 seconds per offer

	let currentIndex = 0;
	let intervalId: any = null;
	let touchStartX = 0;
	let touchEndX = 0;
	let isTransitioning = false;

	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		
		return typeof value === 'string' ? value : keyPath;
	}

	// Get localized offer name
	function getOfferName(offer: any): string {
		return $isRTL ? offer.name_ar : offer.name_en;
	}

	// Get localized offer description
	function getOfferDescription(offer: any): string {
		return $isRTL ? offer.description_ar : offer.description_en;
	}

	// Auto-rotation logic
	function startAutoRotation() {
		if (!autoRotate || offers.length <= 1) return;
		
		intervalId = setInterval(() => {
			nextSlide();
		}, rotationInterval);
	}

	function stopAutoRotation() {
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
	}

	function nextSlide() {
		if (isTransitioning) return;
		isTransitioning = true;
		currentIndex = (currentIndex + 1) % offers.length;
		setTimeout(() => {
			isTransitioning = false;
		}, 500);
	}

	function prevSlide() {
		if (isTransitioning) return;
		isTransitioning = true;
		currentIndex = (currentIndex - 1 + offers.length) % offers.length;
		setTimeout(() => {
			isTransitioning = false;
		}, 500);
	}

	function goToSlide(index: number) {
		if (isTransitioning || index === currentIndex) return;
		isTransitioning = true;
		currentIndex = index;
		setTimeout(() => {
			isTransitioning = false;
		}, 500);
		stopAutoRotation();
		startAutoRotation();
	}

	// Touch gesture handlers
	function handleTouchStart(e: TouchEvent) {
		touchStartX = e.touches[0].clientX;
		stopAutoRotation();
	}

	function handleTouchMove(e: TouchEvent) {
		touchEndX = e.touches[0].clientX;
	}

	function handleTouchEnd() {
		const swipeThreshold = 50;
		const diff = touchStartX - touchEndX;

		if (Math.abs(diff) > swipeThreshold) {
			if (diff > 0) {
				// Swipe left (next)
				if ($isRTL) {
					prevSlide();
				} else {
					nextSlide();
				}
			} else {
				// Swipe right (prev)
				if ($isRTL) {
					nextSlide();
				} else {
					prevSlide();
				}
			}
		}

		startAutoRotation();
	}

	// Format time remaining
	function formatTimeRemaining(offer: any): string {
		if (!offer.is_expiring_soon) return '';
		
		if (offer.hours_remaining < 1) {
			return getTranslation('offers.expiringSoon.minutes');
		} else if (offer.hours_remaining < 24) {
			return `${offer.hours_remaining} ${getTranslation('offers.expiringSoon.hours')}`;
		}
		return '';
	}

	// Calculate discount display value
	function getDiscountDisplay(offer: any): number | null {
		switch (offer.type) {
			case 'percentage':
				return offer.percentage_value;
			case 'special_price':
				return null;
			case 'cart_discount':
				// Get the highest tier discount
				if (offer.tiers && offer.tiers.length > 0) {
					return Math.max(...offer.tiers.map((t: any) => t.discount_percentage));
				}
				return null;
			default:
				return null;
		}
	}

	onMount(() => {
		startAutoRotation();
	});

	onDestroy(() => {
		stopAutoRotation();
	});
</script>

<div class="featured-offers-container" dir={$isRTL ? 'rtl' : 'ltr'}>
	{#if offers.length === 0}
		<div class="empty-state">
			<div class="empty-icon">🎁</div>
			<p>{getTranslation('offers.noActiveOffers')}</p>
		</div>
	{:else}
		<div class="carousel-wrapper">
			<div 
				class="carousel-track" 
				style="transform: translateX({$isRTL ? currentIndex * 100 : -currentIndex * 100}%)"
				on:touchstart={handleTouchStart}
				on:touchmove={handleTouchMove}
				on:touchend={handleTouchEnd}
				role="region"
				aria-label="Featured Offers Carousel"
			>
				{#each offers as offer, index}
					<div class="offer-card" class:active={index === currentIndex}>
						<!-- Offer Image -->
						<div class="offer-image-container">
							{#if offer.image_url}
								<img 
									src={offer.image_url} 
									alt={getOfferName(offer)}
									class="offer-image"
									loading={index === 0 ? 'eager' : 'lazy'}
								/>
							{:else}
								<div class="offer-image-placeholder">
									<span class="placeholder-icon">
										{offer.type === 'percentage' ? '📊' : 
										 offer.type === 'special_price' ? '💰' :
										 offer.type === 'bogo' ? '🎁' :
										 offer.type === 'bundle' ? '📦' : '🛒'}
									</span>
								</div>
							{/if}
							
							<!-- Badge Overlay -->
							<div class="badge-overlay">
								<OfferBadge 
									offerType={offer.type} 
									discountValue={getDiscountDisplay(offer)}
									size="medium"
								/>
							</div>

							<!-- Expiring Soon Badge -->
							{#if offer.is_expiring_soon}
								<div class="expiring-badge">
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<polyline points="12,6 12,12 16,14"/>
									</svg>
									{formatTimeRemaining(offer)}
								</div>
							{/if}
						</div>

						<!-- Offer Info -->
						<div class="offer-info">
							<h3 class="offer-title">{getOfferName(offer)}</h3>
							<p class="offer-description">{getOfferDescription(offer)}</p>

							<!-- Usage Indicator -->
							{#if offer.total_uses_remaining !== null}
								<div class="usage-indicator">
									<div class="usage-bar">
										<div 
											class="usage-fill" 
											style="width: {((offer.max_total_uses - offer.total_uses_remaining) / offer.max_total_uses) * 100}%"
										></div>
									</div>
									<span class="usage-text">
										{offer.total_uses_remaining} {getTranslation('offers.usesRemaining')}
									</span>
								</div>
							{/if}

							<!-- View Details Button -->
							<button 
								class="view-details-btn"
								on:click={() => {
									// Dispatch event to parent to open offer detail modal
									const event = new CustomEvent('viewOffer', { detail: offer });
									dispatchEvent(event);
								}}
							>
								{getTranslation('offers.viewDetails')}
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d={$isRTL ? "M15 18l-6-6 6-6" : "M9 18l6-6-6-6"}/>
								</svg>
							</button>
						</div>
					</div>
				{/each}
			</div>

			<!-- Navigation Arrows -->
			{#if offers.length > 1}
				<button 
					class="nav-arrow prev" 
					on:click={prevSlide}
					aria-label="Previous Offer"
				>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d={$isRTL ? "M9 18l6-6-6-6" : "M15 18l-6-6 6-6"}/>
					</svg>
				</button>
				<button 
					class="nav-arrow next" 
					on:click={nextSlide}
					aria-label="Next Offer"
				>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d={$isRTL ? "M15 18l-6-6 6-6" : "M9 18l6-6-6-6"}/>
					</svg>
				</button>
			{/if}
		</div>

		<!-- Pagination Dots -->
		{#if offers.length > 1}
			<div class="pagination-dots">
				{#each offers as _, index}
					<button 
						class="dot" 
						class:active={index === currentIndex}
						on:click={() => goToSlide(index)}
						aria-label="Go to slide {index + 1}"
					></button>
				{/each}
			</div>
		{/if}
	{/if}
</div>

<style>
	.featured-offers-container {
		width: 100%;
		margin: 0 auto;
		padding: 1rem;
	}

	.empty-state {
		text-align: center;
		padding: 3rem 1rem;
		color: #9CA3AF;
	}

	.empty-icon {
		font-size: 3rem;
		margin-bottom: 0.5rem;
		opacity: 0.5;
	}

	.empty-state p {
		font-size: 0.875rem;
		margin: 0;
	}

	.carousel-wrapper {
		position: relative;
		overflow: hidden;
		border-radius: 16px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.carousel-track {
		display: flex;
		transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1);
		touch-action: pan-y;
	}

	.offer-card {
		min-width: 100%;
		background: white;
		display: flex;
		flex-direction: column;
	}

	.offer-image-container {
		position: relative;
		width: 100%;
		height: 200px;
		overflow: hidden;
	}

	.offer-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.offer-image-placeholder {
		width: 100%;
		height: 100%;
		background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.placeholder-icon {
		font-size: 4rem;
		opacity: 0.8;
	}

	.badge-overlay {
		position: absolute;
		top: 12px;
		left: 12px;
		z-index: 2;
	}

	[dir="rtl"] .badge-overlay {
		left: auto;
		right: 12px;
	}

	.expiring-badge {
		position: absolute;
		top: 12px;
		right: 12px;
		background: #EF4444;
		color: white;
		padding: 0.375rem 0.75rem;
		border-radius: 8px;
		font-size: 0.75rem;
		font-weight: 600;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		animation: blink 1.5s ease-in-out infinite;
	}

	[dir="rtl"] .expiring-badge {
		right: auto;
		left: 12px;
	}

	@keyframes blink {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.7; }
	}

	.offer-info {
		padding: 1.25rem;
	}

	.offer-title {
		font-size: 1.125rem;
		font-weight: 700;
		color: #1F2937;
		margin: 0 0 0.5rem 0;
		line-height: 1.4;
	}

	.offer-description {
		font-size: 0.875rem;
		color: #6B7280;
		line-height: 1.5;
		margin: 0 0 1rem 0;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.usage-indicator {
		margin-bottom: 1rem;
	}

	.usage-bar {
		width: 100%;
		height: 6px;
		background: #E5E7EB;
		border-radius: 3px;
		overflow: hidden;
		margin-bottom: 0.375rem;
	}

	.usage-fill {
		height: 100%;
		background: linear-gradient(90deg, #10B981 0%, #059669 100%);
		transition: width 0.3s ease;
	}

	.usage-text {
		font-size: 0.75rem;
		color: #10B981;
		font-weight: 600;
	}

	.view-details-btn {
		width: 100%;
		padding: 0.75rem 1rem;
		background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: all 0.3s ease;
	}

	.view-details-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	.view-details-btn:active {
		transform: translateY(0);
	}

	.nav-arrow {
		position: absolute;
		top: 50%;
		transform: translateY(-50%);
		background: rgba(255, 255, 255, 0.9);
		border: none;
		width: 40px;
		height: 40px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.3s ease;
		z-index: 10;
		color: #374151;
	}

	.nav-arrow:hover {
		background: white;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
		transform: translateY(-50%) scale(1.1);
	}

	.nav-arrow.prev {
		left: 12px;
	}

	[dir="rtl"] .nav-arrow.prev {
		left: auto;
		right: 12px;
	}

	.nav-arrow.next {
		right: 12px;
	}

	[dir="rtl"] .nav-arrow.next {
		right: auto;
		left: 12px;
	}

	.pagination-dots {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 1rem 0 0 0;
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: #D1D5DB;
		border: none;
		padding: 0;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.dot:hover {
		background: #9CA3AF;
		transform: scale(1.2);
	}

	.dot.active {
		width: 24px;
		border-radius: 4px;
		background: #3B82F6;
	}

	@media (max-width: 480px) {
		.offer-image-container {
			height: 160px;
		}

		.offer-info {
			padding: 1rem;
		}

		.offer-title {
			font-size: 1rem;
		}

		.offer-description {
			font-size: 0.8125rem;
		}

		.nav-arrow {
			width: 32px;
			height: 32px;
		}
	}
</style>

