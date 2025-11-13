<script lang="ts">
	import { localeData, isRTL } from '$lib/i18n';
	import OfferBadge from './OfferBadge.svelte';

	export let offer: any = null;
	export let onClose: () => void;

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

	// Get localized product name
	function getProductName(product: any): string {
		return $isRTL ? product.name_ar : product.name_en;
	}

	// Format date
	function formatDate(dateString: string): string {
		const date = new Date(dateString);
		return date.toLocaleDateString($isRTL ? 'ar-SA' : 'en-US', {
			year: 'numeric',
			month: 'long',
			day: 'numeric'
		});
	}

	// Calculate discount display
	function getDiscountDisplay(offer: any): number | null {
		switch (offer.type) {
			case 'percentage':
				return offer.percentage_value;
			default:
				return null;
		}
	}

	// Close modal on backdrop click
	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) {
			onClose();
		}
	}

	// Close on escape key
	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			onClose();
		}
	}
</script>

<svelte:window on:keydown={handleKeydown} />

{#if offer}
	<div 
		class="modal-backdrop" 
		on:click={handleBackdropClick}
		role="dialog"
		aria-modal="true"
		aria-labelledby="offer-title"
	>
		<div class="modal-container" dir={$isRTL ? 'rtl' : 'ltr'}>
			<!-- Header -->
			<div class="modal-header">
				<button class="close-btn" on:click={onClose} aria-label={getTranslation('common.close')}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<!-- Content -->
			<div class="modal-content">
				<!-- Offer Image -->
				<div class="offer-image-section">
					{#if offer.image_url}
						<img 
							src={offer.image_url} 
							alt={getOfferName(offer)}
							class="offer-image"
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
					<div class="badge-absolute">
						<OfferBadge 
							offerType={offer.type} 
							discountValue={getDiscountDisplay(offer)}
							size="large"
						/>
					</div>
				</div>

				<!-- Offer Details -->
				<div class="offer-details">
					<h2 id="offer-title" class="offer-title">{getOfferName(offer)}</h2>
					<p class="offer-description">{getOfferDescription(offer)}</p>

					<!-- Validity Period -->
					<div class="info-section">
						<h3 class="section-title">{getTranslation('offers.modal.validity')}</h3>
						<div class="validity-info">
							<div class="validity-row">
								<span class="label">{getTranslation('offers.modal.startDate')}:</span>
								<span class="value">{formatDate(offer.start_date)}</span>
							</div>
							<div class="validity-row">
								<span class="label">{getTranslation('offers.modal.endDate')}:</span>
								<span class="value">{formatDate(offer.end_date)}</span>
							</div>
							{#if offer.is_expiring_soon}
								<div class="expiring-warning">
									⚠️ {getTranslation('offers.modal.expiringSoon')}
								</div>
							{/if}
						</div>
					</div>

					<!-- Offer Type Specific Content -->
					{#if offer.type === 'percentage' || offer.type === 'special_price'}
						{#if offer.products && offer.products.length > 0}
							<div class="info-section">
								<h3 class="section-title">{getTranslation('offers.modal.applicableProducts')}</h3>
								<div class="products-grid">
									{#each offer.products as productOffer}
										{@const product = productOffer.products}
										{#if product}
											<div class="product-card">
												{#if product.image_url}
													<img src={product.image_url} alt={getProductName(product)} class="product-image" />
												{:else}
													<div class="product-placeholder">🍽️</div>
												{/if}
												<div class="product-info">
													<span class="product-name">{getProductName(product)}</span>
													{#if offer.type === 'percentage'}
														<span class="product-discount">{productOffer.discount_percentage}% {getTranslation('offers.badge.off')}</span>
													{:else if offer.type === 'special_price'}
														<div class="price-info">
															<span class="original-price">{product.price} {getTranslation('common.sar')}</span>
															<span class="special-price">{productOffer.special_price} {getTranslation('common.sar')}</span>
														</div>
													{/if}
												</div>
											</div>
										{/if}
									{/each}
								</div>
							</div>
						{/if}
					{/if}

					{#if offer.type === 'bogo'}
						{#if offer.bogo_rules && offer.bogo_rules.length > 0}
							<div class="info-section">
								<h3 class="section-title">{getTranslation('offers.modal.bogoRules')}</h3>
								{#each offer.bogo_rules as rule}
									<div class="bogo-rule">
										<div class="bogo-buy">
											<span class="bogo-label">{getTranslation('offers.modal.buy')}:</span>
											<span class="bogo-value">{rule.buy_quantity}× {getProductName(rule.buy_products)}</span>
										</div>
										<div class="bogo-arrow">→</div>
										<div class="bogo-get">
											<span class="bogo-label">{getTranslation('offers.modal.get')}:</span>
											<span class="bogo-value">
												{rule.get_quantity}× {getProductName(rule.get_products)}
												{#if rule.get_discount_percentage === 100}
													<span class="free-badge">{getTranslation('offers.modal.free')}</span>
												{:else}
													<span class="discount-badge">{rule.get_discount_percentage}% {getTranslation('offers.badge.off')}</span>
												{/if}
											</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					{/if}

					{#if offer.type === 'bundle'}
						{#if offer.bundles && offer.bundles.length > 0}
							<div class="info-section">
								<h3 class="section-title">{getTranslation('offers.modal.bundleContents')}</h3>
								{#each offer.bundles as bundle}
									<div class="bundle-card">
										<div class="bundle-price">
											{getTranslation('offers.modal.bundlePrice')}: {bundle.bundle_price} {getTranslation('common.sar')}
										</div>
										<div class="bundle-items">
											{#each bundle.bundle_items as item}
												<div class="bundle-item">
													<span class="item-qty">{item.quantity}×</span>
													<span class="item-name">{getProductName(item.products)}</span>
													<span class="item-discount">({item.discount_percentage}% {getTranslation('offers.badge.off')})</span>
												</div>
											{/each}
										</div>
									</div>
								{/each}
							</div>
						{/if}
					{/if}

					{#if offer.type === 'cart_discount'}
						{#if offer.tiers && offer.tiers.length > 0}
							<div class="info-section">
								<h3 class="section-title">{getTranslation('offers.modal.cartTiers')}</h3>
								<div class="tiers-list">
									{#each offer.tiers as tier}
										<div class="tier-card">
											<div class="tier-condition">
												{getTranslation('offers.modal.spend')} {tier.min_cart_amount}+ {getTranslation('common.sar')}
											</div>
											<div class="tier-benefit">
												→ {tier.discount_percentage}% {getTranslation('offers.badge.off')}
											</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					{/if}

					<!-- Usage Limits -->
					<div class="info-section">
						<h3 class="section-title">{getTranslation('offers.modal.limits')}</h3>
						<div class="limits-info">
							{#if offer.max_uses_per_customer}
								<div class="limit-row">
									<span class="limit-icon">👤</span>
									<span>{offer.max_uses_per_customer} {getTranslation('offers.modal.usesPerCustomer')}</span>
								</div>
							{/if}
							{#if offer.total_uses_remaining !== null}
								<div class="limit-row">
									<span class="limit-icon">🎫</span>
									<span>{offer.total_uses_remaining} {getTranslation('offers.modal.totalUsesRemaining')}</span>
								</div>
							{/if}
						</div>
					</div>
				</div>

				<!-- Footer Action Button -->
				<div class="modal-footer">
					<button class="shop-now-btn">
						{getTranslation('offers.modal.shopNow')}
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="9" cy="21" r="1"/>
							<circle cx="20" cy="21" r="1"/>
							<path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/>
						</svg>
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.modal-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
		z-index: 9999;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		animation: fadeIn 0.3s ease-out;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.modal-container {
		background: white;
		border-radius: 20px;
		max-width: 600px;
		width: 100%;
		max-height: 90vh;
		overflow: hidden;
		box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
		animation: slideUp 0.3s ease-out;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(50px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.modal-header {
		position: relative;
		padding: 1rem 1.25rem;
		display: flex;
		justify-content: flex-end;
		background: linear-gradient(180deg, rgba(0, 0, 0, 0.1) 0%, transparent 100%);
	}

	.close-btn {
		background: white;
		border: none;
		width: 40px;
		height: 40px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.3s ease;
		color: #374151;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.close-btn:hover {
		background: #F3F4F6;
		transform: scale(1.1);
	}

	.modal-content {
		overflow-y: auto;
		max-height: calc(90vh - 70px);
		-webkit-overflow-scrolling: touch;
	}

	.offer-image-section {
		position: relative;
		width: 100%;
		height: 250px;
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
		font-size: 5rem;
		opacity: 0.8;
	}

	.badge-absolute {
		position: absolute;
		top: 1.5rem;
		left: 1.5rem;
	}

	[dir="rtl"] .badge-absolute {
		left: auto;
		right: 1.5rem;
	}

	.offer-details {
		padding: 1.5rem;
	}

	.offer-title {
		font-size: 1.5rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 0.75rem 0;
		line-height: 1.3;
	}

	.offer-description {
		font-size: 1rem;
		color: #6B7280;
		line-height: 1.6;
		margin: 0 0 1.5rem 0;
	}

	.info-section {
		margin-bottom: 1.5rem;
		padding-bottom: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.info-section:last-child {
		border-bottom: none;
		margin-bottom: 0;
		padding-bottom: 0;
	}

	.section-title {
		font-size: 1rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 1rem 0;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.validity-info {
		background: #F9FAFB;
		padding: 1rem;
		border-radius: 8px;
	}

	.validity-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
	}

	.label {
		font-size: 0.875rem;
		color: #6B7280;
		font-weight: 500;
	}

	.value {
		font-size: 0.875rem;
		color: #111827;
		font-weight: 600;
	}

	.expiring-warning {
		margin-top: 0.75rem;
		padding: 0.75rem;
		background: #FEE2E2;
		color: #991B1B;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 600;
		text-align: center;
		animation: pulse 2s ease-in-out infinite;
	}

	.products-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
		gap: 1rem;
	}

	.product-card {
		background: #F9FAFB;
		border-radius: 8px;
		padding: 0.75rem;
		text-align: center;
	}

	.product-image {
		width: 100%;
		height: 80px;
		object-fit: cover;
		border-radius: 6px;
		margin-bottom: 0.5rem;
	}

	.product-placeholder {
		width: 100%;
		height: 80px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 2.5rem;
		background: #E5E7EB;
		border-radius: 6px;
		margin-bottom: 0.5rem;
	}

	.product-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.product-name {
		font-size: 0.8125rem;
		font-weight: 600;
		color: #374151;
	}

	.product-discount {
		font-size: 0.75rem;
		color: #10B981;
		font-weight: 700;
	}

	.price-info {
		display: flex;
		flex-direction: column;
		gap: 0.125rem;
	}

	.original-price {
		font-size: 0.75rem;
		color: #9CA3AF;
		text-decoration: line-through;
	}

	.special-price {
		font-size: 0.875rem;
		color: #EF4444;
		font-weight: 700;
	}

	.bogo-rule {
		background: #F9FAFB;
		padding: 1rem;
		border-radius: 8px;
		display: flex;
		align-items: center;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.bogo-buy, .bogo-get {
		flex: 1;
		min-width: 150px;
	}

	.bogo-label {
		display: block;
		font-size: 0.75rem;
		color: #6B7280;
		font-weight: 500;
		text-transform: uppercase;
		margin-bottom: 0.25rem;
	}

	.bogo-value {
		display: block;
		font-size: 0.9375rem;
		color: #111827;
		font-weight: 600;
	}

	.bogo-arrow {
		font-size: 1.5rem;
		color: #10B981;
	}

	.free-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #10B981;
		color: white;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 700;
		margin-left: 0.5rem;
	}

	[dir="rtl"] .free-badge {
		margin-left: 0;
		margin-right: 0.5rem;
	}

	.discount-badge {
		display: inline-block;
		padding: 0.25rem 0.5rem;
		background: #3B82F6;
		color: white;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 700;
		margin-left: 0.5rem;
	}

	[dir="rtl"] .discount-badge {
		margin-left: 0;
		margin-right: 0.5rem;
	}

	.bundle-card {
		background: #F9FAFB;
		padding: 1rem;
		border-radius: 8px;
	}

	.bundle-price {
		font-size: 1.125rem;
		font-weight: 700;
		color: #10B981;
		margin-bottom: 0.75rem;
	}

	.bundle-items {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.bundle-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
	}

	.item-qty {
		font-weight: 700;
		color: #6B7280;
	}

	.item-name {
		flex: 1;
		color: #374151;
	}

	.item-discount {
		color: #3B82F6;
		font-weight: 600;
		font-size: 0.75rem;
	}

	.tiers-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.tier-card {
		background: #F9FAFB;
		padding: 1rem;
		border-radius: 8px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.tier-condition {
		font-size: 0.875rem;
		color: #374151;
		font-weight: 600;
	}

	.tier-benefit {
		font-size: 1rem;
		color: #10B981;
		font-weight: 700;
	}

	.limits-info {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.limit-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem;
		background: #F9FAFB;
		border-radius: 6px;
		font-size: 0.875rem;
		color: #374151;
	}

	.limit-icon {
		font-size: 1.25rem;
	}

	.modal-footer {
		padding: 1.5rem;
		background: #F9FAFB;
		border-top: 1px solid #E5E7EB;
	}

	.shop-now-btn {
		width: 100%;
		padding: 1rem 1.5rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		transition: all 0.3s ease;
	}

	.shop-now-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 20px rgba(16, 185, 129, 0.4);
	}

	.shop-now-btn:active {
		transform: translateY(0);
	}

	@media (max-width: 768px) {
		.modal-container {
			border-radius: 16px;
		}

		.offer-image-section {
			height: 200px;
		}

		.offer-title {
			font-size: 1.25rem;
		}

		.products-grid {
			grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
		}
	}

	@media (max-width: 480px) {
		.modal-backdrop {
			padding: 0.5rem;
		}

		.offer-details {
			padding: 1rem;
		}

		.products-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>
