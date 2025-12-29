<script lang="ts">
	import { goto } from '$app/navigation';
	import { _, currentLocale } from '$lib/i18n';

	function goBack() {
		goto('/');
	}
</script>

<svelte:head>
	<title>Latest Offers - Aqura</title>
	<meta name="description" content="View the latest offers from Aqura" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
</svelte:head>

<div class="offers-page">
	<header class="offers-header">
		<button class="back-btn" on:click={goBack} title="Back">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
		</button>
		<h1>Latest Offers</h1>
		<button 
			class="lang-btn" 
			title="Toggle Language"
		>
			{$currentLocale === 'en' ? 'العربية' : 'English'}
		</button>
	</header>

	<main class="offers-content">
		<!-- Blank content area for offers -->
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
		background: linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%);
		color: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		gap: 1rem;
	}

	.offers-header h1 {
		flex: 1;
		font-size: 1.5rem;
		font-weight: 700;
		margin: 0;
		text-align: center;
	}

	.back-btn,
	.lang-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		padding: 0;
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		-webkit-tap-highlight-color: transparent;
	}

	.back-btn:hover,
	.lang-btn:hover {
		background: rgba(255, 255, 255, 0.3);
		border-color: rgba(255, 255, 255, 0.5);
	}

	.back-btn:active,
	.lang-btn:active {
		transform: scale(0.95);
	}

	.offers-content {
		flex: 1;
		padding: 1.5rem;
		overflow-y: auto;
		display: flex;
		align-items: center;
		justify-content: center;
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

		.back-btn,
		.lang-btn {
			width: 36px;
			height: 36px;
			font-size: 0.75rem;
		}

		.offers-content {
			padding: 1rem;
		}
	}

	@media (max-width: 480px) {
		.offers-header {
			padding: 0.75rem;
		}

		.offers-header h1 {
			font-size: 1.125rem;
		}

		.offers-content {
			padding: 0.75rem;
		}
	}

	/* Dark mode support */
	@media (prefers-color-scheme: dark) {
		.offers-page {
			background: #1F2937;
			color: #F3F4F6;
		}
	}

	/* RTL Support */
	:global([dir="rtl"]) .offers-header {
		flex-direction: row-reverse;
	}

	:global([dir="rtl"]) .offers-header h1 {
		text-align: center;
	}
</style>
