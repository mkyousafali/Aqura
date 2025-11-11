<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { t, currentLocale } from '$lib/i18n';

	export let selectedType: string | null = null;

	const dispatch = createEventDispatcher();

	const offerTypes = [
		{
			type: 'product',
			icon: '🏷️',
			nameEn: 'Product Discount',
			nameAr: 'خصم على منتج',
			descEn: 'Discount on specific products or product categories',
			descAr: 'خصم على منتجات محددة أو فئات منتجات',
			examples: ['20% off fruits', '15 SAR off dairy']
		},
		{
			type: 'bundle',
			icon: '📦',
			nameEn: 'Bundle Offer',
			nameAr: 'عرض حزمة',
			descEn: 'Buy multiple products together at a discounted price',
			descAr: 'اشتري عدة منتجات معاً بسعر مخفض',
			examples: ['Breakfast bundle', 'Family pack']
		},
		{
			type: 'cart',
			icon: '🛒',
			nameEn: 'Cart Discount',
			nameAr: 'خصم على السلة',
			descEn: 'Discount applied to entire cart based on total amount',
			descAr: 'خصم على إجمالي السلة بناءً على المبلغ الكلي',
			examples: ['10% off orders over 200 SAR']
		},
		{
			type: 'bogo',
			icon: '🎁',
			nameEn: 'Buy X Get Y',
			nameAr: 'اشتري X واحصل على Y',
			descEn: 'Buy a certain quantity and get additional items free or discounted',
			descAr: 'اشتري كمية معينة واحصل على منتجات إضافية مجاناً أو مخفضة',
			examples: ['Buy 2 Get 1 Free', 'Buy 3 Save 50%']
		},
		{
			type: 'min_purchase',
			icon: '💰',
			nameEn: 'Minimum Purchase',
			nameAr: 'حد أدنى للشراء',
			descEn: 'Discount when cart reaches minimum amount or quantity',
			descAr: 'خصم عند الوصول لحد أدنى من المبلغ أو الكمية',
			examples: ['Free delivery on 100 SAR', '15% off 5+ items']
		},
		{
			type: 'customer',
			icon: '⭐',
			nameEn: 'Customer-Specific',
			nameAr: 'خاص بالعملاء',
			descEn: 'Exclusive offers for specific customers or customer groups',
			descAr: 'عروض حصرية لعملاء محددين أو مجموعات عملاء',
			examples: ['VIP customer 25% off', 'Loyalty reward']
		}
	];

	function selectType(type: string) {
		selectedType = type;
		dispatch('select', { type });
	}

	$: isRTL = $currentLocale === 'ar';
</script>

<div class="offer-type-selector" class:rtl={isRTL}>
	<div class="selector-header">
		<h2>{isRTL ? 'اختر نوع العرض' : 'Select Offer Type'}</h2>
		<p class="subtitle">
			{isRTL
				? 'اختر نوع العرض المناسب لاحتياجاتك'
				: 'Choose the offer type that suits your needs'}
		</p>
	</div>

	<div class="types-grid">
		{#each offerTypes as offerType}
			<button
				class="type-card"
				class:selected={selectedType === offerType.type}
				on:click={() => selectType(offerType.type)}
			>
				<div class="card-icon">{offerType.icon}</div>
				<h3 class="card-title">{isRTL ? offerType.nameAr : offerType.nameEn}</h3>
				<p class="card-desc">{isRTL ? offerType.descAr : offerType.descEn}</p>
				<div class="card-examples">
					<span class="examples-label">{isRTL ? 'أمثلة:' : 'Examples:'}</span>
					<ul>
						{#each offerType.examples as example}
							<li>{example}</li>
						{/each}
					</ul>
				</div>
				{#if selectedType === offerType.type}
					<div class="selected-badge">
						<svg
							xmlns="http://www.w3.org/2000/svg"
							width="20"
							height="20"
							viewBox="0 0 24 24"
							fill="none"
							stroke="currentColor"
							stroke-width="2"
							stroke-linecap="round"
							stroke-linejoin="round"
						>
							<polyline points="20 6 9 17 4 12"></polyline>
						</svg>
					</div>
				{/if}
			</button>
		{/each}
	</div>
</div>

<style>
	.offer-type-selector {
		width: 100%;
		padding: 2rem;
	}

	.offer-type-selector.rtl {
		direction: rtl;
		text-align: right;
	}

	.selector-header {
		margin-bottom: 2rem;
		text-align: center;
	}

	.selector-header h2 {
		font-size: 1.75rem;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		font-size: 1rem;
		color: #6b7280;
	}

	.types-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
		gap: 1.5rem;
	}

	.type-card {
		position: relative;
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
		text-align: left;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.rtl .type-card {
		text-align: right;
	}

	.type-card:hover {
		border-color: #3b82f6;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
		transform: translateY(-2px);
	}

	.type-card.selected {
		border-color: #3b82f6;
		background: #eff6ff;
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.2);
	}

	.card-icon {
		font-size: 2.5rem;
		margin-bottom: 0.5rem;
	}

	.card-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1f2937;
		margin: 0;
	}

	.card-desc {
		font-size: 0.875rem;
		color: #6b7280;
		line-height: 1.5;
		margin: 0;
	}

	.card-examples {
		margin-top: 0.5rem;
		padding-top: 0.75rem;
		border-top: 1px solid #e5e7eb;
	}

	.examples-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #9ca3af;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.card-examples ul {
		list-style: none;
		padding: 0;
		margin: 0.5rem 0 0 0;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.card-examples li {
		font-size: 0.8125rem;
		color: #6b7280;
		padding-left: 1rem;
		position: relative;
	}

	.rtl .card-examples li {
		padding-left: 0;
		padding-right: 1rem;
	}

	.card-examples li::before {
		content: '•';
		position: absolute;
		left: 0;
		color: #9ca3af;
	}

	.rtl .card-examples li::before {
		left: auto;
		right: 0;
	}

	.selected-badge {
		position: absolute;
		top: 1rem;
		right: 1rem;
		width: 32px;
		height: 32px;
		background: #3b82f6;
		color: white;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	.rtl .selected-badge {
		right: auto;
		left: 1rem;
	}

	@media (max-width: 768px) {
		.types-grid {
			grid-template-columns: 1fr;
		}

		.offer-type-selector {
			padding: 1rem;
		}
	}
</style>
