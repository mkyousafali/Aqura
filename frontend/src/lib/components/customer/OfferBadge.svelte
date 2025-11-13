<script lang="ts">
	import { localeData } from '$lib/i18n';
	
	export let offerType: 'percentage' | 'special_price' | 'bogo' | 'bundle' | 'cart_discount';
	export let discountValue: number | null = null;
	export let size: 'small' | 'medium' | 'large' = 'medium';
	export let showIcon: boolean = true;

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

	// Get badge config based on offer type
	$: badgeConfig = getBadgeConfig(offerType);

	function getBadgeConfig(type: string) {
		switch (type) {
			case 'percentage':
				return {
					colors: 'from-blue-500 to-blue-600',
					icon: '📊',
					label: discountValue ? `${discountValue}% ${getTranslation('offers.badge.off')}` : getTranslation('offers.badge.discount')
				};
			case 'special_price':
				return {
					colors: 'from-orange-500 to-orange-600',
					icon: '💰',
					label: getTranslation('offers.badge.specialPrice')
				};
			case 'bogo':
				return {
					colors: 'from-pink-500 to-pink-600',
					icon: '🎁',
					label: getTranslation('offers.badge.bogo')
				};
			case 'bundle':
				return {
					colors: 'from-purple-500 to-purple-600',
					icon: '📦',
					label: getTranslation('offers.badge.bundle')
				};
			case 'cart_discount':
				return {
					colors: 'from-green-500 to-green-600',
					icon: '🛒',
					label: getTranslation('offers.badge.cartDiscount')
				};
			default:
				return {
					colors: 'from-gray-500 to-gray-600',
					icon: '✨',
					label: getTranslation('offers.badge.offer')
				};
		}
	}

	$: sizeClasses = {
		small: 'text-xs px-2 py-1',
		medium: 'text-sm px-3 py-1.5',
		large: 'text-base px-4 py-2'
	}[size];
</script>

<div class="offer-badge {sizeClasses} bg-gradient-to-r {badgeConfig.colors} text-white font-bold rounded-lg shadow-md inline-flex items-center gap-1.5 whitespace-nowrap">
	{#if showIcon}
		<span class="icon">{badgeConfig.icon}</span>
	{/if}
	<span>{badgeConfig.label}</span>
</div>

<style>
	.offer-badge {
		transition: all 0.3s ease;
		animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
	}

	.offer-badge:hover {
		transform: scale(1.05);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.9;
		}
	}

	.icon {
		display: inline-block;
		animation: bounce 2s infinite;
	}

	@keyframes bounce {
		0%, 100% {
			transform: translateY(0);
		}
		50% {
			transform: translateY(-2px);
		}
	}
</style>
