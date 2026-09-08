<script lang="ts">
	import { currentLocale } from '$lib/i18n';

	$: isRTL = $currentLocale === 'ar';

	const textEn = '⭐ Loyalty members: Register your WhatsApp number to keep earning points & rewards.';
	const textAr = '⭐ أعضاء الولاء: سجّل رقم واتساب للاستمرار في استلام النقاط والمكافآت.';

	$: text = isRTL ? textAr : textEn;
</script>

<div
	class="announcement-bar"
	role="region"
	aria-label={isRTL ? 'إعلان مهم' : 'Important Announcement'}
>
	<span class="ticker-text" class:rtl-font={isRTL}>{text}</span>
</div>

<style>
	.announcement-bar {
		width: 100%;
		height: 36px;
		background: linear-gradient(135deg, #b91c1c 0%, #dc2626 60%, #ef4444 100%);
		overflow: hidden;
		display: flex;
		align-items: center;
		box-shadow: inset 0 -1px 0 rgba(0, 0, 0, 0.1);
	}

	.ticker-text {
		display: inline-block;
		white-space: nowrap;
		color: #ffffff;
		font-size: 12.5px;
		font-weight: 500;
		letter-spacing: 0.015em;
		flex-shrink: 0;
		/* enters from off-screen right, exits off-screen left, loop reset is invisible */
		animation: ticker-ltr 15s linear infinite;
		will-change: transform;
	}

	.ticker-text.rtl-font {
		font-family: 'Tajawal', 'Noto Sans Arabic', system-ui, sans-serif;
		font-size: 13px;
		letter-spacing: 0;
	}

	@keyframes ticker-ltr {
		0%   { transform: translateX(-100%); }
		100% { transform: translateX(100vw); }
	}
</style>
