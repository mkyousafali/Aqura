<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';

	const loadingMessages = [
		{ en: 'Getting Ready... 😊', ar: 'جاري التحضير...' },
		{ en: 'Almost There... 😊', ar: 'أوشكنا على الانتهاء...' },
		{ en: 'Just a Second... 😊', ar: 'لحظة واحدة...' }
	];
	let msgIndex = 0;
	let msgInterval: ReturnType<typeof setInterval>;

	onMount(() => {
		msgInterval = setInterval(() => {
			msgIndex = (msgIndex + 1) % loadingMessages.length;
		}, 1500);

		// Redirect to appropriate interface based on user type
		if ($currentUser) {
			goto('/desktop-interface');
		} else {
			goto('/login');
		}
	});

	onDestroy(() => {
		if (msgInterval) clearInterval(msgInterval);
	});
</script>

<!-- Loading state while redirecting -->
<div class="loading-container">
	<div class="spinner"></div>
	<div class="loading-text">
		<p>{loadingMessages[msgIndex].en}</p>
		<p>{loadingMessages[msgIndex].ar}</p>
	</div>
</div>

<style>
	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100vh;
		background: var(--theme-desktop-bg, #F9FAFB);
		color: #374151;
	}

	.spinner {
		width: 70px;
		height: 70px;
		border: 5px solid rgba(107, 114, 128, 0.3);
		border-top-color: #374151;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.loading-text {
		margin-top: 1.5rem;
		text-align: center;
	}

	.loading-text p {
		margin: 0;
		font-size: 2rem;
		font-weight: 600;
		line-height: 1.4;
	}
</style>
